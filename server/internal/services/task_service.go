package services

import (
	"errors"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"gorm.io/gorm"
)

type TaskService struct {
	taskRepo     *repository.TaskRepository
	categoryRepo *repository.CategoryRepository
}

func NewTaskService(
	taskRepo *repository.TaskRepository,
	categoryRepo *repository.CategoryRepository,
) *TaskService {
	return &TaskService{
		taskRepo:     taskRepo,
		categoryRepo: categoryRepo,
	}
}

// CreateTask membuat task baru
func (s *TaskService) CreateTask(userID string, data CreateTaskDTO) (*models.Task, error) {
	// Validasi title
	if data.Title == "" {
		return nil, errors.New("title is required")
	}

	// Validasi category (jika ada)
	if data.CategoryID != nil {
		category, err := s.categoryRepo.FindByID(*data.CategoryID)
		if err != nil || category.UserID != userID {
			return nil, errors.New("invalid category")
		}
	}

	// Buat task
	task := &models.Task{
		UserID:          userID,
		CategoryID:      data.CategoryID,
		Title:           data.Title,
		Description:     data.Description,
		Deadline:        data.Deadline,
		ReminderMinutes: data.ReminderMinutes,
		RepeatType:      data.RepeatType,
		RepeatInterval:  data.RepeatInterval,
		RepeatEndDate:   data.RepeatEndDate,
		IsCompleted:     false,
	}

	if err := s.taskRepo.Create(task); err != nil {
		return nil, err
	}

	// Load category relation
	if task.CategoryID != nil {
		task, _ = s.taskRepo.FindByID(task.ID)
	}

	return task, nil
}

// GetTasks mendapatkan semua tasks user
func (s *TaskService) GetTasks(userID string, categoryID *string) ([]models.Task, error) {
	if categoryID != nil && *categoryID != "" {
		return s.taskRepo.FindByUserIDAndCategory(userID, *categoryID)
	}
	return s.taskRepo.FindByUserID(userID)
}

// GetTaskByID mendapatkan task by ID
func (s *TaskService) GetTaskByID(userID, taskID string) (*models.Task, error) {
	task, err := s.taskRepo.FindByID(taskID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("task not found")
		}
		return nil, err
	}

	// Verify ownership
	if task.UserID != userID {
		return nil, errors.New("unauthorized")
	}

	return task, nil
}

// UpdateTask memperbarui task
func (s *TaskService) UpdateTask(userID, taskID string, data UpdateTaskDTO) (*models.Task, error) {
	task, err := s.GetTaskByID(userID, taskID)
	if err != nil {
		return nil, err
	}

	// Update fields if provided
	if data.Title != nil {
		if *data.Title == "" {
			return nil, errors.New("title cannot be empty")
		}
		task.Title = *data.Title
	}

	if data.CategoryID != nil {
		// Validate category
		if *data.CategoryID != "" {
			category, err := s.categoryRepo.FindByID(*data.CategoryID)
			if err != nil || category.UserID != userID {
				return nil, errors.New("invalid category")
			}
		}
		task.CategoryID = data.CategoryID
	}

	if data.Description != nil {
		task.Description = data.Description
	}

	if data.Deadline != nil {
		task.Deadline = data.Deadline
	}

	if data.ReminderMinutes != nil {
		task.ReminderMinutes = data.ReminderMinutes
	}

	if data.RepeatType != nil {
		task.RepeatType = *data.RepeatType
	}

	if data.RepeatInterval != nil {
		task.RepeatInterval = *data.RepeatInterval
	}

	if data.RepeatEndDate != nil {
		task.RepeatEndDate = data.RepeatEndDate
	}

	if data.IsCompleted != nil {
		task.IsCompleted = *data.IsCompleted
		if *data.IsCompleted {
			now := time.Now()
			task.CompletedAt = &now
		} else {
			task.CompletedAt = nil
		}
	}

	if err := s.taskRepo.Update(task); err != nil {
		return nil, err
	}

	// Reload with category
	task, _ = s.taskRepo.FindByID(task.ID)
	return task, nil
}

// DeleteTask menghapus task
func (s *TaskService) DeleteTask(userID, taskID string) error {
	// Verify ownership
	_, err := s.GetTaskByID(userID, taskID)
	if err != nil {
		return err
	}

	return s.taskRepo.Delete(taskID)
}

// ToggleTaskComplete toggle status completed task
func (s *TaskService) ToggleTaskComplete(userID, taskID string) (*models.Task, error) {
	task, err := s.GetTaskByID(userID, taskID)
	if err != nil {
		return nil, err
	}

	task.IsCompleted = !task.IsCompleted
	if task.IsCompleted {
		now := time.Now()
		task.CompletedAt = &now
	} else {
		task.CompletedAt = nil
	}

	if err := s.taskRepo.Update(task); err != nil {
		return nil, err
	}

	return task, nil
}

// DTOs (Data Transfer Objects)

type CreateTaskDTO struct {
	CategoryID      *string           `json:"category_id"`
	Title           string            `json:"title"`
	Description     *string           `json:"description"`
	Deadline        *time.Time        `json:"deadline"`
	ReminderMinutes *int              `json:"reminder_minutes"`
	RepeatType      models.RepeatType `json:"repeat_type"`
	RepeatInterval  int               `json:"repeat_interval"`
	RepeatEndDate   *time.Time        `json:"repeat_end_date"`
}

type UpdateTaskDTO struct {
	CategoryID      *string            `json:"category_id"`
	Title           *string            `json:"title"`
	Description     *string            `json:"description"`
	Deadline        *time.Time         `json:"deadline"`
	ReminderMinutes *int               `json:"reminder_minutes"`
	RepeatType      *models.RepeatType `json:"repeat_type"`
	RepeatInterval  *int               `json:"repeat_interval"`
	RepeatEndDate   *time.Time         `json:"repeat_end_date"`
	IsCompleted     *bool              `json:"is_completed"`
}
