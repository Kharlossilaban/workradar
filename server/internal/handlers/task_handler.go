package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type TaskHandler struct {
	taskService *services.TaskService
}

func NewTaskHandler(taskService *services.TaskService) *TaskHandler {
	return &TaskHandler{taskService: taskService}
}

// CreateTask membuat task baru
// POST /api/tasks
func (h *TaskHandler) CreateTask(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var req services.CreateTaskDTO
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	task, err := h.taskService.CreateTask(userID, req)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"message": "Task created successfully",
		"task":    task,
	})
}

// GetTasks mendapatkan semua tasks user
// GET /api/tasks?category_id=xxx
func (h *TaskHandler) GetTasks(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	// Optional filter by category
	categoryID := c.Query("category_id")
	var categoryIDPtr *string
	if categoryID != "" {
		categoryIDPtr = &categoryID
	}

	tasks, err := h.taskService.GetTasks(userID, categoryIDPtr)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"tasks": tasks,
		"count": len(tasks),
	})
}

// GetTaskByID mendapatkan detail task
// GET /api/tasks/:id
func (h *TaskHandler) GetTaskByID(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	taskID := c.Params("id")

	task, err := h.taskService.GetTaskByID(userID, taskID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"task": task,
	})
}

// UpdateTask memperbarui task
// PUT /api/tasks/:id
func (h *TaskHandler) UpdateTask(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	taskID := c.Params("id")

	var req services.UpdateTaskDTO
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	task, err := h.taskService.UpdateTask(userID, taskID, req)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Task updated successfully",
		"task":    task,
	})
}

// DeleteTask menghapus task
// DELETE /api/tasks/:id
func (h *TaskHandler) DeleteTask(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	taskID := c.Params("id")

	if err := h.taskService.DeleteTask(userID, taskID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Task deleted successfully",
	})
}

// ToggleComplete toggle status completed
// PATCH /api/tasks/:id/toggle
func (h *TaskHandler) ToggleComplete(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	taskID := c.Params("id")

	task, err := h.taskService.ToggleTaskComplete(userID, taskID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Task status toggled",
		"task":    task,
	})
}
