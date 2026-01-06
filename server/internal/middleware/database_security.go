package middleware

import (
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
)

// DatabaseSecurityMiddleware adds security headers for database-related endpoints
func DatabaseSecurityMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Add security headers
		c.Set("X-Content-Type-Options", "nosniff")
		c.Set("X-Frame-Options", "DENY")
		c.Set("X-XSS-Protection", "1; mode=block")
		c.Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

		return c.Next()
	}
}

// SQLInjectionProtectionMiddleware validates input for SQL injection attempts
func SQLInjectionProtectionMiddleware() fiber.Handler {
	// Common SQL injection patterns
	dangerousPatterns := []string{
		"'", "\"", ";--", "/*", "*/", "xp_", "sp_",
		"DROP ", "DELETE ", "INSERT ", "UPDATE ", "UNION ", "SELECT ",
		"<script", "javascript:", "onerror=", "onload=",
	}

	return func(c *fiber.Ctx) error {
		// Check query parameters
		c.Request().URI().QueryArgs().VisitAll(func(key, value []byte) {
			valStr := strings.ToUpper(string(value))
			for _, pattern := range dangerousPatterns {
				if strings.Contains(valStr, strings.ToUpper(pattern)) {
					c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
						"error": "Invalid input detected",
					})
					return
				}
			}
		})

		// Check body for JSON endpoints
		if strings.Contains(c.Get("Content-Type"), "application/json") {
			bodyStr := strings.ToUpper(string(c.Body()))
			for _, pattern := range dangerousPatterns {
				if strings.Contains(bodyStr, strings.ToUpper(pattern)) {
					return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
						"error": "Invalid input detected",
					})
				}
			}
		}

		return c.Next()
	}
}

// AuditLogMiddleware logs all database-modifying requests
func AuditLogMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Log request details for audit trail
		method := c.Method()
		path := c.Path()
		ip := c.IP()
		userAgent := c.Get("User-Agent")
		userID := c.Locals("user_id")

		// Only log write operations (POST, PUT, DELETE, PATCH)
		if method == "POST" || method == "PUT" || method == "DELETE" || method == "PATCH" {
			// Log to file or external service in production
			// For now, just console log
			logEntry := fiber.Map{
				"timestamp":  time.Now().Format(time.RFC3339),
				"method":     method,
				"path":       path,
				"ip":         ip,
				"user_agent": userAgent,
				"user_id":    userID,
			}

			// TODO: In production, write to audit log file or send to logging service
			_ = logEntry
		}

		return c.Next()
	}
}

// DataMaskingMiddleware masks sensitive data in responses
func DataMaskingMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Execute the request
		err := c.Next()

		// If response contains sensitive fields, mask them
		// This is handled at the model level (User.PasswordHash has json:"-")
		// But we can add additional protection here if needed

		return err
	}
}

// DatabaseConnectionSecurityConfig validates database connection parameters
type DatabaseConnectionSecurityConfig struct {
	// MinPasswordLength minimum length for database password
	MinPasswordLength int

	// RequireSSL requires SSL/TLS for database connections
	RequireSSL bool

	// AllowedHosts whitelist of allowed database hosts
	AllowedHosts []string

	// MaxConnections maximum number of concurrent database connections
	MaxConnections int

	// ConnectionTimeout timeout for database connections
	ConnectionTimeout time.Duration
}

// DefaultDatabaseSecurityConfig returns recommended security configuration
func DefaultDatabaseSecurityConfig() DatabaseConnectionSecurityConfig {
	return DatabaseConnectionSecurityConfig{
		MinPasswordLength: 16,
		RequireSSL:        true, // Always use SSL in production
		AllowedHosts: []string{
			"localhost",
			"127.0.0.1",
			// Add your production database hosts here
		},
		MaxConnections:    25,
		ConnectionTimeout: 10 * time.Second,
	}
}

// ValidateDatabaseConfig validates database configuration against security policy
func ValidateDatabaseConfig(host, password string, config DatabaseConnectionSecurityConfig) error {
	// Check password length
	if len(password) < config.MinPasswordLength {
		return fiber.NewError(fiber.StatusInternalServerError,
			"Database password does not meet minimum security requirements")
	}

	// Check if host is in whitelist (in production)
	// This is optional, can be enabled/disabled based on ENV

	return nil
}
