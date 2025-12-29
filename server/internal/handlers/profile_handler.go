package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type ProfileHandler struct {
	profileService *services.ProfileService
}

func NewProfileHandler(profileService *services.ProfileService) *ProfileHandler {
	return &ProfileHandler{profileService: profileService}
}

// GetFullProfile mendapatkan profile lengkap dengan stats
// GET /api/profile
func (h *ProfileHandler) GetFullProfile(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	profile, err := h.profileService.GetFullProfile(userID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(profile)
}

// GetStats mendapatkan stats saja
// GET /api/profile/stats
func (h *ProfileHandler) GetStats(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	stats, err := h.profileService.GetUserStats(userID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"stats": stats,
	})
}
