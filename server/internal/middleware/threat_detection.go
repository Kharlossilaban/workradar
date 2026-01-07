package middleware

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/services"
)

// ThreatDetectionConfig configuration for threat detection
type ThreatDetectionConfig struct {
	// Brute Force Detection
	MaxFailedLoginAttempts int           // Max failed attempts before blocking
	FailedLoginWindow      time.Duration // Time window for counting failed attempts
	BlockDuration          time.Duration // How long to block IP

	// Rate Limiting for sensitive endpoints
	SensitiveEndpointRateLimit int           // Max requests per window
	SensitiveEndpointWindow    time.Duration // Window for rate limiting

	// SQL Injection Detection
	EnableSQLInjectionDetection bool

	// Bulk Access Detection
	BulkAccessThreshold int           // Max records accessed in window
	BulkAccessWindow    time.Duration // Window for bulk access detection
}

// DefaultThreatDetectionConfig returns default configuration
func DefaultThreatDetectionConfig() ThreatDetectionConfig {
	return ThreatDetectionConfig{
		MaxFailedLoginAttempts:      5,
		FailedLoginWindow:           15 * time.Minute,
		BlockDuration:               30 * time.Minute,
		SensitiveEndpointRateLimit:  20,
		SensitiveEndpointWindow:     1 * time.Minute,
		EnableSQLInjectionDetection: true,
		BulkAccessThreshold:         100,
		BulkAccessWindow:            5 * time.Minute,
	}
}

// isLocalhost checks if IP is localhost (for development/testing)
func isLocalhost(ip string) bool {
	return ip == "127.0.0.1" || ip == "::1" || ip == "localhost"
}

// ThreatDetectionMiddleware creates middleware for detecting and preventing threats
func ThreatDetectionMiddleware(auditService *services.AuditService, config ThreatDetectionConfig) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ip := c.IP()
		userAgent := c.Get("User-Agent")

		// Skip all security checks for localhost (development/testing)
		if isLocalhost(ip) {
			return c.Next()
		}

		// Check if IP is blocked
		blocked, err := auditService.IsIPBlocked(ip)
		if err != nil {
			log.Printf("❌ Error checking blocked IP: %v", err)
		}

		if blocked {
			auditService.LogSecurityEvent(
				models.EventUnauthorizedAccess,
				models.SeverityWarning,
				nil,
				ip,
				"Blocked IP attempted to access the system",
				userAgent,
			)
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"error":   "Access denied",
				"message": "Your IP has been temporarily blocked due to suspicious activity. Please try again later.",
			})
		}

		// SQL Injection Detection
		if config.EnableSQLInjectionDetection {
			// Skip SQL injection check for JSON requests (API calls)
			contentType := c.Get("Content-Type")
			isJSONRequest := strings.Contains(strings.ToLower(contentType), "application/json")

			if !isJSONRequest {
				if detected, pattern := detectSQLInjection(c); detected {
					auditService.LogSecurityEvent(
						models.EventSQLInjectionAttempt,
						models.SeverityCritical,
						nil,
						ip,
						fmt.Sprintf("SQL Injection attempt detected. Pattern: %s, Path: %s", pattern, c.Path()),
						userAgent,
					)

					// Block the IP
					auditService.BlockIP(ip, "SQL Injection attempt detected", int(config.BlockDuration.Minutes()))

					return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
						"error":   "Invalid request",
						"message": "Your request has been blocked due to security concerns.",
					})
				}
			}
		}

		return c.Next()
	}
}

// BruteForceProtectionMiddleware protects login endpoint from brute force attacks
func BruteForceProtectionMiddleware(auditService *services.AuditService, config ThreatDetectionConfig) fiber.Handler {
	return func(c *fiber.Ctx) error {
		ip := c.IP()
		_ = c.Get("User-Agent") // Reserved for future logging

		// Skip security checks for localhost (development/testing)
		if isLocalhost(ip) {
			return c.Next()
		}

		// Check if IP is blocked
		blocked, err := auditService.IsIPBlocked(ip)
		if err != nil {
			log.Printf("❌ Error checking blocked IP: %v", err)
		}

		if blocked {
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"error":   "Too many attempts",
				"message": "Your IP has been temporarily blocked due to too many failed login attempts. Please try again later.",
			})
		}

		// Check brute force pattern
		isBruteForce, count, err := auditService.CheckBruteForce(
			ip,
			config.MaxFailedLoginAttempts,
			int(config.FailedLoginWindow.Minutes()),
		)

		if err != nil {
			log.Printf("❌ Error checking brute force: %v", err)
		}

		if isBruteForce {
			// Block the IP
			auditService.BlockIP(ip, "Brute force attack detected", int(config.BlockDuration.Minutes()))

			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"error":   "Too many attempts",
				"message": fmt.Sprintf("Too many failed login attempts (%d). Your IP has been blocked for %d minutes.", count, int(config.BlockDuration.Minutes())),
			})
		}

		// Add attempt count to context for login handler to use
		c.Locals("login_attempt_count", count)

		return c.Next()
	}
}

// AuditMiddleware logs all requests for audit trail
func AuditMiddleware(auditService *services.AuditService) fiber.Handler {
	return func(c *fiber.Ctx) error {
		startTime := time.Now()

		// Continue processing
		err := c.Next()

		// Calculate duration
		duration := time.Since(startTime).Milliseconds()

		// Get user ID if authenticated
		var userID *string
		if uid, ok := c.Locals("user_id").(string); ok && uid != "" {
			userID = &uid
		}

		// Only log write operations (POST, PUT, DELETE, PATCH)
		method := c.Method()
		if method == "POST" || method == "PUT" || method == "DELETE" || method == "PATCH" {
			tableName := extractTableFromPath(c.Path())

			auditService.LogCreate(
				userID,
				tableName,
				"", // Record ID not available at middleware level
				nil,
				c.IP(),
				c.Get("User-Agent"),
				c.Path(),
				c.Response().StatusCode(),
				duration,
			)
		}

		return err
	}
}

// AccountLockoutMiddleware checks if account is locked before allowing login
func AccountLockoutMiddleware(auditService *services.AuditService, config ThreatDetectionConfig) fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Parse email from request body
		var body struct {
			Email string `json:"email"`
		}

		// Save body for later parsing
		bodyBytes := c.Body()

		if err := c.BodyParser(&body); err != nil || body.Email == "" {
			// Continue without check if body parsing fails
			return c.Next()
		}

		// Restore body for next handler
		c.Request().SetBody(bodyBytes)

		// Check if account has too many failed attempts
		isLocked, count, err := auditService.CheckAccountBruteForce(
			body.Email,
			config.MaxFailedLoginAttempts,
			int(config.FailedLoginWindow.Minutes()),
		)

		if err != nil {
			log.Printf("❌ Error checking account lockout: %v", err)
			return c.Next()
		}

		if isLocked {
			auditService.LogSecurityEvent(
				models.EventAccountLocked,
				models.SeverityCritical,
				nil,
				c.IP(),
				fmt.Sprintf("Account locked due to too many failed attempts: %s (%d attempts)", body.Email, count),
				c.Get("User-Agent"),
			)

			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"error":   "Account locked",
				"message": "This account has been temporarily locked due to too many failed login attempts. Please try again later or reset your password.",
			})
		}

		return c.Next()
	}
}

// ==================== SQL INJECTION DETECTION ====================

// SQL injection patterns to detect
var sqlInjectionPatterns = []string{
	// Basic SQL injection
	"'", "\"", ";--", "/*", "*/", "@@", "@",

	// SQL commands
	"SELECT", "INSERT", "UPDATE", "DELETE", "DROP", "CREATE", "ALTER", "TRUNCATE",
	"UNION", "JOIN", "EXEC", "EXECUTE", "xp_", "sp_", "0x",

	// SQL functions
	"CONCAT", "CHAR(", "ASCII(", "SUBSTRING(", "CONVERT(", "CAST(",

	// Boolean-based
	"OR 1=1", "OR '1'='1", "OR \"1\"=\"1", "AND 1=1", "AND '1'='1",
	"' OR '", "' AND '", "\" OR \"", "\" AND \"",

	// Comment markers
	"#", "--", "//", "\\*", "/**/",

	// Time-based
	"SLEEP(", "WAITFOR", "BENCHMARK(",

	// Error-based
	"EXTRACTVALUE", "UPDATEXML",

	// Specific patterns
	"1=1", "1'='1", "1\"=\"1",
}

func detectSQLInjection(c *fiber.Ctx) (bool, string) {
	// Check query parameters
	c.Request().URI().QueryArgs().VisitAll(func(key, value []byte) {
		// Check is done inside the loop
	})

	queryString := string(c.Request().URI().QueryString())
	bodyString := string(c.Body())

	// Combine and check
	fullInput := strings.ToUpper(queryString + " " + bodyString)

	for _, pattern := range sqlInjectionPatterns {
		patternUpper := strings.ToUpper(pattern)
		if strings.Contains(fullInput, patternUpper) {
			// Check for false positives
			if !isFalsePositive(fullInput, patternUpper) {
				return true, pattern
			}
		}
	}

	return false, ""
}

// isFalsePositive checks if the detected pattern is a false positive
func isFalsePositive(input, pattern string) bool {
	// Allow common words that might trigger false positives
	falsePositivePatterns := map[string][]string{
		"SELECT": {"SELECT", "SELECTED", "SELECTION"},   // Allow words containing SELECT
		"UPDATE": {"UPDATED", "UPDATING"},               // Allow words containing UPDATE
		"DELETE": {"DELETED", "DELETING"},               // Allow words containing DELETE
		"OR":     {"ORDER", "ORDINARY", "ORGANIZATION"}, // Allow words containing OR
		"AND":    {"ANDROID", "UNDERSTAND", "HAND"},     // Allow words containing AND
		"DROP":   {"DROPDOWN", "DROPPING"},              // Allow words containing DROP
		"CREATE": {"CREATED", "CREATING", "CREATIVE"},   // Allow words containing CREATE
		"JOIN":   {"JOINED", "JOINING"},                 // Allow words containing JOIN
		"'":      {},                                    // Single quotes are suspicious
		"\"":     {},                                    // Double quotes are suspicious
		";--":    {},                                    // Comment markers are suspicious
		"1=1":    {},                                    // Always suspicious
	}

	// Check if pattern is part of a legitimate word
	if allowedWords, exists := falsePositivePatterns[pattern]; exists {
		for _, word := range allowedWords {
			if strings.Contains(input, word) {
				return true
			}
		}
	}

	// Check if pattern appears in context of a normal sentence
	// This is a simplified check - in production, use more sophisticated NLP

	return false
}

// ==================== HELPER FUNCTIONS ====================

func extractTableFromPath(path string) string {
	// Extract table name from API path
	// e.g., /api/tasks/123 -> tasks
	// e.g., /api/users/profile -> users

	parts := strings.Split(strings.Trim(path, "/"), "/")

	if len(parts) >= 2 && parts[0] == "api" {
		return parts[1]
	}

	if len(parts) >= 1 {
		return parts[0]
	}

	return "unknown"
}

// XSSProtectionMiddleware prevents XSS attacks
func XSSProtectionMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Add XSS protection headers
		c.Set("X-XSS-Protection", "1; mode=block")
		c.Set("X-Content-Type-Options", "nosniff")
		c.Set("Content-Security-Policy", "default-src 'self'")

		return c.Next()
	}
}

// SensitiveDataProtectionMiddleware masks sensitive data in responses
func SensitiveDataProtectionMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// This middleware can be extended to mask sensitive data in responses
		// For now, it relies on struct tags (json:"-") for hiding sensitive fields
		return c.Next()
	}
}
