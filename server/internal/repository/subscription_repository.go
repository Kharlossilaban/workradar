package repository

import (
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type SubscriptionRepository struct {
	db *gorm.DB
}

func NewSubscriptionRepository(db *gorm.DB) *SubscriptionRepository {
	return &SubscriptionRepository{db: db}
}

// Create membuat subscription baru
func (r *SubscriptionRepository) Create(subscription *models.Subscription) error {
	return r.db.Create(subscription).Error
}

// FindByID mencari subscription by ID
func (r *SubscriptionRepository) FindByID(id string) (*models.Subscription, error) {
	var subscription models.Subscription
	err := r.db.First(&subscription, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &subscription, nil
}

// FindByUserID mencari semua subscription user (history)
func (r *SubscriptionRepository) FindByUserID(userID string) ([]models.Subscription, error) {
	var subscriptions []models.Subscription
	err := r.db.Where("user_id = ?", userID).Order("created_at DESC").Find(&subscriptions).Error
	return subscriptions, err
}

// FindActiveByUserID mencari subscription yang masih aktif
func (r *SubscriptionRepository) FindActiveByUserID(userID string) (*models.Subscription, error) {
	var subscription models.Subscription
	err := r.db.Where("user_id = ? AND is_active = ? AND end_date > ?", userID, true, time.Now()).
		First(&subscription).Error
	if err != nil {
		return nil, err
	}
	return &subscription, nil
}

// Update memperbarui subscription
func (r *SubscriptionRepository) Update(subscription *models.Subscription) error {
	return r.db.Save(subscription).Error
}

// DeactivateExpired menonaktifkan subscription yang sudah expired
func (r *SubscriptionRepository) DeactivateExpired(userID string) error {
	return r.db.Model(&models.Subscription{}).
		Where("user_id = ? AND is_active = ? AND end_date < ?", userID, true, time.Now()).
		Update("is_active", false).Error
}
