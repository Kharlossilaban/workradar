package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
	"github.com/workradar/server/pkg/utils"
)

// RefreshToken endpoint untuk get new access token
// POST /api/auth/refresh
func (h *AuthHandler) RefreshToken(c *fiber.Ctx) error {
	type RefreshRequest struct {
		RefreshToken string `json:"refresh_token"`
	}

	var req RefreshRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.RefreshToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Refresh token is required",
		})
	}

	// Validate refresh token
	claims, err := utils.ValidateToken(req.RefreshToken)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "Invalid or expired refresh token",
		})
	}

	// Check token type
	if claims.Type != "refresh" {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "Invalid token type",
		})
	}

	// Check blacklist
	blacklistService := services.GetTokenBlacklistService()
	if blacklistService.IsBlacklisted(claims.ID) {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "Refresh token has been revoked",
		})
	}

	// Generate new access token
	newAccessToken, err := utils.GenerateAccessToken(claims.UserID, claims.Email, claims.UserType)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to generate access token",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"access_token": newAccessToken,
	})
}

// Logout endpoint untuk blacklist token
// POST /api/auth/logout
func (h *AuthHandler) Logout(c *fiber.Ctx) error {
	type LogoutRequest struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}

	var req LogoutRequest
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	blacklistService := services.GetTokenBlacklistService()

	// Blacklist access token
	if req.AccessToken != "" {
		jti, err := utils.GetJTI(req.AccessToken)
		if err == nil {
			claims, _ := utils.ValidateToken(req.AccessToken)
			if claims != nil {
				blacklistService.AddToken(jti, claims.ExpiresAt.Time)
			}
		}
	}

	// Blacklist refresh token
	if req.RefreshToken != "" {
		jti, err := utils.GetJTI(req.RefreshToken)
		if err == nil {
			claims, _ := utils.ValidateToken(req.RefreshToken)
			if claims != nil {
				blacklistService.AddToken(jti, claims.ExpiresAt.Time)
			}
		}
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Logged out successfully",
	})
}
