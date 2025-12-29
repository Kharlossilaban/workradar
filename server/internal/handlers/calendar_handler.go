package handlers

import (
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type CalendarHandler struct {
	calendarService *services.CalendarService
}

func NewCalendarHandler(calendarService *services.CalendarService) *CalendarHandler {
	return &CalendarHandler{calendarService: calendarService}
}

// GetTodayTasks mendapatkan tasks hari ini
// GET /api/calendar/today
func (h *CalendarHandler) GetTodayTasks(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	response, err := h.calendarService.GetTodayTasks(userID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(response)
}

// GetWeekTasks mendapatkan tasks minggu ini
// GET /api/calendar/week
func (h *CalendarHandler) GetWeekTasks(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	response, err := h.calendarService.GetWeekTasks(userID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(response)
}

// GetMonthTasks mendapatkan tasks bulan ini
// GET /api/calendar/month
func (h *CalendarHandler) GetMonthTasks(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	response, err := h.calendarService.GetMonthTasks(userID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(response)
}

// GetTasksByDateRange mendapatkan tasks custom date range
// GET /api/calendar/range?start=2025-12-01&end=2025-12-31
func (h *CalendarHandler) GetTasksByDateRange(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	// Parse query params
	startStr := c.Query("start")
	endStr := c.Query("end")

	if startStr == "" || endStr == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "start and end date are required (format: YYYY-MM-DD)",
		})
	}

	// Parse dates
	start, err := time.Parse("2006-01-02", startStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "invalid start date format (use YYYY-MM-DD)",
		})
	}

	end, err := time.Parse("2006-01-02", endStr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "invalid end date format (use YYYY-MM-DD)",
		})
	}

	// Set time to end of day for end date
	end = time.Date(end.Year(), end.Month(), end.Day(), 23, 59, 59, 0, end.Location())

	response, err := h.calendarService.GetTasksByDateRange(userID, start, end)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(response)
}
