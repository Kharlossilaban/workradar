package handlers

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type OAuthHandler struct {
	oauthService *services.OAuthService
	authService  *services.AuthService
}

func NewOAuthHandler(oauthService *services.OAuthService, authService *services.AuthService) *OAuthHandler {
	return &OAuthHandler{
		oauthService: oauthService,
		authService:  authService,
	}
}

// GoogleLogin initiates Google OAuth flow
// GET /api/auth/google
func (h *OAuthHandler) GoogleLogin(c *fiber.Ctx) error {
	// Generate random state for CSRF protection
	state, err := generateRandomState()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to generate state",
		})
	}

	// Store state in session/cookie (for CSRF validation)
	c.Cookie(&fiber.Cookie{
		Name:     "oauth_state",
		Value:    state,
		HTTPOnly: true,
		Secure:   false, // Set to true in production with HTTPS
		SameSite: "Lax",
	})

	// Get OAuth URL
	authURL := h.oauthService.GetAuthURL(state)

	return c.JSON(fiber.Map{
		"auth_url": authURL,
	})
}

// GoogleCallback handles Google OAuth callback
// GET /api/auth/google/callback
func (h *OAuthHandler) GoogleCallback(c *fiber.Ctx) error {
	// Get state and code from query
	state := c.Query("state")
	code := c.Query("code")

	if code == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Authorization code not provided",
		})
	}

	// Validate state for CSRF protection
	storedState := c.Cookies("oauth_state")
	if state != storedState {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid state parameter",
		})
	}

	// Clear state cookie
	c.ClearCookie("oauth_state")

	// Exchange code for token
	token, err := h.oauthService.ExchangeCode(c.Context(), code)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": fmt.Sprintf("Failed to exchange code: %v", err),
		})
	}

	// Get user info from Google
	userInfo, err := h.oauthService.GetUserInfo(c.Context(), token)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": fmt.Sprintf("Failed to get user info: %v", err),
		})
	}

	// Validate email is verified
	if !userInfo.VerifiedEmail {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Email is not verified on Google account",
		})
	}

	// Login or create user
	user, jwtToken, isNew, err := h.authService.GoogleOAuthLogin(
		userInfo.ID,
		userInfo.Email,
		userInfo.Name,
		userInfo.Picture,
	)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": fmt.Sprintf("Failed to process Google login: %v", err),
		})
	}

	// Return user data and JWT token
	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message":     "Google login successful",
		"is_new_user": isNew,
		"token":       jwtToken,
		"user": fiber.Map{
			"id":              user.ID,
			"email":           user.Email,
			"username":        user.Username,
			"profile_picture": user.ProfilePicture,
			"user_type":       user.UserType,
			"auth_provider":   user.AuthProvider,
		},
	})
}

// Helper function to generate random state
func generateRandomState() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(b), nil
}
