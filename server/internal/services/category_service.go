package services

import (
	"errors"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"gorm.io/gorm"
)

type CategoryService struct {
	categoryRepo *repository.CategoryRepository
	taskRepo     *repository.TaskRepository
}

func NewCategoryService(
	categoryRepo *repository.CategoryRepository,
	taskRepo *repository.TaskRepository,
) *CategoryService {
	return &CategoryService{
		categoryRepo: categoryRepo,
		taskRepo:     taskRepo,
	}
}

// GetCategories mendapatkan semua kategori user
func (s *CategoryService) GetCategories(userID string) ([]models.Category, error) {
	return s.categoryRepo.FindByUserID(userID)
}

// CreateCategory membuat kategori baru
func (s *CategoryService) CreateCategory(userID string, data CreateCategoryDTO) (*models.Category, error) {
	// Validasi
	if data.Name == "" {
		return nil, errors.New("category name is required")
	}

	if data.Color == "" {
		data.Color = "#6C5CE7" // Default purple
	}

	// Check duplicate name
	categories, _ := s.categoryRepo.FindByUserID(userID)
	for _, cat := range categories {
		if cat.Name == data.Name {
			return nil, errors.New("category name already exists")
		}
	}

	// Create category
	category := &models.Category{
		UserID:    userID,
		Name:      data.Name,
		Color:     data.Color,
		IsDefault: false,
	}

	if err := s.categoryRepo.Create(category); err != nil {
		return nil, err
	}

	return category, nil
}

// UpdateCategory memperbarui kategori
func (s *CategoryService) UpdateCategory(userID, categoryID string, data UpdateCategoryDTO) (*models.Category, error) {
	// Get category
	category, err := s.categoryRepo.FindByID(categoryID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("category not found")
		}
		return nil, err
	}

	// Verify ownership
	if category.UserID != userID {
		return nil, errors.New("unauthorized")
	}

	// Update fields
	if data.Name != nil {
		if *data.Name == "" {
			return nil, errors.New("category name cannot be empty")
		}

		// Check duplicate (kecuali nama yang sama)
		categories, _ := s.categoryRepo.FindByUserID(userID)
		for _, cat := range categories {
			if cat.Name == *data.Name && cat.ID != categoryID {
				return nil, errors.New("category name already exists")
			}
		}

		category.Name = *data.Name
	}

	if data.Color != nil {
		category.Color = *data.Color
	}

	if err := s.categoryRepo.Update(category); err != nil {
		return nil, err
	}

	return category, nil
}

// DeleteCategory menghapus kategori
func (s *CategoryService) DeleteCategory(userID, categoryID string) error {
	// Get category
	category, err := s.categoryRepo.FindByID(categoryID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("category not found")
		}
		return err
	}

	// Verify ownership
	if category.UserID != userID {
		return errors.New("unauthorized")
	}

	// Cannot delete default categories
	if category.IsDefault {
		return errors.New("cannot delete default category")
	}

	// Delete category (tasks akan jadi category_id = null karena ON DELETE SET NULL)
	return s.categoryRepo.Delete(categoryID)
}

// DTOs

type CreateCategoryDTO struct {
	Name  string `json:"name"`
	Color string `json:"color"`
}

type UpdateCategoryDTO struct {
	Name  *string `json:"name"`
	Color *string `json:"color"`
}
