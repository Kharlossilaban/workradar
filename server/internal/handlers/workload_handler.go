package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type WorkloadHandler struct {
	workloadService *services.WorkloadService
}

func NewWorkloadHandler(workloadService *services.WorkloadService) *WorkloadHandler {
	return &WorkloadHandler{workloadService: workloadService}
}

// GetWorkload mendapatkan workload data
// GET /api/workload?period=daily|weekly|monthly
func (h *WorkloadHandler) GetWorkload(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	period := c.Query("period", "daily") // default: daily

	var response *services.WorkloadResponse
	var err error

	switch period {
	case "daily":
		response, err = h.workloadService.GetDailyWorkload(userID)
	case "weekly":
		response, err = h.workloadService.GetWeeklyWorkload(userID)
	case "monthly":
		response, err = h.workloadService.GetMonthlyWorkload(userID)
	default:
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid period. Use 'daily', 'weekly', or 'monthly'",
		})
	}

	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(response)
}
