package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

// MFAHandler handles MFA-related endpoints
type MFAHandler struct {
	mfaService *services.MFAService
}

// NewMFAHandler creates a new MFA handler
func NewMFAHandler(mfaService *services.MFAService) *MFAHandler {
	return &MFAHandler{
		mfaService: mfaService,
	}
}

// GetMFAStatus returns the current MFA status for the user
// GET /api/auth/mfa/status
func (h *MFAHandler) GetMFAStatus(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	user, err := h.mfaService.GetMFAStatus(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to get MFA status",
		})
	}

	return c.JSON(fiber.Map{
		"mfa_enabled": user.MFAEnabled,
		"has_secret":  user.MFASecret != nil && *user.MFASecret != "",
	})
}

// EnableMFA generates a new MFA secret and returns QR code URL
// POST /api/auth/mfa/enable
func (h *MFAHandler) EnableMFA(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	// Check if MFA is already enabled
	enabled, err := h.mfaService.IsMFAEnabled(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to check MFA status",
		})
	}

	if enabled {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "MFA is already enabled for this account",
		})
	}

	// Generate new secret
	response, err := h.mfaService.GenerateSecret(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to generate MFA secret",
		})
	}

	return c.JSON(fiber.Map{
		"message":     "MFA secret generated. Please scan the QR code and verify with a code from your authenticator app.",
		"secret":      response.Secret,
		"qr_code_url": response.QRCodeURL,
		"manual_code": response.ManualCode,
		"instructions": []string{
			"1. Download Google Authenticator or similar app",
			"2. Scan the QR code or enter the manual code",
			"3. Enter the 6-digit code from the app to verify",
		},
	})
}

// VerifyMFA verifies the TOTP code and enables MFA
// POST /api/auth/mfa/verify
func (h *MFAHandler) VerifyMFA(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var req struct {
		Code string `json:"code"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.Code == "" || len(req.Code) != 6 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Please provide a valid 6-digit code",
		})
	}

	if err := h.mfaService.VerifyAndEnable(userID, req.Code); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"message":     "MFA has been successfully enabled for your account",
		"mfa_enabled": true,
	})
}

// DisableMFA disables MFA for the user
// POST /api/auth/mfa/disable
func (h *MFAHandler) DisableMFA(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var req struct {
		Code string `json:"code"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.Code == "" || len(req.Code) != 6 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Please provide a valid 6-digit code to disable MFA",
		})
	}

	if err := h.mfaService.DisableMFA(userID, req.Code); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"message":     "MFA has been successfully disabled",
		"mfa_enabled": false,
	})
}

// VerifyMFALogin verifies MFA code during login (called after password verification)
// POST /api/auth/mfa/login
func (h *MFAHandler) VerifyMFALogin(c *fiber.Ctx) error {
	var req struct {
		UserID string `json:"user_id"`
		Code   string `json:"code"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.UserID == "" || req.Code == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "User ID and code are required",
		})
	}

	if len(req.Code) != 6 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Please provide a valid 6-digit code",
		})
	}

	if err := h.mfaService.VerifyLogin(req.UserID, req.Code); err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"message":  "MFA verification successful",
		"verified": true,
	})
}
