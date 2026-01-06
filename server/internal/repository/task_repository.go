package repository

import (
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type TaskRepository struct {
	db *gorm.DB
}

func NewTaskRepository(db *gorm.DB) *TaskRepository {
	return &TaskRepository{db: db}
}

// Create membuat task baru
func (r *TaskRepository) Create(task *models.Task) error {
	return r.db.Create(task).Error
}

// FindByID mencari task by ID dengan category
func (r *TaskRepository) FindByID(id string) (*models.Task, error) {
	var task models.Task
	err := r.db.Preload("Category").First(&task, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &task, nil
}

// FindByUserID mencari semua tasks milik user
func (r *TaskRepository) FindByUserID(userID string) ([]models.Task, error) {
	var tasks []models.Task
	err := r.db.Preload("Category").
		Where("user_id = ?", userID).
		Order("created_at DESC").
		Find(&tasks).Error
	return tasks, err
}

// FindByUserIDAndComplete mencari tasks by completed status
func (r *TaskRepository) FindByUserIDAndComplete(userID string, isCompleted bool) ([]models.Task, error) {
	var tasks []models.Task
	err := r.db.Preload("Category").
		Where("user_id = ? AND is_completed = ?", userID, isCompleted).
		Order("created_at DESC").
		Find(&tasks).Error
	return tasks, err
}

// FindByUserIDAndCategory mencari tasks by category
func (r *TaskRepository) FindByUserIDAndCategory(userID, categoryID string) ([]models.Task, error) {
	var tasks []models.Task
	err := r.db.Preload("Category").
		Where("user_id = ? AND category_id = ?", userID, categoryID).
		Order("created_at DESC").
		Find(&tasks).Error
	return tasks, err
}

// FindByUserIDAndDateRange mencari tasks dalam range tanggal
func (r *TaskRepository) FindByUserIDAndDateRange(userID string, start, end time.Time) ([]models.Task, error) {
	var tasks []models.Task
	err := r.db.Preload("Category").
		Where("user_id = ? AND deadline BETWEEN ? AND ?", userID, start, end).
		Order("deadline ASC").
		Find(&tasks).Error
	return tasks, err
}

// Update memperbarui task
func (r *TaskRepository) Update(task *models.Task) error {
	return r.db.Save(task).Error
}

// Delete menghapus task
func (r *TaskRepository) Delete(id string) error {
	return r.db.Delete(&models.Task{}, "id = ?", id).Error
}

// CountByUserID menghitung total tasks user
func (r *TaskRepository) CountByUserID(userID string) (int64, error) {
	var count int64
	err := r.db.Model(&models.Task{}).Where("user_id = ?", userID).Count(&count).Error
	return count, err
}

// CountCompletedByUserID menghitung completed tasks user
func (r *TaskRepository) CountCompletedByUserID(userID string) (int64, error) {
	var count int64
	err := r.db.Model(&models.Task{}).
		Where("user_id = ? AND is_completed = ?", userID, true).
		Count(&count).Error
	return count, err
}
