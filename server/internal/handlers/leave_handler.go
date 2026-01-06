package handlers

import (
	"strconv"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type LeaveHandler struct {
	leaveService *services.LeaveService
}

func NewLeaveHandler(leaveService *services.LeaveService) *LeaveHandler {
	return &LeaveHandler{leaveService: leaveService}
}

// GetLeaves mendapatkan leaves berdasarkan filter
// GET /api/leaves?filter=all|upcoming|past&year=2026&month=1
func (h *LeaveHandler) GetLeaves(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	filter := c.Query("filter", "all") // all, upcoming, past
	yearStr := c.Query("year")
	monthStr := c.Query("month")

	// If year and month provided, get leaves by month
	if yearStr != "" && monthStr != "" {
		year, err := strconv.Atoi(yearStr)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid year format",
			})
		}

		monthInt, err := strconv.Atoi(monthStr)
		if err != nil || monthInt < 1 || monthInt > 12 {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid month format",
			})
		}

		month := time.Month(monthInt)
		leaves, err := h.leaveService.GetLeavesByMonth(userID, year, month)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Failed to fetch leaves",
			})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"leaves": leaves,
		})
	}

	// Filter-based queries
	var leaves interface{}
	var err error

	switch filter {
	case "upcoming":
		leaves, err = h.leaveService.GetUpcomingLeaves(userID)
	case "past":
		leaves, err = h.leaveService.GetPastLeaves(userID)
	default:
		leaves, err = h.leaveService.GetAllLeaves(userID)
	}

	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to fetch leaves",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"leaves": leaves,
	})
}

// CreateLeave membuat leave baru
// POST /api/leaves
func (h *LeaveHandler) CreateLeave(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var requestBody struct {
		Date   string `json:"date"` // Format: YYYY-MM-DD
		Reason string `json:"reason"`
	}

	if err := c.BodyParser(&requestBody); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if requestBody.Date == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Date is required",
		})
	}

	if requestBody.Reason == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Reason is required",
		})
	}

	// Parse date
	date, err := time.Parse("2006-01-02", requestBody.Date)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid date format. Use YYYY-MM-DD",
		})
	}

	// Create leave
	leave, err := h.leaveService.CreateLeave(userID, date, requestBody.Reason)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"message": "Leave created successfully",
		"leave":   leave,
	})
}

// UpdateLeave mengupdate leave
// PUT /api/leaves/:id
func (h *LeaveHandler) UpdateLeave(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	leaveID := c.Params("id")

	if leaveID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Leave ID is required",
		})
	}

	var requestBody struct {
		Date   string `json:"date"`
		Reason string `json:"reason"`
	}

	if err := c.BodyParser(&requestBody); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if requestBody.Date == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Date is required",
		})
	}

	if requestBody.Reason == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Reason is required",
		})
	}

	// Parse date
	date, err := time.Parse("2006-01-02", requestBody.Date)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid date format. Use YYYY-MM-DD",
		})
	}

	// Update leave
	leave, err := h.leaveService.UpdateLeave(leaveID, userID, date, requestBody.Reason)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Leave updated successfully",
		"leave":   leave,
	})
}

// DeleteLeave menghapus leave
// DELETE /api/leaves/:id
func (h *LeaveHandler) DeleteLeave(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	leaveID := c.Params("id")

	if leaveID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Leave ID is required",
		})
	}

	if err := h.leaveService.DeleteLeave(leaveID, userID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Leave deleted successfully",
	})
}

// GetUpcomingCount mendapatkan jumlah leaves yang akan datang
// GET /api/leaves/upcoming/count
func (h *LeaveHandler) GetUpcomingCount(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	count, err := h.leaveService.GetUpcomingCount(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to fetch upcoming leave count",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"count": count,
	})
}
