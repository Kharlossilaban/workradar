package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Category struct {
	ID        string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID    string    `gorm:"type:varchar(36);not null;index:idx_user_id" json:"user_id"`
	Name      string    `gorm:"type:varchar(100);not null" json:"name"`
	Color     string    `gorm:"type:varchar(20);default:'#6C5CE7'" json:"color"`
	IsDefault bool      `gorm:"default:false" json:"is_default"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`

	// Relations
	User  User   `gorm:"foreignKey:UserID" json:"-"`
	Tasks []Task `gorm:"foreignKey:CategoryID" json:"tasks,omitempty"`
}

// BeforeCreate hook untuk generate UUID
func (c *Category) BeforeCreate(tx *gorm.DB) error {
	if c.ID == "" {
		c.ID = uuid.New().String()
	}
	return nil
}

// Default categories yang dibuat saat user register
var DefaultCategories = []string{
	"Kerja",
	"Pribadi",
	"Wishlist",
	"Hari Ulang Tahun",
}

// DefaultCategoryColors map nama ke warna
var DefaultCategoryColors = map[string]string{
	"Kerja":            "#FF6B6B",
	"Pribadi":          "#4ECDC4",
	"Wishlist":         "#FFD93D",
	"Hari Ulang Tahun": "#95E1D3",
}
