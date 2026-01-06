package services

import (
	"errors"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"gorm.io/gorm"
)

type SubscriptionService struct {
	userRepo         *repository.UserRepository
	subscriptionRepo *repository.SubscriptionRepository
	db               *gorm.DB
}

func NewSubscriptionService(
	userRepo *repository.UserRepository,
	subscriptionRepo *repository.SubscriptionRepository,
	db *gorm.DB,
) *SubscriptionService {
	return &SubscriptionService{
		userRepo:         userRepo,
		subscriptionRepo: subscriptionRepo,
		db:               db,
	}
}

// CreateSubscription membuat subscription baru dan upgrade user ke VIP
func (s *SubscriptionService) CreateSubscription(userID string, planType models.PlanType, paymentMethod, transactionID string) (*models.Subscription, error) {
	// Validate plan type
	if planType != models.PlanTypeMonthly && planType != models.PlanTypeYearly {
		return nil, errors.New("invalid plan type")
	}

	// Check if user already has active subscription
	activeSubscription, _ := s.subscriptionRepo.FindActiveByUserID(userID)
	if activeSubscription != nil {
		return nil, errors.New("user already has an active subscription")
	}

	// Calculate dates and price
	startDate := time.Now()
	var endDate time.Time
	var price int

	if planType == models.PlanTypeMonthly {
		endDate = startDate.AddDate(0, 1, 0) // +1 bulan
		price = models.PriceMonthly
	} else {
		endDate = startDate.AddDate(1, 0, 0) // +1 tahun
		price = models.PriceYearly
	}

	// Begin transaction
	tx := s.db.Begin()
	defer func() {
		if r := recover(); r != nil {
			tx.Rollback()
		}
	}()

	// Create subscription
	subscription := &models.Subscription{
		UserID:        userID,
		PlanType:      planType,
		Price:         price,
		StartDate:     startDate,
		EndDate:       endDate,
		IsActive:      true,
		PaymentMethod: &paymentMethod,
		TransactionID: &transactionID,
	}

	if err := tx.Create(subscription).Error; err != nil {
		tx.Rollback()
		return nil, err
	}

	// Update user to VIP
	if err := tx.Model(&models.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"user_type":      models.UserTypeVIP,
			"vip_expires_at": endDate,
		}).Error; err != nil {
		tx.Rollback()
		return nil, err
	}

	// Commit transaction
	if err := tx.Commit().Error; err != nil {
		return nil, err
	}

	return subscription, nil
}

// GetVIPStatus mendapatkan status VIP user
func (s *SubscriptionService) GetVIPStatus(userID string) (*VIPStatusResponse, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return nil, err
	}

	isVIP := user.UserType == models.UserTypeVIP
	var daysRemaining int
	var activeSubscription *models.Subscription

	if isVIP && user.VIPExpiresAt != nil {
		// Calculate days remaining
		duration := time.Until(*user.VIPExpiresAt)
		daysRemaining = int(duration.Hours() / 24)

		if daysRemaining < 0 {
			daysRemaining = 0
			isVIP = false // Expired
		}

		// Get active subscription
		activeSubscription, _ = s.subscriptionRepo.FindActiveByUserID(userID)
	}

	return &VIPStatusResponse{
		IsVIP:              isVIP,
		VIPExpiresAt:       user.VIPExpiresAt,
		DaysRemaining:      daysRemaining,
		ActiveSubscription: activeSubscription,
	}, nil
}

// GetSubscriptionHistory mendapatkan riwayat subscription user
func (s *SubscriptionService) GetSubscriptionHistory(userID string) ([]models.Subscription, error) {
	return s.subscriptionRepo.FindByUserID(userID)
}

// CheckAndDowngradeExpired cek VIP expired dan downgrade otomatis
func (s *SubscriptionService) CheckAndDowngradeExpired(userID string) error {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return err
	}

	if user.UserType == models.UserTypeVIP && user.VIPExpiresAt != nil {
		if time.Now().After(*user.VIPExpiresAt) {
			// Downgrade to regular
			user.UserType = models.UserTypeRegular
			user.VIPExpiresAt = nil

			if err := s.userRepo.Update(user); err != nil {
				return err
			}

			// Deactivate expired subscriptions
			if err := s.subscriptionRepo.DeactivateExpired(userID); err != nil {
				return err
			}
		}
	}

	return nil
}

// DTOs

type VIPStatusResponse struct {
	IsVIP              bool                 `json:"is_vip"`
	VIPExpiresAt       *time.Time           `json:"vip_expires_at,omitempty"`
	DaysRemaining      int                  `json:"days_remaining"`
	ActiveSubscription *models.Subscription `json:"active_subscription,omitempty"`
}
