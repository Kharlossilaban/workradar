package middleware

import (
	"bytes"
	"encoding/json"
	"io"
	"log"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/services"
	"github.com/workradar/server/pkg/utils"
)

// ============================================
// INPUT SANITIZATION MIDDLEWARE
// Minggu 6: SQL Injection Prevention
// ============================================

// SanitizationConfig holds sanitization middleware config
type SanitizationConfig struct {
	// SkipPaths paths to skip sanitization
	SkipPaths []string
	// LogThreats log detected threats
	LogThreats bool
	// BlockOnThreat block request on threat detection
	BlockOnThreat bool
	// AuditService for logging
	AuditService *services.AuditService
	// MaxBodySize maximum body size to scan
	MaxBodySize int
}

// DefaultSanitizationConfig returns default config
func DefaultSanitizationConfig() SanitizationConfig {
	return SanitizationConfig{
		SkipPaths: []string{
			"/api/health",
			"/api/ready",
			"/api/live",
			"/api/metrics",
		},
		LogThreats:    true,
		BlockOnThreat: true,
		MaxBodySize:   1024 * 1024, // 1MB
	}
}

// InputSanitizationMiddleware sanitizes all input to prevent injection attacks
func InputSanitizationMiddleware(config ...SanitizationConfig) fiber.Handler {
	cfg := DefaultSanitizationConfig()
	if len(config) > 0 {
		cfg = config[0]
	}

	return func(c *fiber.Ctx) error {
		// Skip certain paths
		path := c.Path()
		for _, skipPath := range cfg.SkipPaths {
			if strings.HasPrefix(path, skipPath) {
				return c.Next()
			}
		}

		// Check query parameters
		queryArgs := c.Queries()
		for key, value := range queryArgs {
			if threat := detectThreat(value); threat != "" {
				if cfg.LogThreats {
					logThreatDetection(c, cfg.AuditService, "QUERY_PARAM", key, value, threat)
				}
				if cfg.BlockOnThreat {
					return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
						"success": false,
						"error":   "Invalid input detected in query parameter: " + key,
						"code":    "SECURITY_THREAT_DETECTED",
					})
				}
			}
		}

		// Check path parameters
		params := c.AllParams()
		for key, value := range params {
			if threat := detectThreat(value); threat != "" {
				if cfg.LogThreats {
					logThreatDetection(c, cfg.AuditService, "PATH_PARAM", key, value, threat)
				}
				if cfg.BlockOnThreat {
					return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
						"success": false,
						"error":   "Invalid input detected in path parameter",
						"code":    "SECURITY_THREAT_DETECTED",
					})
				}
			}
		}

		// Check headers for common attack vectors
		suspiciousHeaders := []string{"User-Agent", "Referer", "X-Forwarded-For"}
		for _, header := range suspiciousHeaders {
			value := c.Get(header)
			if value != "" {
				if hasSQLInjection, _ := utils.ContainsSQLInjection(value); hasSQLInjection {
					if cfg.LogThreats {
						logThreatDetection(c, cfg.AuditService, "HEADER", header, value, "SQL_INJECTION")
					}
					// Don't block on headers, just log
				}
			}
		}

		// Check request body for POST/PUT/PATCH
		method := c.Method()
		if method == "POST" || method == "PUT" || method == "PATCH" {
			body := c.Body()
			if len(body) > 0 && len(body) <= cfg.MaxBodySize {
				bodyStr := string(body)

				// Check for SQL injection in body
				if hasSQLInjection, patterns := utils.ContainsSQLInjection(bodyStr); hasSQLInjection {
					if cfg.LogThreats {
						logThreatDetection(c, cfg.AuditService, "BODY", "request_body", truncateString(bodyStr, 200), "SQL_INJECTION")
						_ = patterns
					}
					if cfg.BlockOnThreat {
						return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
							"success": false,
							"error":   "Invalid input detected in request body",
							"code":    "SQL_INJECTION_DETECTED",
						})
					}
				}

				// Check for XSS in body
				if hasXSS, _ := utils.ContainsXSS(bodyStr); hasXSS {
					if cfg.LogThreats {
						logThreatDetection(c, cfg.AuditService, "BODY", "request_body", truncateString(bodyStr, 200), "XSS")
					}
					if cfg.BlockOnThreat {
						return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
							"success": false,
							"error":   "Invalid input detected in request body",
							"code":    "XSS_DETECTED",
						})
					}
				}

				// Parse JSON and validate individual fields
				if c.Get("Content-Type") == "application/json" {
					var jsonData map[string]interface{}
					if err := json.Unmarshal(body, &jsonData); err == nil {
						if err := validateJSONFields(jsonData, cfg, c); err != nil {
							return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
								"success": false,
								"error":   err.Error(),
								"code":    "INVALID_INPUT",
							})
						}
					}
				}
			}
		}

		return c.Next()
	}
}

// detectThreat detects various threat types in input
func detectThreat(input string) string {
	if hasSQLInjection, _ := utils.ContainsSQLInjection(input); hasSQLInjection {
		return "SQL_INJECTION"
	}
	if hasXSS, _ := utils.ContainsXSS(input); hasXSS {
		return "XSS"
	}
	if hasPathTraversal, _ := utils.ContainsPathTraversal(input); hasPathTraversal {
		return "PATH_TRAVERSAL"
	}
	if hasCmdInjection, _ := utils.ContainsCmdInjection(input); hasCmdInjection {
		return "COMMAND_INJECTION"
	}
	return ""
}

// validateJSONFields validates JSON fields recursively
func validateJSONFields(data map[string]interface{}, cfg SanitizationConfig, c *fiber.Ctx) error {
	for key, value := range data {
		switch v := value.(type) {
		case string:
			if threat := detectThreat(v); threat != "" {
				if cfg.LogThreats {
					logThreatDetection(c, cfg.AuditService, "JSON_FIELD", key, truncateString(v, 100), threat)
				}
				if cfg.BlockOnThreat {
					return fiber.NewError(fiber.StatusBadRequest, "Invalid input in field: "+key)
				}
			}
		case map[string]interface{}:
			if err := validateJSONFields(v, cfg, c); err != nil {
				return err
			}
		case []interface{}:
			for _, item := range v {
				if itemMap, ok := item.(map[string]interface{}); ok {
					if err := validateJSONFields(itemMap, cfg, c); err != nil {
						return err
					}
				}
				if itemStr, ok := item.(string); ok {
					if threat := detectThreat(itemStr); threat != "" {
						if cfg.LogThreats {
							logThreatDetection(c, cfg.AuditService, "JSON_ARRAY", key, truncateString(itemStr, 100), threat)
						}
						if cfg.BlockOnThreat {
							return fiber.NewError(fiber.StatusBadRequest, "Invalid input in array field: "+key)
						}
					}
				}
			}
		}
	}
	return nil
}

// logThreatDetection logs detected threats
func logThreatDetection(c *fiber.Ctx, auditService *services.AuditService, location, field, value, threatType string) {
	userID := c.Locals("userID")
	userIDStr := ""
	if userID != nil {
		userIDStr = userID.(string)
	}

	details := map[string]interface{}{
		"location":    location,
		"field":       field,
		"value":       truncateString(value, 200),
		"threat_type": threatType,
		"path":        c.Path(),
		"method":      c.Method(),
	}
	detailsJSON, _ := json.Marshal(details)

	log.Printf("[SECURITY] Threat detected: type=%s, location=%s, field=%s, ip=%s, path=%s",
		threatType, location, field, c.IP(), c.Path())

	if auditService != nil {
		auditService.LogSecurityEvent(
			models.SecurityEventType(threatType+"_ATTEMPT"),
			models.SeverityHigh,
			&userIDStr,
			c.IP(),
			string(detailsJSON),
			c.Get("User-Agent"),
		)
	}
}

// truncateString truncates string to max length
func truncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// ============================================
// STRICT INPUT VALIDATION MIDDLEWARE
// ============================================

// StrictValidationConfig for strict validation
type StrictValidationConfig struct {
	// ValidateContentType enforce content type
	ValidateContentType bool
	// AllowedContentTypes list of allowed content types
	AllowedContentTypes []string
	// ValidateContentLength check content length
	ValidateContentLength bool
	// MaxContentLength maximum content length
	MaxContentLength int
	// RequireJSONForAPI require JSON for API endpoints
	RequireJSONForAPI bool
}

// DefaultStrictValidationConfig returns default strict config
func DefaultStrictValidationConfig() StrictValidationConfig {
	return StrictValidationConfig{
		ValidateContentType: true,
		AllowedContentTypes: []string{
			"application/json",
			"application/x-www-form-urlencoded",
			"multipart/form-data",
		},
		ValidateContentLength: true,
		MaxContentLength:      10 * 1024 * 1024, // 10MB
		RequireJSONForAPI:     true,
	}
}

// StrictInputValidationMiddleware enforces strict input validation
func StrictInputValidationMiddleware(config ...StrictValidationConfig) fiber.Handler {
	cfg := DefaultStrictValidationConfig()
	if len(config) > 0 {
		cfg = config[0]
	}

	return func(c *fiber.Ctx) error {
		method := c.Method()

		// Only validate for methods with body
		if method == "POST" || method == "PUT" || method == "PATCH" {
			// Content-Type validation
			if cfg.ValidateContentType {
				contentType := c.Get("Content-Type")
				if contentType != "" {
					// Extract base content type (without charset, boundary, etc.)
					baseContentType := strings.Split(contentType, ";")[0]
					baseContentType = strings.TrimSpace(baseContentType)

					isAllowed := false
					for _, allowed := range cfg.AllowedContentTypes {
						if strings.HasPrefix(baseContentType, allowed) {
							isAllowed = true
							break
						}
					}

					if !isAllowed && cfg.RequireJSONForAPI && strings.HasPrefix(c.Path(), "/api/") {
						return c.Status(fiber.StatusUnsupportedMediaType).JSON(fiber.Map{
							"success": false,
							"error":   "Unsupported content type",
							"code":    "INVALID_CONTENT_TYPE",
						})
					}
				} else if cfg.RequireJSONForAPI && strings.HasPrefix(c.Path(), "/api/") && len(c.Body()) > 0 {
					return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
						"success": false,
						"error":   "Content-Type header is required",
						"code":    "MISSING_CONTENT_TYPE",
					})
				}
			}

			// Content-Length validation
			if cfg.ValidateContentLength {
				contentLength := len(c.Body())
				if contentLength > cfg.MaxContentLength {
					return c.Status(fiber.StatusRequestEntityTooLarge).JSON(fiber.Map{
						"success": false,
						"error":   "Request body too large",
						"code":    "REQUEST_TOO_LARGE",
					})
				}
			}
		}

		return c.Next()
	}
}

// ============================================
// BODY PARSER WITH SANITIZATION
// ============================================

// SanitizedBodyParser parses and sanitizes request body
func SanitizedBodyParser(c *fiber.Ctx, out interface{}) error {
	// Read body
	body := c.Body()
	if len(body) == 0 {
		return fiber.NewError(fiber.StatusBadRequest, "Request body is empty")
	}

	// Parse JSON
	if err := json.Unmarshal(body, out); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid JSON format")
	}

	return nil
}

// ParseAndValidateJSON parses JSON and validates it
func ParseAndValidateJSON(c *fiber.Ctx, out interface{}) error {
	body := c.Body()
	if len(body) == 0 {
		return fiber.NewError(fiber.StatusBadRequest, "Request body is empty")
	}

	// Check for threats first
	bodyStr := string(body)
	if hasSQLInjection, _ := utils.ContainsSQLInjection(bodyStr); hasSQLInjection {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid input detected")
	}

	// Parse
	if err := json.Unmarshal(body, out); err != nil {
		return fiber.NewError(fiber.StatusBadRequest, "Invalid JSON format")
	}

	return nil
}

// ============================================
// REQUEST BODY LIMITER
// ============================================

// RequestBodyLimiter limits request body size per endpoint
func RequestBodyLimiter(defaultLimit int, pathLimits map[string]int) fiber.Handler {
	return func(c *fiber.Ctx) error {
		path := c.Path()
		limit := defaultLimit

		// Check for path-specific limits
		for pathPattern, pathLimit := range pathLimits {
			if strings.HasPrefix(path, pathPattern) {
				limit = pathLimit
				break
			}
		}

		bodyLen := len(c.Body())
		if bodyLen > limit {
			return c.Status(fiber.StatusRequestEntityTooLarge).JSON(fiber.Map{
				"success": false,
				"error":   "Request body exceeds size limit",
				"code":    "BODY_TOO_LARGE",
			})
		}

		return c.Next()
	}
}

// ============================================
// THREAT DETECTION RESULT
// ============================================

// ThreatDetectionResult holds threat detection result
type ThreatDetectionResult struct {
	HasThreat   bool      `json:"has_threat"`
	ThreatType  string    `json:"threat_type,omitempty"`
	Severity    string    `json:"severity,omitempty"`
	Location    string    `json:"location,omitempty"`
	Field       string    `json:"field,omitempty"`
	Description string    `json:"description,omitempty"`
	DetectedAt  time.Time `json:"detected_at,omitempty"`
}

// ScanRequestForThreats scans entire request for threats
func ScanRequestForThreats(c *fiber.Ctx) []ThreatDetectionResult {
	results := []ThreatDetectionResult{}

	// Scan query parameters
	queryArgs := c.Queries()
	for key, value := range queryArgs {
		if threat := detectThreat(value); threat != "" {
			results = append(results, ThreatDetectionResult{
				HasThreat:   true,
				ThreatType:  threat,
				Severity:    getThreatSeverity(threat),
				Location:    "QUERY_PARAMETER",
				Field:       key,
				Description: "Threat detected in query parameter",
				DetectedAt:  time.Now(),
			})
		}
	}

	// Scan path parameters
	params := c.AllParams()
	for key, value := range params {
		if threat := detectThreat(value); threat != "" {
			results = append(results, ThreatDetectionResult{
				HasThreat:   true,
				ThreatType:  threat,
				Severity:    getThreatSeverity(threat),
				Location:    "PATH_PARAMETER",
				Field:       key,
				Description: "Threat detected in path parameter",
				DetectedAt:  time.Now(),
			})
		}
	}

	// Scan body
	body := c.Body()
	if len(body) > 0 {
		bodyStr := string(body)
		if threat := detectThreat(bodyStr); threat != "" {
			results = append(results, ThreatDetectionResult{
				HasThreat:   true,
				ThreatType:  threat,
				Severity:    getThreatSeverity(threat),
				Location:    "REQUEST_BODY",
				Field:       "",
				Description: "Threat detected in request body",
				DetectedAt:  time.Now(),
			})
		}
	}

	return results
}

// getThreatSeverity returns severity for threat type
func getThreatSeverity(threatType string) string {
	switch threatType {
	case "SQL_INJECTION":
		return "CRITICAL"
	case "XSS":
		return "HIGH"
	case "COMMAND_INJECTION":
		return "CRITICAL"
	case "PATH_TRAVERSAL":
		return "HIGH"
	default:
		return "MEDIUM"
	}
}

// ============================================
// SANITIZED BODY READER
// ============================================

// SanitizedBodyReader wraps body reader with sanitization
type SanitizedBodyReader struct {
	reader io.Reader
	buffer bytes.Buffer
}

// NewSanitizedBodyReader creates new sanitized body reader
func NewSanitizedBodyReader(body []byte) *SanitizedBodyReader {
	return &SanitizedBodyReader{
		reader: bytes.NewReader(body),
	}
}

// Read implements io.Reader
func (r *SanitizedBodyReader) Read(p []byte) (n int, err error) {
	return r.reader.Read(p)
}

// GetSanitizedContent returns sanitized content
func (r *SanitizedBodyReader) GetSanitizedContent() string {
	content := r.buffer.String()
	return utils.SanitizeHTML(content)
}
