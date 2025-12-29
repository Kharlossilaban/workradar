package services

import (
	"time"

	"github.com/workradar/server/internal/repository"
)

type WorkloadService struct {
	taskRepo *repository.TaskRepository
}

func NewWorkloadService(taskRepo *repository.TaskRepository) *WorkloadService {
	return &WorkloadService{taskRepo: taskRepo}
}

// WorkloadData data untuk chart
type WorkloadData struct {
	Label string `json:"label"` // "Mon", "Week 1", "Dec"
	Count int    `json:"count"` // Jumlah tasks
}

// WorkloadResponse response untuk workload
type WorkloadResponse struct {
	Period string         `json:"period"` // "daily", "weekly", "monthly"
	Data   []WorkloadData `json:"data"`
}

// GetDailyWorkload mendapatkan workload 7 hari terakhir
func (s *WorkloadService) GetDailyWorkload(userID string) (*WorkloadResponse, error) {
	data := []WorkloadData{}
	dayLabels := []string{"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}

	// Loop 7 hari terakhir
	for i := 6; i >= 0; i-- {
		date := time.Now().AddDate(0, 0, -i)
		startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
		endOfDay := startOfDay.Add(24*time.Hour - time.Second)

		// Count tasks di hari ini
		tasks, _ := s.taskRepo.FindByUserIDAndDateRange(userID, startOfDay, endOfDay)

		// Get day name
		dayName := dayLabels[int(date.Weekday())]

		data = append(data, WorkloadData{
			Label: dayName,
			Count: len(tasks),
		})
	}

	return &WorkloadResponse{
		Period: "daily",
		Data:   data,
	}, nil
}

// GetWeeklyWorkload mendapatkan workload 4 minggu terakhir
func (s *WorkloadService) GetWeeklyWorkload(userID string) (*WorkloadResponse, error) {
	data := []WorkloadData{}

	// Loop 4 minggu terakhir
	for i := 3; i >= 0; i-- {
		// Start of week (Monday)
		now := time.Now().AddDate(0, 0, -i*7)
		weekday := int(now.Weekday())
		if weekday == 0 {
			weekday = 7
		}
		startOfWeek := now.AddDate(0, 0, -(weekday - 1))
		startOfWeek = time.Date(startOfWeek.Year(), startOfWeek.Month(), startOfWeek.Day(), 0, 0, 0, 0, startOfWeek.Location())

		// End of week (Sunday)
		endOfWeek := startOfWeek.AddDate(0, 0, 6)
		endOfWeek = time.Date(endOfWeek.Year(), endOfWeek.Month(), endOfWeek.Day(), 23, 59, 59, 0, endOfWeek.Location())

		// Count tasks minggu ini
		tasks, _ := s.taskRepo.FindByUserIDAndDateRange(userID, startOfWeek, endOfWeek)

		data = append(data, WorkloadData{
			Label: "Week " + string(rune('1'+3-i)), // "Week 1", "Week 2", ...
			Count: len(tasks),
		})
	}

	return &WorkloadResponse{
		Period: "weekly",
		Data:   data,
	}, nil
}

// GetMonthlyWorkload mendapatkan workload 12 bulan terakhir
func (s *WorkloadService) GetMonthlyWorkload(userID string) (*WorkloadResponse, error) {
	data := []WorkloadData{}
	monthNames := []string{"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"}

	// Loop 12 bulan terakhir
	for i := 11; i >= 0; i-- {
		date := time.Now().AddDate(0, -i, 0)
		startOfMonth := time.Date(date.Year(), date.Month(), 1, 0, 0, 0, 0, date.Location())
		endOfMonth := startOfMonth.AddDate(0, 1, 0).Add(-time.Second)

		// Count tasks bulan ini
		tasks, _ := s.taskRepo.FindByUserIDAndDateRange(userID, startOfMonth, endOfMonth)

		monthName := monthNames[date.Month()-1]

		data = append(data, WorkloadData{
			Label: monthName,
			Count: len(tasks),
		})
	}

	return &WorkloadResponse{
		Period: "monthly",
		Data:   data,
	}, nil
}
