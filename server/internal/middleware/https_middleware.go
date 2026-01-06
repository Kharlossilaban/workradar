package middleware

import (
	"os"
	"strings"

	"github.com/gofiber/fiber/v2"
)

// HTTPSRedirectConfig holds configuration for HTTPS redirect middleware
type HTTPSRedirectConfig struct {
	// Enabled determines if HTTPS redirect is active
	Enabled bool
	// ExcludePaths lists paths that don't require HTTPS redirect (e.g., health checks)
	ExcludePaths []string
	// STSMaxAge sets the max-age for Strict-Transport-Security header (default: 31536000 = 1 year)
	STSMaxAge int
	// IncludeSubdomains includes subdomains in HSTS
	IncludeSubdomains bool
	// Preload enables HSTS preload
	Preload bool
}

// DefaultHTTPSRedirectConfig returns default HTTPS redirect configuration
func DefaultHTTPSRedirectConfig() HTTPSRedirectConfig {
	return HTTPSRedirectConfig{
		Enabled:           os.Getenv("HTTPS_REDIRECT_ENABLED") == "true",
		ExcludePaths:      []string{"/api/health", "/api/webhooks"},
		STSMaxAge:         31536000, // 1 year
		IncludeSubdomains: true,
		Preload:           false,
	}
}

// HTTPSRedirectMiddleware redirects HTTP requests to HTTPS
// This is essential for production environments to ensure encrypted communication
func HTTPSRedirectMiddleware(config ...HTTPSRedirectConfig) fiber.Handler {
	cfg := DefaultHTTPSRedirectConfig()
	if len(config) > 0 {
		cfg = config[0]
	}

	return func(c *fiber.Ctx) error {
		// Skip if disabled
		if !cfg.Enabled {
			return c.Next()
		}

		// Check if path should be excluded
		path := c.Path()
		for _, excludePath := range cfg.ExcludePaths {
			if strings.HasPrefix(path, excludePath) {
				return c.Next()
			}
		}

		// Check if request is already HTTPS
		// X-Forwarded-Proto is set by reverse proxies (nginx, cloudflare, etc.)
		proto := c.Get("X-Forwarded-Proto")
		if proto == "" {
			proto = c.Protocol()
		}

		// If already HTTPS, add HSTS header and continue
		if proto == "https" {
			// Add Strict-Transport-Security header
			stsValue := "max-age=" + string(rune(cfg.STSMaxAge))
			if cfg.IncludeSubdomains {
				stsValue += "; includeSubDomains"
			}
			if cfg.Preload {
				stsValue += "; preload"
			}
			c.Set("Strict-Transport-Security", stsValue)
			return c.Next()
		}

		// Build HTTPS URL
		host := c.Hostname()
		originalURL := string(c.Request().RequestURI())
		httpsURL := "https://" + host + originalURL

		// Redirect to HTTPS
		return c.Redirect(httpsURL, fiber.StatusMovedPermanently)
	}
}

// ForceHTTPSMiddleware forces HTTPS for specific routes
// Returns 403 Forbidden if request is not over HTTPS
func ForceHTTPSMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Check X-Forwarded-Proto header (set by reverse proxy)
		proto := c.Get("X-Forwarded-Proto")
		if proto == "" {
			proto = c.Protocol()
		}

		if proto != "https" {
			// In production, reject non-HTTPS requests to sensitive endpoints
			if os.Getenv("GO_ENV") == "production" {
				return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
					"success": false,
					"message": "HTTPS is required for this endpoint",
					"error":   "insecure_connection",
				})
			}
		}

		return c.Next()
	}
}

// SecureHeadersEnhancedMiddleware adds enhanced security headers for encrypted connections
// This is in addition to the basic SecurityHeadersMiddleware
func SecureHeadersEnhancedMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Certificate Transparency
		c.Set("Expect-CT", "max-age=86400, enforce")

		// Prevent information leakage
		c.Set("X-DNS-Prefetch-Control", "off")
		c.Set("X-Download-Options", "noopen")
		c.Set("X-Permitted-Cross-Domain-Policies", "none")

		// Feature Policy / Permissions Policy
		c.Set("Permissions-Policy", "accelerometer=(), camera=(), geolocation=(self), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()")

		return c.Next()
	}
}

// TLSVersionCheckMiddleware checks if client supports modern TLS
func TLSVersionCheckMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// This is more relevant at the reverse proxy level (nginx, etc.)
		// But we can check headers set by proxies
		tlsVersion := c.Get("X-TLS-Version")
		if tlsVersion != "" {
			// Log if client uses outdated TLS
			if tlsVersion == "TLSv1.0" || tlsVersion == "TLSv1.1" {
				// Log warning - these versions are deprecated
				// In strict mode, you could reject these connections
			}
		}

		return c.Next()
	}
}
