package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type CategoryHandler struct {
	categoryService *services.CategoryService
}

func NewCategoryHandler(categoryService *services.CategoryService) *CategoryHandler {
	return &CategoryHandler{categoryService: categoryService}
}

// GetCategories mendapatkan semua kategori user
// GET /api/categories
func (h *CategoryHandler) GetCategories(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	categories, err := h.categoryService.GetCategories(userID)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"categories": categories,
		"count":      len(categories),
	})
}

// CreateCategory membuat kategori baru
// POST /api/categories
func (h *CategoryHandler) CreateCategory(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	var req services.CreateCategoryDTO
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	category, err := h.categoryService.CreateCategory(userID, req)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusCreated).JSON(fiber.Map{
		"message":  "Category created successfully",
		"category": category,
	})
}

// UpdateCategory memperbarui kategori
// PUT /api/categories/:id
func (h *CategoryHandler) UpdateCategory(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	categoryID := c.Params("id")

	var req services.UpdateCategoryDTO
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	category, err := h.categoryService.UpdateCategory(userID, categoryID, req)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message":  "Category updated successfully",
		"category": category,
	})
}

// DeleteCategory menghapus kategori
// DELETE /api/categories/:id
func (h *CategoryHandler) DeleteCategory(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)
	categoryID := c.Params("id")

	if err := h.categoryService.DeleteCategory(userID, categoryID); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"message": "Category deleted successfully",
	})
}
