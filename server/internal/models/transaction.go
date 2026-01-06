package models

import (
	"time"

	"gorm.io/gorm"
)

type TransactionStatus string

const (
	TransactionStatusPending    TransactionStatus = "pending"
	TransactionStatusSettlement TransactionStatus = "settlement"
	TransactionStatusExpire     TransactionStatus = "expire"
	TransactionStatusCancel     TransactionStatus = "cancel"
	TransactionStatusDeny       TransactionStatus = "deny"
)

type Transaction struct {
	OrderID       string            `gorm:"primaryKey;type:varchar(50)" json:"order_id"`
	UserID        string            `gorm:"type:char(36);not null;index" json:"user_id"`
	PlanType      PlanType          `gorm:"type:varchar(20);not null" json:"plan_type"` // monthly / yearly
	Amount        float64           `gorm:"type:decimal(15,2);not null" json:"amount"`
	Status        TransactionStatus `gorm:"type:varchar(20);not null;default:'pending'" json:"status"`
	SnapToken     string            `gorm:"type:text" json:"snap_token"`
	PaymentMethod string            `gorm:"type:varchar(50)" json:"payment_method"`
	CreatedAt     time.Time         `json:"created_at"`
	UpdatedAt     time.Time         `json:"updated_at"`
	User          User              `gorm:"foreignKey:UserID" json:"-"`
}

// BeforeCreate hook to set default status
func (t *Transaction) BeforeCreate(tx *gorm.DB) (err error) {
	if t.Status == "" {
		t.Status = TransactionStatusPending
	}
	return
}
