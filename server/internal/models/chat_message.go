package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ChatRole string

const (
	ChatRoleUser  ChatRole = "user"
	ChatRoleModel ChatRole = "model"
)

type ChatMessage struct {
	ID        string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID    string    `gorm:"type:char(36);not null;index" json:"user_id"`
	Role      ChatRole  `gorm:"type:varchar(10);not null" json:"role"` // 'user' or 'model'
	Content   string    `gorm:"type:text;not null" json:"content"`
	CreatedAt time.Time `json:"created_at"`
	User      User      `gorm:"foreignKey:UserID" json:"-"`
}

func (m *ChatMessage) BeforeCreate(tx *gorm.DB) error {
	if m.ID == "" {
		m.ID = uuid.New().String()
	}
	return nil
}
