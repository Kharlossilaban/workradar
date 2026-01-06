package repository

import (
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type PasswordResetRepository struct {
	db *gorm.DB
}

func NewPasswordResetRepository(db *gorm.DB) *PasswordResetRepository {
	return &PasswordResetRepository{db: db}
}

// Create membuat password reset token
func (r *PasswordResetRepository) Create(reset *models.PasswordReset) error {
	return r.db.Create(reset).Error
}

// FindByCode mencari password reset by verification code
func (r *PasswordResetRepository) FindByCode(code string) (*models.PasswordReset, error) {
	var reset models.PasswordReset
	err := r.db.Where("verification_code = ? AND used = ? AND expires_at > ?",
		code, false, time.Now()).
		First(&reset).Error
	if err != nil {
		return nil, err
	}
	return &reset, nil
}

// MarkAsUsed menandai token sebagai sudah digunakan
func (r *PasswordResetRepository) MarkAsUsed(id string) error {
	return r.db.Model(&models.PasswordReset{}).
		Where("id = ?", id).
		Update("used", true).Error
}

// DeleteExpired menghapus token yang sudah expired
func (r *PasswordResetRepository) DeleteExpired() error {
	return r.db.Where("expires_at < ?", time.Now()).
		Delete(&models.PasswordReset{}).Error
}
