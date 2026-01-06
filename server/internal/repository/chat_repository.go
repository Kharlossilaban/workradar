package repository

import (
	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type ChatRepository struct {
	db *gorm.DB
}

func NewChatRepository(db *gorm.DB) *ChatRepository {
	return &ChatRepository{db: db}
}

func (r *ChatRepository) Create(message *models.ChatMessage) error {
	return r.db.Create(message).Error
}

func (r *ChatRepository) FindByUserID(userID string, limit int) ([]models.ChatMessage, error) {
	var messages []models.ChatMessage
	err := r.db.Where("user_id = ?", userID).Order("created_at desc").Limit(limit).Find(&messages).Error

	// Reverse to get chronological order for chat history
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}

	return messages, err
}

func (r *ChatRepository) DeleteByUserID(userID string) error {
	return r.db.Where("user_id = ?", userID).Delete(&models.ChatMessage{}).Error
}
