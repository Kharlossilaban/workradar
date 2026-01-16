package handlers

import (
	"context"
	"fmt"
	"log"

	"github.com/gofiber/fiber/v2"
	"google.golang.org/api/idtoken"
)

// GoogleMobileAuthRequest represents the request from mobile app
type GoogleMobileAuthRequest struct {
	IDToken string `json:"id_token" validate:"required"`
}

// GoogleMobileAuth handles Google Sign-In from mobile app
// POST /api/auth/google/mobile
// Accepts ID Token from Google Sign-In SDK
func (h *OAuthHandler) GoogleMobileAuth(c *fiber.Ctx) error {
	var req GoogleMobileAuthRequest

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.IDToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ID token is required",
		})
	}

	log.Printf("[GoogleMobileAuth] 🔵 Received ID token from mobile app (length: %d)", len(req.IDToken))

	// Verify ID token with Google
	// Note: In production, you should set the audience to your Google Client ID
	// For now, we'll validate the token structure and extract user info
	payload, err := idtoken.Validate(context.Background(), req.IDToken, "")
	if err != nil {
		log.Printf("[GoogleMobileAuth] ❌ Failed to validate ID token: %v", err)
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": "Invalid ID token",
		})
	}

	log.Printf("[GoogleMobileAuth] ✅ ID token validated successfully")

	// Extract user info from payload
	googleID, ok := payload.Claims["sub"].(string)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid token: missing user ID",
		})
	}

	email, ok := payload.Claims["email"].(string)
	if !ok {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid token: missing email",
		})
	}

	// Check if email is verified
	emailVerified, _ := payload.Claims["email_verified"].(bool)
	if !emailVerified {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Email is not verified on Google account",
		})
	}

	name, _ := payload.Claims["name"].(string)
	picture, _ := payload.Claims["picture"].(string)

	log.Printf("[GoogleMobileAuth] 📧 User: %s (%s)", name, email)

	// Login or create user
	user, jwtToken, refreshToken, isNew, err := h.authService.GoogleOAuthLogin(
		googleID,
		email,
		name,
		picture,
	)
	if err != nil {
		log.Printf("[GoogleMobileAuth] ❌ Failed to process Google login: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": fmt.Sprintf("Failed to process Google login: %v", err),
		})
	}

	log.Printf("[GoogleMobileAuth] ✅ User authenticated successfully (isNew: %v)", isNew)

	// Return user data and JWT tokens
	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message":       "Google login successful",
		"is_new_user":   isNew,
		"token":         jwtToken,
		"refresh_token": refreshToken,
		"user": fiber.Map{
			"id":              user.ID,
			"email":           user.Email,
			"username":        user.Username,
			"profile_picture": user.ProfilePicture,
			"user_type":       user.UserType,
			"auth_provider":   user.AuthProvider,
			"created_at":      user.CreatedAt,
			"updated_at":      user.UpdatedAt,
		},
	})
}
