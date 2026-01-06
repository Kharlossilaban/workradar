package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Leave struct {
	ID         string     `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID     string     `gorm:"type:varchar(36);not null" json:"user_id"`
	Date       time.Time  `gorm:"type:date;not null" json:"date"`
	Reason     string     `gorm:"type:varchar(255);not null" json:"reason"`
	IsApproved bool       `gorm:"default:false" json:"is_approved"`
	ApprovedBy *string    `gorm:"type:varchar(36)" json:"approved_by,omitempty"`
	ApprovedAt *time.Time `json:"approved_at,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}

// BeforeCreate hook untuk generate UUID
func (l *Leave) BeforeCreate(tx *gorm.DB) error {
	if l.ID == "" {
		l.ID = uuid.New().String()
	}
	return nil
}

// LeaveResponse untuk response API
type LeaveResponse struct {
	ID         string     `json:"id"`
	UserID     string     `json:"user_id"`
	Date       time.Time  `json:"date"`
	Reason     string     `json:"reason"`
	IsApproved bool       `json:"is_approved"`
	ApprovedBy *string    `json:"approved_by,omitempty"`
	ApprovedAt *time.Time `json:"approved_at,omitempty"`
	CreatedAt  time.Time  `json:"created_at"`
	UpdatedAt  time.Time  `json:"updated_at"`
}

func (l *Leave) ToResponse() LeaveResponse {
	return LeaveResponse{
		ID:         l.ID,
		UserID:     l.UserID,
		Date:       l.Date,
		Reason:     l.Reason,
		IsApproved: l.IsApproved,
		ApprovedBy: l.ApprovedBy,
		ApprovedAt: l.ApprovedAt,
		CreatedAt:  l.CreatedAt,
		UpdatedAt:  l.UpdatedAt,
	}
}
