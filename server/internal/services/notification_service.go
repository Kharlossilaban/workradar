package services

import (
	"context"
	"fmt"
	"log"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/workradar/server/internal/repository"
	"google.golang.org/api/option"
)

type NotificationService struct {
	userRepo        *repository.UserRepository
	messagingClient *messaging.Client
	ctx             context.Context
}

func NewNotificationService(userRepo *repository.UserRepository, projectID, credentialsPath string) (*NotificationService, error) {
	ctx := context.Background()

	// Skip initialization if credentials not provided
	if projectID == "" || credentialsPath == "" {
		log.Println("⚠️ Firebase credentials not configured - notifications disabled")
		return &NotificationService{
			userRepo:        userRepo,
			messagingClient: nil,
			ctx:             ctx,
		}, nil
	}

	// Initialize Firebase App
	opt := option.WithCredentialsFile(credentialsPath)
	app, err := firebase.NewApp(ctx, &firebase.Config{
		ProjectID: projectID,
	}, opt)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize Firebase app: %w", err)
	}

	// Get Messaging client
	client, err := app.Messaging(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to get messaging client: %w", err)
	}

	log.Println("✅ Firebase Cloud Messaging initialized successfully")

	return &NotificationService{
		userRepo:        userRepo,
		messagingClient: client,
		ctx:             ctx,
	}, nil
}

// RegisterDevice registers a device FCM token for a user
func (s *NotificationService) RegisterDevice(userID, fcmToken string) error {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return err
	}

	user.FCMToken = &fcmToken
	return s.userRepo.Update(user)
}

// UnregisterDevice removes FCM token from user
func (s *NotificationService) UnregisterDevice(userID string) error {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return err
	}

	user.FCMToken = nil
	return s.userRepo.Update(user)
}

// SendTaskReminder sends a reminder notification for an upcoming task
func (s *NotificationService) SendTaskReminder(userID, taskTitle string, deadline time.Time) error {
	if s.messagingClient == nil {
		return fmt.Errorf("FCM not configured")
	}

	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return err
	}

	if user.FCMToken == nil || *user.FCMToken == "" {
		return fmt.Errorf("user has no FCM token registered")
	}

	timeUntil := time.Until(deadline)
	var timeStr string
	if timeUntil.Hours() < 1 {
		timeStr = fmt.Sprintf("%d menit lagi", int(timeUntil.Minutes()))
	} else if timeUntil.Hours() < 24 {
		timeStr = fmt.Sprintf("%d jam lagi", int(timeUntil.Hours()))
	} else {
		timeStr = fmt.Sprintf("%d hari lagi", int(timeUntil.Hours()/24))
	}

	message := &messaging.Message{
		Token: *user.FCMToken,
		Notification: &messaging.Notification{
			Title: "⏰ Pengingat Tugas",
			Body:  fmt.Sprintf("'%s' deadline %s!", taskTitle, timeStr),
		},
		Data: map[string]string{
			"type":     "task_reminder",
			"task_id":  taskTitle,
			"deadline": deadline.Format(time.RFC3339),
		},
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				Sound: "default",
				Color: "#FF6B35",
			},
		},
		APNS: &messaging.APNSConfig{
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Sound: "default",
				},
			},
		},
	}

	_, err = s.messagingClient.Send(s.ctx, message)
	if err != nil {
		return fmt.Errorf("failed to send notification: %w", err)
	}

	log.Printf("✅ Task reminder sent to user %s for task '%s'", userID, taskTitle)
	return nil
}

// SendWeatherAlert sends a weather-related notification
func (s *NotificationService) SendWeatherAlert(userID, city, condition string, temperature float64) error {
	if s.messagingClient == nil {
		return fmt.Errorf("FCM not configured")
	}

	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return err
	}

	if user.FCMToken == nil || *user.FCMToken == "" {
		return fmt.Errorf("user has no FCM token registered")
	}

	message := &messaging.Message{
		Token: *user.FCMToken,
		Notification: &messaging.Notification{
			Title: fmt.Sprintf("🌤️ Cuaca di %s", city),
			Body:  fmt.Sprintf("%s, %.1f°C. %s", condition, temperature, getWeatherAdvice(condition)),
		},
		Data: map[string]string{
			"type":        "weather_alert",
			"city":        city,
			"condition":   condition,
			"temperature": fmt.Sprintf("%.1f", temperature),
		},
		Android: &messaging.AndroidConfig{
			Priority: "normal",
			Notification: &messaging.AndroidNotification{
				Sound: "default",
				Color: "#4A90E2",
			},
		},
	}

	_, err = s.messagingClient.Send(s.ctx, message)
	if err != nil {
		return fmt.Errorf("failed to send notification: %w", err)
	}

	log.Printf("✅ Weather alert sent to user %s for %s", userID, city)
	return nil
}

// SendHealthRecommendation sends health/productivity recommendation
func (s *NotificationService) SendHealthRecommendation(userID, recommendation string, workloadHours float64) error {
	if s.messagingClient == nil {
		return fmt.Errorf("FCM not configured")
	}

	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return err
	}

	if user.FCMToken == nil || *user.FCMToken == "" {
		return fmt.Errorf("user has no FCM token registered")
	}

	var title string
	var emoji string

	if workloadHours > 12 {
		title = "⚠️ Beban Kerja Sangat Tinggi!"
		emoji = "😰"
	} else if workloadHours > 10 {
		title = "🔔 Peringatan Beban Kerja"
		emoji = "😓"
	} else {
		title = "💡 Saran Produktivitas"
		emoji = "😊"
	}

	message := &messaging.Message{
		Token: *user.FCMToken,
		Notification: &messaging.Notification{
			Title: title,
			Body:  fmt.Sprintf("%s Anda sudah bekerja %.1f jam hari ini. %s", emoji, workloadHours, recommendation),
		},
		Data: map[string]string{
			"type":           "health_recommendation",
			"workload_hours": fmt.Sprintf("%.1f", workloadHours),
		},
		Android: &messaging.AndroidConfig{
			Priority: "normal",
			Notification: &messaging.AndroidNotification{
				Sound: "default",
				Color: "#50C878",
			},
		},
	}

	_, err = s.messagingClient.Send(s.ctx, message)
	if err != nil {
		return fmt.Errorf("failed to send notification: %w", err)
	}

	log.Printf("✅ Health recommendation sent to user %s (%.1fh workload)", userID, workloadHours)
	return nil
}

// Helper function for weather advice
func getWeatherAdvice(condition string) string {
	conditionLower := condition

	// Simple weather advice based on condition
	switch {
	case contains(conditionLower, "rain") || contains(conditionLower, "hujan"):
		return "Jangan lupa bawa payung! ☔"
	case contains(conditionLower, "clear") || contains(conditionLower, "cerah"):
		return "Cuaca bagus untuk aktivitas outdoor! ☀️"
	case contains(conditionLower, "cloud") || contains(conditionLower, "berawan"):
		return "Cuaca sejuk, cocok untuk produktif! ⛅"
	case contains(conditionLower, "storm") || contains(conditionLower, "badai"):
		return "Hindari aktivitas luar rumah. ⛈️"
	default:
		return "Semoga hari Anda menyenangkan!"
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) &&
		(s == substr || len(s) > len(substr) &&
			(s[:len(substr)] == substr || s[len(s)-len(substr):] == substr ||
				findInString(s, substr)))
}

func findInString(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
