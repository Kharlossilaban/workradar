package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type PlanType string

const (
	PlanTypeMonthly PlanType = "monthly"
	PlanTypeYearly  PlanType = "yearly"
)

type Subscription struct {
	ID            string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID        string    `gorm:"type:varchar(36);not null;index:idx_user_id" json:"user_id"`
	PlanType      PlanType  `gorm:"type:enum('monthly','yearly');not null" json:"plan_type"`
	Price         int       `gorm:"not null" json:"price"`
	StartDate     time.Time `gorm:"type:date;not null" json:"start_date"`
	EndDate       time.Time `gorm:"type:date;not null;index:idx_end_date" json:"end_date"`
	IsActive      bool      `gorm:"default:true;index:idx_is_active" json:"is_active"`
	PaymentMethod *string   `gorm:"type:varchar(50)" json:"payment_method,omitempty"`
	TransactionID *string   `gorm:"type:varchar(255)" json:"transaction_id,omitempty"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`

	// Relations
	User User `gorm:"foreignKey:UserID" json:"-"`
}

// BeforeCreate hook untuk generate UUID
func (s *Subscription) BeforeCreate(tx *gorm.DB) error {
	if s.ID == "" {
		s.ID = uuid.New().String()
	}
	return nil
}

// Subscription prices (in IDR)
const (
	PriceMonthly = 49000  // Rp 49K
	PriceYearly  = 499000 // Rp 499K
)
