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

// --- Workload Multiplier Calculation (Phase 3.6) ---

// WorkloadStats contains calculated workload with multipliers
type WorkloadStats struct {
	TotalTasks     int     `json:"total_tasks"`
	RegularTasks   int     `json:"regular_tasks"`
	OvertimeTasks  int     `json:"overtime_tasks"`
	WeekendTasks   int     `json:"weekend_tasks"`
	CalculatedLoad float64 `json:"calculated_load"` // dengan multiplier
	OvertimeHours  float64 `json:"overtime_hours"`  // estimated
	WeekendHours   float64 `json:"weekend_hours"`   // estimated
}

// CalculateWorkloadWithMultipliers menghitung workload dengan multiplier untuk rentang tanggal
func (s *WorkloadService) CalculateWorkloadWithMultipliers(
	userID string,
	startDate, endDate time.Time,
	workDaysConfig map[string]interface{}, // dari User.WorkDays
	holidays []time.Time, // dari HolidayService
) (*WorkloadStats, error) {

	// Get all completed tasks in date range
	tasks, err := s.taskRepo.FindByUserIDAndDateRange(userID, startDate, endDate)
	if err != nil {
		return nil, err
	}

	stats := &WorkloadStats{
		TotalTasks: len(tasks),
	}

	for _, task := range tasks {
		// Only count completed tasks for workload
		if !task.IsCompleted || task.CompletedAt == nil {
			continue
		}

		completedAt := *task.CompletedAt
		categoryName := task.Category.Name

		// Only apply multipliers for "Kerja" category
		if categoryName != "Kerja" {
			stats.RegularTasks++
			stats.CalculatedLoad += 1.0
			continue
		}

		// Check if weekend/holiday work
		if s.isWeekendOrHoliday(completedAt, workDaysConfig, holidays) {
			stats.WeekendTasks++
			stats.CalculatedLoad += 1.3 // 1.3x multiplier
			stats.WeekendHours += estimateTaskDuration(task.DurationMinutes)
		} else if s.isOvertimeWork(completedAt, workDaysConfig) {
			stats.OvertimeTasks++
			stats.CalculatedLoad += 1.5 // 1.5x multiplier
			stats.OvertimeHours += estimateTaskDuration(task.DurationMinutes)
		} else {
			stats.RegularTasks++
			stats.CalculatedLoad += 1.0
		}
	}

	return stats, nil
}

// isWeekendOrHoliday checks if date is weekend or holiday
func (s *WorkloadService) isWeekendOrHoliday(
	date time.Time,
	workDaysConfig map[string]interface{},
	holidays []time.Time,
) bool {
	// Check if it's a holiday
	dateOnly := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())
	for _, holiday := range holidays {
		holidayOnly := time.Date(holiday.Year(), holiday.Month(), holiday.Day(), 0, 0, 0, 0, holiday.Location())
		if dateOnly.Equal(holidayOnly) {
			return true
		}
	}

	// Check work days config
	// Monday = 0, Tuesday = 1, ..., Sunday = 6
	dayIndex := int(date.Weekday())
	if dayIndex == 0 { // Sunday
		dayIndex = 6
	} else {
		dayIndex-- // Adjust: Monday=0
	}

	dayKey := string(rune('0' + dayIndex))
	dayConfig, exists := workDaysConfig[dayKey]
	if !exists {
		return true // No config = assume not work day
	}

	dayMap, ok := dayConfig.(map[string]interface{})
	if !ok {
		return true
	}

	isWorkDay, exists := dayMap["is_work_day"]
	if !exists {
		return true
	}

	isWork, ok := isWorkDay.(bool)
	if !ok {
		return true
	}

	return !isWork
}

// isOvertimeWork checks if work was completed outside work hours
func (s *WorkloadService) isOvertimeWork(
	date time.Time,
	workDaysConfig map[string]interface{},
) bool {
	// Get day index (Monday=0)
	dayIndex := int(date.Weekday())
	if dayIndex == 0 {
		dayIndex = 6
	} else {
		dayIndex--
	}

	dayKey := string(rune('0' + dayIndex))
	dayConfig, exists := workDaysConfig[dayKey]
	if !exists {
		return false
	}

	dayMap, ok := dayConfig.(map[string]interface{})
	if !ok {
		return false
	}

	// Check if it's a work day
	isWorkDay, _ := dayMap["is_work_day"].(bool)
	if !isWorkDay {
		return false // If not work day, it's weekend work, not overtime
	}

	// Get start and end times
	startStr, _ := dayMap["start"].(string)
	endStr, _ := dayMap["end"].(string)

	if startStr == "" || endStr == "" {
		return false
	}

	// Parse time strings (format: "HH:MM")
	startTime, err1 := time.Parse("15:04", startStr)
	endTime, err2 := time.Parse("15:04", endStr)

	if err1 != nil || err2 != nil {
		return false
	}

	// Get completion time (hour:minute only)
	completedTime := time.Date(0, 1, 1, date.Hour(), date.Minute(), 0, 0, time.UTC)

	// Check if outside work hours
	return completedTime.Before(startTime) || completedTime.After(endTime)
}

// estimateTaskDuration returns estimated hours for a task
func estimateTaskDuration(durationMinutes *int) float64 {
	if durationMinutes == nil || *durationMinutes == 0 {
		return 0.5 // default 30 min
	}
	return float64(*durationMinutes) / 60.0
}
