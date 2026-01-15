package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type ChatHandler struct {
	aiService *services.AIService
}

func NewChatHandler(aiService *services.AIService) *ChatHandler {
	return &ChatHandler{aiService: aiService}
}

// Chat handles AI chat requests
// POST /api/ai/chat
func (h *ChatHandler) Chat(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var req struct {
		Message string `json:"message"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Format request tidak valid",
		})
	}

	if req.Message == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Pesan tidak boleh kosong",
		})
	}

	response, err := h.aiService.GenerateResponse(userID, req.Message)
	if err != nil {
		// Return proper error message from service
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"response": response,
	})
}

// GetHistory returns chat history for a user
// GET /api/ai/history
func (h *ChatHandler) GetHistory(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	history, err := h.aiService.GetChatHistory(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"messages": history, // Changed from "history" to "messages" to match frontend
	})
}

// ClearHistory deletes all chat history for a user
// DELETE /api/ai/history
func (h *ChatHandler) ClearHistory(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	if err := h.aiService.ClearChatHistory(userID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Chat history cleared successfully",
	})
}
