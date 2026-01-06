package handlers

import (
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type HolidayHandler struct {
	holidayService *services.HolidayService
}

func NewHolidayHandler(holidayService *services.HolidayService) *HolidayHandler {
	return &HolidayHandler{holidayService: holidayService}
}

// GetHolidays mendapatkan semua holidays atau by date range
// GET /api/holidays?start_date=2026-01-01&end_date=2026-12-31
func (h *HolidayHandler) GetHolidays(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	startDateStr := c.Query("start_date")
	endDateStr := c.Query("end_date")

	// If date range provided, use it
	if startDateStr != "" && endDateStr != "" {
		startDate, err := time.Parse("2006-01-02", startDateStr)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid start_date format. Use YYYY-MM-DD",
			})
		}

		endDate, err := time.Parse("2006-01-02", endDateStr)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid end_date format. Use YYYY-MM-DD",
			})
		}

		holidays, err := h.holidayService.GetHolidaysByDateRange(userID, startDate, endDate)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "Failed to fetch holidays",
			})
		}

		return c.Status(fiber.StatusOK).JSON(fiber.Map{
			"holidays": holidays,
		})
	}

	// Otherwise, get all holidays
	holidays, err := h.holidayService.GetAllHolidays(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to fetch holidays",
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"holidays": holidays,
	})
}

// CreatePersonalHoliday membuat personal holiday baru
// POST /api/holidays/personal
func (h *HolidayHandler) CreatePersonalHoliday(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var requestBody struct {
		Name        string  `json:"name"`
		Date        string  `json:"date"` // Format: YYYY-MM-DD
		Description *string `json:"description"`
	}

	if err := c.BodyParser(&requestBody); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	// Validate required fields
	if requestBody.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Name is required",
		})
	}

	if requestBody.Date == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Date is required",
		})
	}

	// Parse date
	date, err := time.Parse("2006-01-02", requestBody.Date)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid date format. Use YYYY-MM-DD",
		})
	}

	// Create holiday
	holiday, err := h.holidayService.CreatePersonalHoliday(
		userID,
		requestBody.Name,
		date,
		requestBody.Description,
	)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to create holiday",
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"message": "Personal holiday created successfully",
		"holiday": holiday,
	})
}

// DeletePersonalHoliday menghapus personal holiday
// DELETE /api/holidays/personal/:id
func (h *HolidayHandler) DeletePersonalHoliday(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	holidayID := c.Params("id")

	if holidayID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Holiday ID is required",
		})
	}

	if err := h.holidayService.DeletePersonalHoliday(holidayID, userID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Personal holiday deleted successfully",
	})
}
