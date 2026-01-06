package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type UserType string
type AuthProvider string

const (
	UserTypeRegular UserType = "regular"
	UserTypeVIP     UserType = "vip"

	AuthProviderLocal  AuthProvider = "local"
	AuthProviderGoogle AuthProvider = "google"
)

type User struct {
	ID             string       `gorm:"type:varchar(36);primaryKey" json:"id"`
	Email          string       `gorm:"type:varchar(255);uniqueIndex;not null" json:"email"`
	Username       string       `gorm:"type:varchar(100);not null" json:"username"`
	PasswordHash   string       `gorm:"type:varchar(255)" json:"-"`
	ProfilePicture *string      `gorm:"type:text" json:"profile_picture"`
	AuthProvider   AuthProvider `gorm:"type:enum('local','google');default:'local'" json:"auth_provider"`
	GoogleID       *string      `gorm:"type:varchar(255)" json:"google_id,omitempty"`
	FCMToken       *string      `gorm:"type:varchar(255)" json:"-"` // Don't expose in JSON
	UserType       UserType     `gorm:"type:enum('regular','vip');default:'regular'" json:"user_type"`
	VIPExpiresAt   *time.Time   `gorm:"column:vip_expires_at" json:"vip_expires_at,omitempty"`
	WorkDays       *string      `gorm:"type:json" json:"work_days,omitempty"`

	// Field-Level Encryption Fields (Minggu 4: Enkripsi & Perlindungan Data)
	Phone          *string `gorm:"type:varchar(20)" json:"phone,omitempty"`
	EncryptedEmail string  `gorm:"type:text" json:"-"`              // AES-256 encrypted email
	EncryptedPhone *string `gorm:"type:text" json:"-"`              // AES-256 encrypted phone
	EmailHash      string  `gorm:"type:varchar(64);index" json:"-"` // SHA-256 hash for searchability

	// Security Fields (Minggu 3: Account Lockout & MFA)
	FailedLoginAttempts int        `gorm:"default:0" json:"-"`
	LockedUntil         *time.Time `json:"-"`
	PasswordChangedAt   *time.Time `json:"-"`
	MFAEnabled          bool       `gorm:"default:false" json:"mfa_enabled"`
	MFASecret           *string    `gorm:"type:varchar(255)" json:"-"`
	LastLoginAt         *time.Time `json:"last_login_at,omitempty"`
	LastLoginIP         *string    `gorm:"type:varchar(45)" json:"-"`

	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// Relations
	Categories    []Category     `gorm:"foreignKey:UserID" json:"categories,omitempty"`
	Tasks         []Task         `gorm:"foreignKey:UserID" json:"tasks,omitempty"`
	Subscriptions []Subscription `gorm:"foreignKey:UserID" json:"subscriptions,omitempty"`
}

// BeforeCreate hook untuk generate UUID
func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.ID == "" {
		u.ID = uuid.New().String()
	}
	return nil
}

// UserResponse untuk response tanpa sensitive data
type UserResponse struct {
	ID             string       `json:"id"`
	Email          string       `json:"email"`
	Username       string       `json:"username"`
	ProfilePicture *string      `json:"profile_picture"`
	AuthProvider   AuthProvider `json:"auth_provider"`
	UserType       UserType     `json:"user_type"`
	VIPExpiresAt   *time.Time   `json:"vip_expires_at,omitempty"`
	WorkDays       *string      `json:"work_days,omitempty"`
	CreatedAt      time.Time    `json:"created_at"`
	UpdatedAt      time.Time    `json:"updated_at"`
}

func (u *User) ToResponse() UserResponse {
	return UserResponse{
		ID:             u.ID,
		Email:          u.Email,
		Username:       u.Username,
		ProfilePicture: u.ProfilePicture,
		AuthProvider:   u.AuthProvider,
		UserType:       u.UserType,
		VIPExpiresAt:   u.VIPExpiresAt,
		WorkDays:       u.WorkDays,
		CreatedAt:      u.CreatedAt,
		UpdatedAt:      u.UpdatedAt,
	}
}
