package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type MessageType string

const (
	MessageTypePayment MessageType = "payment"
	MessageTypeWelcome MessageType = "welcome"
	MessageTypeTip     MessageType = "tip"
	MessageTypeAlert   MessageType = "alert"
	MessageTypeUpdate  MessageType = "update"
)

type BotMessage struct {
	ID        string                 `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID    string                 `gorm:"type:char(36);not null;index" json:"user_id"`
	Type      MessageType            `gorm:"type:varchar(20);not null" json:"type"`
	Title     string                 `gorm:"type:varchar(255);not null" json:"title"`
	Content   string                 `gorm:"type:text;not null" json:"content"`
	IsRead    bool                   `gorm:"default:false" json:"is_read"`
	Metadata  map[string]interface{} `gorm:"serializer:json" json:"metadata,omitempty"`
	CreatedAt time.Time              `json:"created_at"`
	User      User                   `gorm:"foreignKey:UserID" json:"-"`
}

// BeforeCreate hook to generate UUID
func (m *BotMessage) BeforeCreate(tx *gorm.DB) error {
	if m.ID == "" {
		m.ID = uuid.New().String()
	}
	return nil
}
