package repository

import (
	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type CategoryRepository struct {
	db *gorm.DB
}

func NewCategoryRepository(db *gorm.DB) *CategoryRepository {
	return &CategoryRepository{db: db}
}

// Create membuat category baru
func (r *CategoryRepository) Create(category *models.Category) error {
	return r.db.Create(category).Error
}

// FindByUserID mencari semua kategori milik user
func (r *CategoryRepository) FindByUserID(userID string) ([]models.Category, error) {
	var categories []models.Category
	err := r.db.Where("user_id = ?", userID).Find(&categories).Error
	return categories, err
}

// FindByID mencari category by ID
func (r *CategoryRepository) FindByID(id string) (*models.Category, error) {
	var category models.Category
	err := r.db.First(&category, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &category, nil
}

// Update memperbarui category
func (r *CategoryRepository) Update(category *models.Category) error {
	return r.db.Save(category).Error
}

// Delete menghapus category
func (r *CategoryRepository) Delete(id string) error {
	return r.db.Delete(&models.Category{}, "id = ?", id).Error
}

// CreateDefaultCategories membuat default categories untuk user baru
func (r *CategoryRepository) CreateDefaultCategories(userID string) error {
	for _, name := range models.DefaultCategories {
		category := &models.Category{
			UserID:    userID,
			Name:      name,
			Color:     models.DefaultCategoryColors[name],
			IsDefault: true,
		}
		if err := r.Create(category); err != nil {
			return err
		}
	}
	return nil
}
