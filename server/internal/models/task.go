package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type RepeatType string

const (
	RepeatNone    RepeatType = "none"
	RepeatHourly  RepeatType = "hourly"
	RepeatDaily   RepeatType = "daily"
	RepeatWeekly  RepeatType = "weekly"
	RepeatMonthly RepeatType = "monthly"
)

type Task struct {
	ID              string     `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID          string     `gorm:"type:varchar(36);not null;index:idx_user_id" json:"user_id"`
	CategoryID      *string    `gorm:"type:varchar(36);index:idx_category_id" json:"category_id"`
	Title           string     `gorm:"type:varchar(255);not null" json:"title"`
	Description     *string    `gorm:"type:text" json:"description,omitempty"`
	Deadline        *time.Time `json:"deadline,omitempty"`
	ReminderMinutes *int       `json:"reminder_minutes,omitempty"`
	DurationMinutes *int       `json:"duration_minutes,omitempty"`
	Difficulty      *string    `gorm:"type:varchar(20)" json:"difficulty,omitempty"` // relaxed, normal, focus
	RepeatType      RepeatType `gorm:"type:enum('none','hourly','daily','weekly','monthly');default:'none'" json:"repeat_type"`
	RepeatInterval  int        `gorm:"default:1" json:"repeat_interval"`
	RepeatEndDate   *time.Time `gorm:"type:date" json:"repeat_end_date,omitempty"`
	IsCompleted     bool       `gorm:"default:false;index:idx_is_completed" json:"is_completed"`
	CompletedAt     *time.Time `json:"completed_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at"`

	// Relations
	User     User      `gorm:"foreignKey:UserID" json:"-"`
	Category *Category `gorm:"foreignKey:CategoryID" json:"category,omitempty"`
}

// BeforeCreate hook untuk generate UUID
func (t *Task) BeforeCreate(tx *gorm.DB) error {
	if t.ID == "" {
		t.ID = uuid.New().String()
	}
	return nil
}

// TaskWithCategory response dengan nama kategori
type TaskWithCategory struct {
	Task
	CategoryName string `json:"category_name,omitempty"`
}
