package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// EmailVerification stores OTP codes for email verification during registration
type EmailVerification struct {
	ID               string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID           string    `gorm:"type:varchar(36);not null" json:"user_id"`
	Email            string    `gorm:"type:varchar(255);not null;index:idx_ev_email" json:"email"`
	VerificationCode string    `gorm:"type:varchar(6);not null;index:idx_ev_code" json:"verification_code"`
	ExpiresAt        time.Time `gorm:"not null;index:idx_ev_expires_at" json:"expires_at"`
	Used             bool      `gorm:"default:false" json:"used"`
	CreatedAt        time.Time `json:"created_at"`

	// Relations
	User User `gorm:"foreignKey:UserID" json:"-"`
}

// BeforeCreate hook untuk generate UUID
func (e *EmailVerification) BeforeCreate(tx *gorm.DB) error {
	if e.ID == "" {
		e.ID = uuid.New().String()
	}
	return nil
}
