package services

import (
	"errors"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"gorm.io/gorm"
)

type ProfileService struct {
	userRepo     *repository.UserRepository
	taskRepo     *repository.TaskRepository
	categoryRepo *repository.CategoryRepository
}

func NewProfileService(
	userRepo *repository.UserRepository,
	taskRepo *repository.TaskRepository,
	categoryRepo *repository.CategoryRepository,
) *ProfileService {
	return &ProfileService{
		userRepo:     userRepo,
		taskRepo:     taskRepo,
		categoryRepo: categoryRepo,
	}
}

// UserStats untuk statistik user
type UserStats struct {
	TotalTasks     int     `json:"total_tasks"`
	CompletedTasks int     `json:"completed_tasks"`
	CompletionRate float64 `json:"completion_rate"`
	TodayTasks     int     `json:"today_tasks"`
	PendingTasks   int     `json:"pending_tasks"`
}

// ProfileResponse response lengkap profile
type ProfileResponse struct {
	User       models.UserResponse `json:"user"`
	Stats      UserStats           `json:"stats"`
	Categories []models.Category   `json:"categories"`
}

// GetFullProfile mendapatkan profile lengkap dengan stats
func (s *ProfileService) GetFullProfile(userID string) (*ProfileResponse, error) {
	// Get user
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("user not found")
		}
		return nil, err
	}

	// Get stats
	stats, err := s.GetUserStats(userID)
	if err != nil {
		return nil, err
	}

	// Get categories
	categories, err := s.categoryRepo.FindByUserID(userID)
	if err != nil {
		categories = []models.Category{} // Empty array jika error
	}

	return &ProfileResponse{
		User:       user.ToResponse(),
		Stats:      *stats,
		Categories: categories,
	}, nil
}

// GetUserStats menghitung statistik user
func (s *ProfileService) GetUserStats(userID string) (*UserStats, error) {
	// Total tasks
	totalTasks, err := s.taskRepo.CountByUserID(userID)
	if err != nil {
		return nil, err
	}

	// Completed tasks
	completedTasks, err := s.taskRepo.CountCompletedByUserID(userID)
	if err != nil {
		return nil, err
	}

	// Completion rate
	completionRate := 0.0
	if totalTasks > 0 {
		completionRate = float64(completedTasks) / float64(totalTasks) * 100
	}

	// Today's tasks (deadline hari ini)
	startOfDay := time.Now().Truncate(24 * time.Hour)
	endOfDay := startOfDay.Add(24*time.Hour - time.Second)
	todayTasks, err := s.taskRepo.FindByUserIDAndDateRange(userID, startOfDay, endOfDay)
	if err != nil {
		todayTasks = []models.Task{}
	}

	// Pending tasks (belum selesai)
	pendingTasks := int(totalTasks) - int(completedTasks)

	return &UserStats{
		TotalTasks:     int(totalTasks),
		CompletedTasks: int(completedTasks),
		CompletionRate: completionRate,
		TodayTasks:     len(todayTasks),
		PendingTasks:   pendingTasks,
	}, nil
}
