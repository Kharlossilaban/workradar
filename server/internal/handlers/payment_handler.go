package handlers

import (
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/services"
)

type PaymentHandler struct {
	paymentService *services.PaymentService
}

func NewPaymentHandler(paymentService *services.PaymentService) *PaymentHandler {
	return &PaymentHandler{paymentService: paymentService}
}

// GetSnapToken request token pembayaran
// POST /api/payment/token
func (h *PaymentHandler) GetSnapToken(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var req struct {
		PlanType string `json:"plan_type"` // "monthly" or "yearly"
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Create Snap Token
	snapToken, redirectURL, orderID, err := h.paymentService.CreateSnapToken(userID, models.PlanType(req.PlanType))
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"token":        snapToken,
		"redirect_url": redirectURL,
		"order_id":     orderID,
	})
}

// HandleNotification webhook midtrans
// POST /api/payment/notification
func (h *PaymentHandler) HandleNotification(c *fiber.Ctx) error {
	var notificationPayload map[string]interface{}

	if err := c.BodyParser(&notificationPayload); err != nil {
		log.Printf("Error parsing notification: %v", err)
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid notification payload",
		})
	}

	// Process notification in background / service
	if err := h.paymentService.HandleNotification(notificationPayload); err != nil {
		log.Printf("Error handling notification: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to process notification",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"status": "OK",
	})
}

// GetPaymentStatus gets the status of a specific transaction
// GET /api/payments/:order_id
func (h *PaymentHandler) GetPaymentStatus(c *fiber.Ctx) error {
	orderID := c.Params("order_id")

	// Get transaction from service
	transaction, err := h.paymentService.GetTransactionByOrderID(orderID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"status":  "error",
			"message": "Transaction not found",
		})
	}

	return c.JSON(fiber.Map{
		"status": "success",
		"data":   transaction,
	})
}

// GetPaymentHistory retrieves payment history for the current user
// GET /api/payments/history
func (h *PaymentHandler) GetPaymentHistory(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	transactions, err := h.paymentService.GetPaymentHistory(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"status":  "error",
			"message": "Failed to retrieve payment history",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status": "success",
		"data":   transactions,
	})
}

// CancelPayment cancels a pending payment
// POST /api/payments/:order_id/cancel
func (h *PaymentHandler) CancelPayment(c *fiber.Ctx) error {
	orderID := c.Params("order_id")

	if err := h.paymentService.CancelTransaction(orderID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"status":  "error",
			"message": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"status":  "success",
		"message": "Payment cancelled successfully",
	})
}
