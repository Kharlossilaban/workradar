package repository

import (
	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type BotMessageRepository struct {
	db *gorm.DB
}

func NewBotMessageRepository(db *gorm.DB) *BotMessageRepository {
	return &BotMessageRepository{db: db}
}

// Create stores a new bot message
func (r *BotMessageRepository) Create(message *models.BotMessage) error {
	return r.db.Create(message).Error
}

// FindByUserID retrieves all messages for a user, ordered by creation date
func (r *BotMessageRepository) FindByUserID(userID string) ([]models.BotMessage, error) {
	var messages []models.BotMessage
	err := r.db.Where("user_id = ?", userID).Order("created_at desc").Find(&messages).Error
	return messages, err
}

// FindUnreadByUserID retrieves all unread messages for a user
func (r *BotMessageRepository) FindUnreadByUserID(userID string) ([]models.BotMessage, error) {
	var messages []models.BotMessage
	err := r.db.Where("user_id = ? AND is_read = ?", userID, false).Order("created_at desc").Find(&messages).Error
	return messages, err
}

// MarkAsRead marks a specific message as read
func (r *BotMessageRepository) MarkAsRead(id string) error {
	return r.db.Model(&models.BotMessage{}).Where("id = ?", id).Update("is_read", true).Error
}

// MarkAllAsRead marks all messages for a user as read
func (r *BotMessageRepository) MarkAllAsRead(userID string) error {
	return r.db.Model(&models.BotMessage{}).Where("user_id = ? AND is_read = ?", userID, false).Update("is_read", true).Error
}

// DeleteByID deletes a message by ID
func (r *BotMessageRepository) DeleteByID(id string) error {
	return r.db.Delete(&models.BotMessage{}, "id = ?", id).Error
}

// CountUnread counts unread messages for a user
func (r *BotMessageRepository) CountUnread(userID string) (int64, error) {
	var count int64
	err := r.db.Model(&models.BotMessage{}).Where("user_id = ? AND is_read = ?", userID, false).Count(&count).Error
	return count, err
}
