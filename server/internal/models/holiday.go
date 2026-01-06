package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Holiday struct {
	ID          string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID      *string   `gorm:"type:varchar(36)" json:"user_id,omitempty"` // NULL for national holidays
	Name        string    `gorm:"type:varchar(255);not null" json:"name"`
	Date        time.Time `gorm:"type:date;not null" json:"date"`
	IsNational  bool      `gorm:"default:false" json:"is_national"`
	Description *string   `gorm:"type:text" json:"description,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// BeforeCreate hook untuk generate UUID
func (h *Holiday) BeforeCreate(tx *gorm.DB) error {
	if h.ID == "" {
		h.ID = uuid.New().String()
	}
	return nil
}

// HolidayResponse untuk response API
type HolidayResponse struct {
	ID          string    `json:"id"`
	UserID      *string   `json:"user_id,omitempty"`
	Name        string    `json:"name"`
	Date        time.Time `json:"date"`
	IsNational  bool      `json:"is_national"`
	Description *string   `json:"description,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func (h *Holiday) ToResponse() HolidayResponse {
	return HolidayResponse{
		ID:          h.ID,
		UserID:      h.UserID,
		Name:        h.Name,
		Date:        h.Date,
		IsNational:  h.IsNational,
		Description: h.Description,
		CreatedAt:   h.CreatedAt,
		UpdatedAt:   h.UpdatedAt,
	}
}
