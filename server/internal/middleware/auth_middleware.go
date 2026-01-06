package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
	"github.com/workradar/server/pkg/utils"
)

// AuthMiddleware memvalidasi JWT token
func AuthMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		authHeader := c.Get("Authorization")
		if authHeader == "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Missing authorization header",
			})
		}

		// Extract token from "Bearer <token>"
		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || parts[0] != "Bearer" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Invalid authorization format",
			})
		}

		token := parts[1]

		// Validate token
		claims, err := utils.ValidateToken(token)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Invalid or expired token",
			})
		}

		// Check if token is access token (not refresh token)
		if claims.Type != "access" && claims.Type != "" {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Invalid token type",
			})
		}

		// Check if token is blacklisted (logged out)
		blacklistService := services.GetTokenBlacklistService()
		if blacklistService.IsBlacklisted(claims.ID) {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "Token has been revoked",
			})
		}

		// Store user info in context
		c.Locals("user_id", claims.UserID)
		c.Locals("user_email", claims.Email)
		c.Locals("user_type", claims.UserType)

		return c.Next()
	}
}

// VIPMiddleware memvalidasi apakah user adalah VIP
func VIPMiddleware() fiber.Handler {
	return func(c *fiber.Ctx) error {
		userType := c.Locals("user_type")
		if userType != "vip" {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"error": "This feature is only available for VIP members",
			})
		}
		return c.Next()
	}
}
