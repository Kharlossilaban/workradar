package services

import (
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
)

type CalendarService struct {
	taskRepo *repository.TaskRepository
}

func NewCalendarService(taskRepo *repository.TaskRepository) *CalendarService {
	return &CalendarService{taskRepo: taskRepo}
}

// CalendarResponse response untuk calendar view
type CalendarResponse struct {
	Date  string        `json:"date"`
	Tasks []models.Task `json:"tasks"`
	Count int           `json:"count"`
}

// GetTodayTasks mendapatkan tasks hari ini
func (s *CalendarService) GetTodayTasks(userID string) (*CalendarResponse, error) {
	start, end := GetTodayRange()
	tasks, err := s.taskRepo.FindByUserIDAndDateRange(userID, start, end)
	if err != nil {
		return nil, err
	}

	return &CalendarResponse{
		Date:  time.Now().Format("2006-01-02"),
		Tasks: tasks,
		Count: len(tasks),
	}, nil
}

// GetWeekTasks mendapatkan tasks minggu ini
func (s *CalendarService) GetWeekTasks(userID string) (*CalendarResponse, error) {
	start, end := GetWeekRange()
	tasks, err := s.taskRepo.FindByUserIDAndDateRange(userID, start, end)
	if err != nil {
		return nil, err
	}

	return &CalendarResponse{
		Date:  start.Format("2006-01-02") + " to " + end.Format("2006-01-02"),
		Tasks: tasks,
		Count: len(tasks),
	}, nil
}

// GetMonthTasks mendapatkan tasks bulan ini
func (s *CalendarService) GetMonthTasks(userID string) (*CalendarResponse, error) {
	start, end := GetMonthRange()
	tasks, err := s.taskRepo.FindByUserIDAndDateRange(userID, start, end)
	if err != nil {
		return nil, err
	}

	return &CalendarResponse{
		Date:  start.Format("2006-01") + " (month)",
		Tasks: tasks,
		Count: len(tasks),
	}, nil
}

// GetTasksByDateRange mendapatkan tasks custom date range
func (s *CalendarService) GetTasksByDateRange(userID string, start, end time.Time) (*CalendarResponse, error) {
	tasks, err := s.taskRepo.FindByUserIDAndDateRange(userID, start, end)
	if err != nil {
		return nil, err
	}

	return &CalendarResponse{
		Date:  start.Format("2006-01-02") + " to " + end.Format("2006-01-02"),
		Tasks: tasks,
		Count: len(tasks),
	}, nil
}

// Helper functions untuk date range

// GetTodayRange return start dan end hari ini
func GetTodayRange() (time.Time, time.Time) {
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	end := start.Add(24*time.Hour - time.Second)
	return start, end
}

// GetWeekRange return start (Senin) dan end (Minggu) minggu ini
func GetWeekRange() (time.Time, time.Time) {
	now := time.Now()
	weekday := int(now.Weekday())
	if weekday == 0 { // Sunday = 0, kita anggap Senin = hari pertama
		weekday = 7
	}

	// Senin minggu ini
	start := now.AddDate(0, 0, -(weekday - 1))
	start = time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, start.Location())

	// Minggu minggu ini
	end := start.AddDate(0, 0, 6)
	end = time.Date(end.Year(), end.Month(), end.Day(), 23, 59, 59, 0, end.Location())

	return start, end
}

// GetMonthRange return start (tanggal 1) dan end (tanggal terakhir) bulan ini
func GetMonthRange() (time.Time, time.Time) {
	now := time.Now()
	start := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())

	// Tanggal terakhir bulan ini = tanggal 1 bulan depan - 1 detik
	end := start.AddDate(0, 1, 0).Add(-time.Second)

	return start, end
}
