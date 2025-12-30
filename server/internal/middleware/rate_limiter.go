package middleware

import (
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
)

// RateLimiter struct untuk track requests
type RateLimiter struct {
	visitors map[string]*Visitor
	mu       sync.RWMutex
	cleanup  *time.Ticker
}

// Visitor struct untuk track request per IP/User
type Visitor struct {
	lastSeen time.Time
	requests []time.Time
}

var rateLimiter *RateLimiter

func init() {
	rateLimiter = &RateLimiter{
		visitors: make(map[string]*Visitor),
		cleanup:  time.NewTicker(5 * time.Minute),
	}

	// Cleanup goroutine
	go func() {
		for range rateLimiter.cleanup.C {
			rateLimiter.cleanupOldVisitors()
		}
	}()
}

// RateLimitMiddleware membatasi request per menit
func RateLimitMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		// Get identifier (IP atau User ID jika authenticated)
		identifier := c.IP()
		userID := c.Locals("user_id")

		var limit int
		var window time.Duration

		// Special limits untuk login endpoint (prevent brute force)
		if c.Path() == "/api/auth/login" || c.Path() == "/api/auth/register" {
			limit = 5
			window = 1 * time.Minute
		} else if userID != nil {
			// Authenticated user
			identifier = userID.(string)

			// Check if VIP
			userType := c.Locals("user_type")
			if userType == "vip" {
				limit = 120 // VIP: 120 req/min
			} else {
				limit = 60 // Regular: 60 req/min
			}
			window = 1 * time.Minute
		} else {
			// Anonymous/unauthenticated
			limit = 30 // 30 req/min untuk anonymous
			window = 1 * time.Minute
		}

		// Check rate limit
		if !rateLimiter.allow(identifier, limit, window) {
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"error": "Too many requests. Please try again later.",
			})
		}

		return c.Next()
	}
}

// allow checks if request is allowed
func (rl *RateLimiter) allow(identifier string, limit int, window time.Duration) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	visitor, exists := rl.visitors[identifier]

	if !exists {
		// New visitor
		rl.visitors[identifier] = &Visitor{
			lastSeen: now,
			requests: []time.Time{now},
		}
		return true
	}

	// Update last seen
	visitor.lastSeen = now

	// Remove old requests outside window
	var validRequests []time.Time
	for _, req := range visitor.requests {
		if now.Sub(req) < window {
			validRequests = append(validRequests, req)
		}
	}

	// Check if limit exceeded
	if len(validRequests) >= limit {
		visitor.requests = validRequests
		return false
	}

	// Add current request
	validRequests = append(validRequests, now)
	visitor.requests = validRequests

	return true
}

// cleanupOldVisitors removes visitors yang sudah tidak aktif
func (rl *RateLimiter) cleanupOldVisitors() {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	for identifier, visitor := range rl.visitors {
		// Remove jika tidak ada activity dalam 10 menit
		if now.Sub(visitor.lastSeen) > 10*time.Minute {
			delete(rl.visitors, identifier)
		}
	}
}
