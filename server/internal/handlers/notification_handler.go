package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type NotificationHandler struct {
	notificationService *services.NotificationService
}

func NewNotificationHandler(notificationService *services.NotificationService) *NotificationHandler {
	return &NotificationHandler{
		notificationService: notificationService,
	}
}

// RegisterDevice registers a device FCM token
// POST /api/notifications/register-device
func (h *NotificationHandler) RegisterDevice(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var req struct {
		FCMToken string `json:"fcm_token"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.FCMToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "FCM token is required",
		})
	}

	if err := h.notificationService.RegisterDevice(userID, req.FCMToken); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Device registered successfully",
	})
}

// UnregisterDevice removes FCM token from user
// DELETE /api/notifications/register-device
func (h *NotificationHandler) UnregisterDevice(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	if err := h.notificationService.UnregisterDevice(userID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Device unregistered successfully",
	})
}

// SendTestNotification sends a test notification (for testing purposes)
// POST /api/notifications/test
func (h *NotificationHandler) SendTestNotification(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var req struct {
		Type    string  `json:"type"` // "task", "weather", "health"
		Message string  `json:"message"`
		Hours   float64 `json:"hours,omitempty"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	var err error
	switch req.Type {
	case "health":
		hours := req.Hours
		if hours == 0 {
			hours = 10.5
		}
		err = h.notificationService.SendHealthRecommendation(userID, req.Message, hours)
	case "weather":
		err = h.notificationService.SendWeatherAlert(userID, "Jakarta", "Cerah", 28.5)
	default:
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid notification type. Use: task, weather, or health",
		})
	}

	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Test notification sent successfully",
	})
}
