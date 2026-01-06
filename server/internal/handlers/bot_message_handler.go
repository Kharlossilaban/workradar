package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type BotMessageHandler struct {
	service *services.BotMessageService
}

func NewBotMessageHandler(service *services.BotMessageService) *BotMessageHandler {
	return &BotMessageHandler{service: service}
}

// GetMessages retrieves all messages for the current user
func (h *BotMessageHandler) GetMessages(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	messages, err := h.service.GetUserMessages(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"status":  "error",
			"message": "Failed to retrieve messages",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status": "success",
		"data":   messages,
	})
}

// GetUnreadMessages retrieves unread messages for the current user
func (h *BotMessageHandler) GetUnreadMessages(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	messages, err := h.service.GetUnreadMessages(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"status":  "error",
			"message": "Failed to retrieve unread messages",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status": "success",
		"data":   messages,
	})
}

// GetUnreadCount retrieves the count of unread messages
func (h *BotMessageHandler) GetUnreadCount(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	count, err := h.service.GetUnreadCount(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"status":  "error",
			"message": "Failed to count unread messages",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status": "success",
		"data":   fiber.Map{"count": count},
	})
}

// MarkAsRead marks a specific message as read
func (h *BotMessageHandler) MarkAsRead(c *fiber.Ctx) error {
	messageID := c.Params("id")

	if err := h.service.MarkAsRead(messageID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"status":  "error",
			"message": "Failed to mark message as read",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status":  "success",
		"message": "Message marked as read",
	})
}

// MarkAllAsRead marks all messages as read for the user
func (h *BotMessageHandler) MarkAllAsRead(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	if err := h.service.MarkAllAsRead(userID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"status":  "error",
			"message": "Failed to mark all messages as read",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status":  "success",
		"message": "All messages marked as read",
	})
}

// DeleteMessage deletes a message
func (h *BotMessageHandler) DeleteMessage(c *fiber.Ctx) error {
	messageID := c.Params("id")

	if err := h.service.DeleteMessage(messageID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"status":  "error",
			"message": "Failed to delete message",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status":  "success",
		"message": "Message deleted",
	})
}
