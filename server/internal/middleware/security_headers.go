package middleware

import (
	"fmt"

	"github.com/gofiber/fiber/v2"
)

// SecurityHeadersMiddleware menambahkan security headers
func SecurityHeadersMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Prevent MIME type sniffing
		c.Set("X-Content-Type-Options", "nosniff")

		// Prevent clickjacking
		c.Set("X-Frame-Options", "DENY")

		// XSS Protection
		c.Set("X-XSS-Protection", "1; mode=block")

		// HSTS (HTTP Strict Transport Security)
		// Only for HTTPS in production
		if c.Protocol() == "https" {
			c.Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		}

		// Content Security Policy
		c.Set("Content-Security-Policy", "default-src 'self'")

		// Referrer Policy
		c.Set("Referrer-Policy", "no-referrer")

		// Permissions Policy
		c.Set("Permissions-Policy", "geolocation=(), camera=(), microphone=()")

		return c.Next()
	}
}

// RequestIDMiddleware menambahkan unique request ID
func RequestIDMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Generate request ID dari header atau buat baru
		requestID := c.Get("X-Request-ID")
		if requestID == "" {
			// Convert uint64 to string
			requestID = fmt.Sprintf("%d", c.Context().ID())
		}

		// Set ke context dan response header
		c.Locals("request_id", requestID)
		c.Set("X-Request-ID", requestID)

		return c.Next()
	}
}
