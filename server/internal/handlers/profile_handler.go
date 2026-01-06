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

// GetWorkHours mendapatkan konfigurasi jam kerja user
// GET /api/profile/work-hours
func (h *ProfileHandler) GetWorkHours(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	workDays, err := h.profileService.GetWorkHours(userID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"work_days": workDays,
	})
}

// UpdateWorkHours mengupdate konfigurasi jam kerja user
// PUT /api/profile/work-hours
func (h *ProfileHandler) UpdateWorkHours(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var requestBody struct {
		WorkDays map[string]interface{} `json:"work_days"`
	}

	if err := c.BodyParser(&requestBody); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if err := h.profileService.UpdateWorkHours(userID, requestBody.WorkDays); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message":   "Work hours updated successfully",
		"work_days": requestBody.WorkDays,
	})
}
