package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/services"
)

type SubscriptionHandler struct {
	subscriptionService *services.SubscriptionService
}

func NewSubscriptionHandler(subscriptionService *services.SubscriptionService) *SubscriptionHandler {
	return &SubscriptionHandler{subscriptionService: subscriptionService}
}

// UpgradeToVIP upgrade user ke VIP
// POST /api/subscription/upgrade
func (h *SubscriptionHandler) UpgradeToVIP(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var req struct {
		PlanType      string `json:"plan_type"`      // "monthly" or "yearly"
		PaymentMethod string `json:"payment_method"` // "credit_card", "bank_transfer", etc
		TransactionID string `json:"transaction_id"` // Payment transaction ID
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate plan type
	planType := models.PlanType(req.PlanType)
	if planType != models.PlanTypeMonthly && planType != models.PlanTypeYearly {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid plan type. Use 'monthly' or 'yearly'",
		})
	}

	// Create subscription
	subscription, err := h.subscriptionService.CreateSubscription(userID, planType, req.PaymentMethod, req.TransactionID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"message":      "Upgraded to VIP successfully",
		"subscription": subscription,
	})
}

// GetVIPStatus mendapatkan status VIP user
// GET /api/subscription/status
func (h *SubscriptionHandler) GetVIPStatus(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	// Check and downgrade if expired
	_ = h.subscriptionService.CheckAndDowngradeExpired(userID)

	status, err := h.subscriptionService.GetVIPStatus(userID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(status)
}

// GetHistory mendapatkan riwayat subscription
// GET /api/subscription/history
func (h *SubscriptionHandler) GetHistory(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	subscriptions, err := h.subscriptionService.GetSubscriptionHistory(userID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"subscriptions": subscriptions,
		"count":         len(subscriptions),
	})
}
