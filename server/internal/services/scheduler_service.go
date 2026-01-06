package services

import (
	"log"
	"sync"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"gorm.io/gorm"
)

// SchedulerService handles scheduled background tasks for notifications
type SchedulerService struct {
	db                  *gorm.DB
	userRepo            *repository.UserRepository
	taskRepo            *repository.TaskRepository
	notificationService *NotificationService
	weatherService      *WeatherService
	stopChan            chan struct{}
	wg                  sync.WaitGroup
}

// NewSchedulerService creates a new scheduler service
func NewSchedulerService(
	db *gorm.DB,
	userRepo *repository.UserRepository,
	taskRepo *repository.TaskRepository,
	notificationService *NotificationService,
	weatherService *WeatherService,
) *SchedulerService {
	return &SchedulerService{
		db:                  db,
		userRepo:            userRepo,
		taskRepo:            taskRepo,
		notificationService: notificationService,
		weatherService:      weatherService,
		stopChan:            make(chan struct{}),
	}
}

// Start begins all scheduler routines
func (s *SchedulerService) Start() {
	log.Println("🚀 Starting Scheduler Service...")

	// Start health recommendation scheduler (runs every hour)
	s.wg.Add(1)
	go s.healthRecommendationScheduler()

	// Start weather notification scheduler (runs at 6 AM daily)
	s.wg.Add(1)
	go s.weatherNotificationScheduler()

	// Start task reminder scheduler (runs every 5 minutes)
	s.wg.Add(1)
	go s.taskReminderScheduler()

	log.Println("✅ Scheduler Service started successfully")
}

// Stop gracefully stops all scheduler routines
func (s *SchedulerService) Stop() {
	log.Println("🛑 Stopping Scheduler Service...")
	close(s.stopChan)
	s.wg.Wait()
	log.Println("✅ Scheduler Service stopped")
}

// ==================== HEALTH RECOMMENDATION SCHEDULER ====================

// healthRecommendationScheduler runs every hour to check workload and send health notifications
func (s *SchedulerService) healthRecommendationScheduler() {
	defer s.wg.Done()

	// Run immediately on startup
	s.checkAllUsersWorkload()

	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			s.checkAllUsersWorkload()
		case <-s.stopChan:
			log.Println("📋 Health recommendation scheduler stopped")
			return
		}
	}
}

// checkAllUsersWorkload checks workload for all active users
func (s *SchedulerService) checkAllUsersWorkload() {
	log.Println("📋 Running health recommendation check...")

	// Get all users with FCM tokens
	var users []models.User
	if err := s.db.Where("fcm_token IS NOT NULL AND fcm_token != ''").Find(&users).Error; err != nil {
		log.Printf("❌ Failed to fetch users for health check: %v", err)
		return
	}

	for _, user := range users {
		go s.checkUserWorkload(user)
	}

	log.Printf("✅ Health check initiated for %d users", len(users))
}

// checkUserWorkload analyzes a single user's workload and sends notification if needed
func (s *SchedulerService) checkUserWorkload(user models.User) {
	// Get today's tasks
	now := time.Now()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	endOfDay := startOfDay.Add(24*time.Hour - time.Second)

	tasks, err := s.taskRepo.FindByUserIDAndDateRange(user.ID, startOfDay, endOfDay)
	if err != nil {
		log.Printf("❌ Failed to fetch tasks for user %s: %v", user.ID, err)
		return
	}

	taskCount := len(tasks)
	estimatedHours := s.calculateEstimatedWorkHours(tasks)

	// Check conditions for health notification
	// Condition 1: More than 15 tasks today
	// Condition 2: More than 12 hours estimated work
	if taskCount > 15 || estimatedHours > 12 {
		recommendation := s.getHealthRecommendation(taskCount, estimatedHours)

		if err := s.notificationService.SendHealthRecommendation(user.ID, recommendation, estimatedHours); err != nil {
			log.Printf("❌ Failed to send health recommendation to user %s: %v", user.ID, err)
		} else {
			log.Printf("✅ Health recommendation sent to user %s (tasks: %d, hours: %.1f)", user.ID, taskCount, estimatedHours)
		}
	}
}

// calculateEstimatedWorkHours calculates total estimated work hours from tasks
func (s *SchedulerService) calculateEstimatedWorkHours(tasks []models.Task) float64 {
	totalMinutes := 0
	for _, task := range tasks {
		if task.DurationMinutes != nil {
			totalMinutes += *task.DurationMinutes
		} else {
			// Default 30 minutes per task if no duration set
			totalMinutes += 30
		}
	}
	return float64(totalMinutes) / 60.0
}

// getHealthRecommendation returns appropriate health message based on workload
func (s *SchedulerService) getHealthRecommendation(taskCount int, hours float64) string {
	recommendations := []struct {
		condition bool
		message   string
	}{
		{
			condition: hours > 14,
			message:   "Beban kerjamu sangat berat hari ini! 😰 Prioritaskan tugas penting, delegasikan yang bisa, dan jangan lupa istirahat sejenak setiap 2 jam.",
		},
		{
			condition: hours > 12,
			message:   "Beban tugasmu sangat sibuk hari ini! 😓 Jangan lupa minum air putih dan ambil waktu istirahat singkat untuk menjaga produktivitas.",
		},
		{
			condition: taskCount > 20,
			message:   "Wah, ada banyak tugas hari ini! 📝 Pertimbangkan untuk memilah mana yang paling urgent dan penting untuk dikerjakan duluan.",
		},
		{
			condition: taskCount > 15,
			message:   "Tugasmu cukup padat hari ini! 💪 Ingat untuk take a break setiap beberapa jam agar tetap fokus.",
		},
		{
			condition: true, // Default
			message:   "Selamat bekerja! Jangan lupa jaga kesehatan dengan minum air putih dan peregangan ringan. 🌟",
		},
	}

	for _, r := range recommendations {
		if r.condition {
			return r.message
		}
	}

	return recommendations[len(recommendations)-1].message
}

// ==================== WEATHER NOTIFICATION SCHEDULER ====================

// weatherNotificationScheduler runs daily at 6 AM to send weather alerts to VIP users
func (s *SchedulerService) weatherNotificationScheduler() {
	defer s.wg.Done()

	for {
		// Calculate time until next 6 AM
		now := time.Now()
		next6AM := time.Date(now.Year(), now.Month(), now.Day(), 6, 0, 0, 0, now.Location())

		// If it's already past 6 AM, schedule for tomorrow
		if now.After(next6AM) {
			next6AM = next6AM.Add(24 * time.Hour)
		}

		waitDuration := next6AM.Sub(now)
		log.Printf("⏰ Weather notification scheduled for %v (in %v)", next6AM.Format("2006-01-02 15:04:05"), waitDuration.Round(time.Minute))

		timer := time.NewTimer(waitDuration)

		select {
		case <-timer.C:
			s.sendWeatherNotificationsToVIPUsers()
		case <-s.stopChan:
			timer.Stop()
			log.Println("🌤️ Weather notification scheduler stopped")
			return
		}
	}
}

// sendWeatherNotificationsToVIPUsers sends weather alerts to all VIP users
func (s *SchedulerService) sendWeatherNotificationsToVIPUsers() {
	log.Println("🌤️ Running weather notification for VIP users...")

	// Get all VIP users with FCM tokens
	var vipUsers []models.User
	if err := s.db.Where(
		"user_type = ? AND fcm_token IS NOT NULL AND fcm_token != '' AND (vip_expires_at IS NULL OR vip_expires_at > ?)",
		models.UserTypeVIP,
		time.Now(),
	).Find(&vipUsers).Error; err != nil {
		log.Printf("❌ Failed to fetch VIP users for weather notification: %v", err)
		return
	}

	if len(vipUsers) == 0 {
		log.Println("ℹ️ No VIP users with FCM tokens found for weather notification")
		return
	}

	// Default city for Indonesian users
	defaultCity := "Jakarta"

	for _, user := range vipUsers {
		go s.sendWeatherToUser(user, defaultCity)
	}

	log.Printf("✅ Weather notifications initiated for %d VIP users", len(vipUsers))
}

// sendWeatherToUser sends weather notification to a single user
func (s *SchedulerService) sendWeatherToUser(user models.User, city string) {
	// Get current weather
	weather, err := s.weatherService.GetWeatherByCity(city)
	if err != nil {
		log.Printf("❌ Failed to fetch weather for user %s: %v", user.ID, err)
		return
	}

	// Check if weather condition warrants notification
	if s.shouldSendWeatherAlert(weather) {
		if err := s.notificationService.SendWeatherAlert(user.ID, city, weather.Description, weather.Temperature); err != nil {
			log.Printf("❌ Failed to send weather alert to user %s: %v", user.ID, err)
		} else {
			log.Printf("✅ Weather alert sent to user %s: %s, %.1f°C", user.ID, weather.Description, weather.Temperature)
		}
	}
}

// shouldSendWeatherAlert determines if weather condition warrants a notification
func (s *SchedulerService) shouldSendWeatherAlert(weather *CurrentWeather) bool {
	if weather == nil {
		return false
	}

	// Always notify for significant weather conditions
	significantConditions := []string{
		"rain", "hujan",
		"storm", "badai", "thunderstorm",
		"drizzle", "gerimis",
		"snow", "salju",
		"extreme", "ekstrem",
		"heavy", "lebat",
	}

	descLower := toLower(weather.Description)
	for _, condition := range significantConditions {
		if containsString(descLower, condition) {
			return true
		}
	}

	// Notify for extreme temperatures
	if weather.Temperature > 35 || weather.Temperature < 15 {
		return true
	}

	// Notify for high humidity that might indicate rain
	if weather.Humidity > 90 {
		return true
	}

	// For nice weather, still send morning notification (VIP feature)
	return true
}

// ==================== TASK REMINDER SCHEDULER ====================

// taskReminderScheduler runs every 5 minutes to check for upcoming task deadlines
func (s *SchedulerService) taskReminderScheduler() {
	defer s.wg.Done()

	ticker := time.NewTicker(5 * time.Minute)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			s.checkUpcomingDeadlines()
		case <-s.stopChan:
			log.Println("⏰ Task reminder scheduler stopped")
			return
		}
	}
}

// checkUpcomingDeadlines finds tasks with upcoming deadlines and sends reminders
func (s *SchedulerService) checkUpcomingDeadlines() {
	now := time.Now()

	// Get all tasks with deadlines in the next hour that haven't been completed
	// We'll check for tasks where deadline - reminder_minutes = now (approximately)
	var tasks []models.Task
	if err := s.db.Preload("User").
		Where("is_completed = ? AND deadline IS NOT NULL AND reminder_minutes IS NOT NULL", false).
		Where("deadline BETWEEN ? AND ?", now, now.Add(1*time.Hour)).
		Find(&tasks).Error; err != nil {
		log.Printf("❌ Failed to fetch upcoming tasks: %v", err)
		return
	}

	for _, task := range tasks {
		if task.Deadline == nil || task.ReminderMinutes == nil {
			continue
		}

		// Calculate when reminder should be sent
		reminderTime := task.Deadline.Add(-time.Duration(*task.ReminderMinutes) * time.Minute)

		// Check if we're within 5 minutes of the reminder time
		timeDiff := reminderTime.Sub(now)
		if timeDiff >= -2*time.Minute && timeDiff <= 5*time.Minute {
			go s.sendTaskReminder(task)
		}
	}
}

// sendTaskReminder sends a reminder for a specific task
func (s *SchedulerService) sendTaskReminder(task models.Task) {
	if task.Deadline == nil {
		return
	}

	if err := s.notificationService.SendTaskReminder(task.UserID, task.Title, *task.Deadline); err != nil {
		log.Printf("❌ Failed to send task reminder for task %s: %v", task.ID, err)
	} else {
		log.Printf("✅ Task reminder sent for '%s' (deadline: %v)", task.Title, task.Deadline.Format("15:04"))
	}
}

// ==================== HELPER FUNCTIONS ====================

// toLower converts string to lowercase (simple implementation)
func toLower(s string) string {
	result := make([]byte, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'A' && c <= 'Z' {
			result[i] = c + 32
		} else {
			result[i] = c
		}
	}
	return string(result)
}

// containsString checks if s contains substr
func containsString(s, substr string) bool {
	if len(substr) > len(s) {
		return false
	}
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
