package repository

import (
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type EmailVerificationRepository struct {
	db *gorm.DB
}

func NewEmailVerificationRepository(db *gorm.DB) *EmailVerificationRepository {
	return &EmailVerificationRepository{db: db}
}

// Create membuat email verification OTP
func (r *EmailVerificationRepository) Create(verification *models.EmailVerification) error {
	return r.db.Create(verification).Error
}

// FindByCode mencari email verification by verification code
func (r *EmailVerificationRepository) FindByCode(code string) (*models.EmailVerification, error) {
	var verification models.EmailVerification
	err := r.db.Where("verification_code = ? AND used = ? AND expires_at > ?",
		code, false, time.Now()).
		First(&verification).Error
	if err != nil {
		return nil, err
	}
	return &verification, nil
}

// FindByEmail mencari email verification by email
func (r *EmailVerificationRepository) FindByEmail(email string) (*models.EmailVerification, error) {
	var verification models.EmailVerification
	err := r.db.Where("email = ? AND used = ? AND expires_at > ?",
		email, false, time.Now()).
		Order("created_at DESC").
		First(&verification).Error
	if err != nil {
		return nil, err
	}
	return &verification, nil
}

// MarkAsUsed menandai verification sebagai sudah digunakan
func (r *EmailVerificationRepository) MarkAsUsed(id string) error {
	return r.db.Model(&models.EmailVerification{}).
		Where("id = ?", id).
		Update("used", true).Error
}

// DeleteByEmail menghapus semua verification untuk email tertentu
func (r *EmailVerificationRepository) DeleteByEmail(email string) error {
	return r.db.Where("email = ?", email).
		Delete(&models.EmailVerification{}).Error
}

// DeleteExpired menghapus verification yang sudah expired
func (r *EmailVerificationRepository) DeleteExpired() error {
	return r.db.Where("expires_at < ?", time.Now()).
		Delete(&models.EmailVerification{}).Error
}
