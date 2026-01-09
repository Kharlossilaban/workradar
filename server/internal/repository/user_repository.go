package repository

import (
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

type UserRepository struct {
	db *gorm.DB
}

func NewUserRepository(db *gorm.DB) *UserRepository {
	return &UserRepository{db: db}
}

// Create membuat user baru
func (r *UserRepository) Create(user *models.User) error {
	return r.db.Create(user).Error
}

// FindByID mencari user by ID
func (r *UserRepository) FindByID(id string) (*models.User, error) {
	var user models.User
	err := r.db.First(&user, "id = ?", id).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByEmail mencari user by email
func (r *UserRepository) FindByEmail(email string) (*models.User, error) {
	var user models.User
	err := r.db.Where("email = ?", email).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindByGoogleID mencari user by Google ID
func (r *UserRepository) FindByGoogleID(googleID string) (*models.User, error) {
	var user models.User
	err := r.db.Where("google_id = ?", googleID).First(&user).Error
	if err != nil {
		return nil, err
	}
	return &user, nil
}

// FindOrCreateGoogleUser finds or creates user from Google OAuth
func (r *UserRepository) FindOrCreateGoogleUser(googleID, email, username, picture string) (*models.User, bool, error) {
	// Try to find by Google ID first
	user, err := r.FindByGoogleID(googleID)
	if err == nil {
		return user, false, nil
	}

	// Try to find by email (user might exist with local auth)
	user, err = r.FindByEmail(email)
	if err == nil {
		// User exists with email, link Google account
		googleIDPtr := &googleID
		user.GoogleID = googleIDPtr
		user.AuthProvider = models.AuthProviderGoogle
		if user.ProfilePicture == nil && picture != "" {
			user.ProfilePicture = &picture
		}
		if saveErr := r.Update(user); saveErr != nil {
			return nil, false, saveErr
		}
		return user, false, nil
	}

	// Create new user
	googleIDPtr := &googleID
	picturePtr := &picture
	newUser := &models.User{
		Email:          email,
		Username:       username,
		GoogleID:       googleIDPtr,
		ProfilePicture: picturePtr,
		AuthProvider:   models.AuthProviderGoogle,
		UserType:       models.UserTypeRegular,
		PasswordHash:   "", // No password for OAuth users
	}

	if createErr := r.Create(newUser); createErr != nil {
		return nil, false, createErr
	}

	return newUser, true, nil
}

// Update memperbarui user data
func (r *UserRepository) Update(user *models.User) error {
	return r.db.Save(user).Error
}

// Delete menghapus user
func (r *UserRepository) Delete(id string) error {
	return r.db.Delete(&models.User{}, "id = ?", id).Error
}

// UpdateWorkDays memperbarui konfigurasi jam kerja user
func (r *UserRepository) UpdateWorkDays(userID string, workDays *string) error {
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Update("work_days", workDays).Error
}

// GetByID alias for FindByID
func (r *UserRepository) GetByID(id string) (*models.User, error) {
	return r.FindByID(id)
}

// ============ MFA (Multi-Factor Authentication) Methods ============

// UpdateMFASecret updates the MFA secret for a user
func (r *UserRepository) UpdateMFASecret(userID, secret string) error {
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Update("mfa_secret", secret).Error
}

// EnableMFA enables MFA for a user
func (r *UserRepository) EnableMFA(userID string) error {
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Update("mfa_enabled", true).Error
}

// DisableMFA disables MFA and clears the secret
func (r *UserRepository) DisableMFA(userID string) error {
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"mfa_enabled": false,
			"mfa_secret":  nil,
		}).Error
}

// ============ Account Lockout Methods ============

// IncrementFailedLogin increments failed login attempts
func (r *UserRepository) IncrementFailedLogin(userID string) error {
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Update("failed_login_attempts", gorm.Expr("failed_login_attempts + 1")).Error
}

// ResetFailedLogin resets failed login attempts to 0
func (r *UserRepository) ResetFailedLogin(userID string) error {
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Update("failed_login_attempts", 0).Error
}

// LockAccount locks user account until specified time
func (r *UserRepository) LockAccount(userID string, until *time.Time) error {
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Update("locked_until", until).Error
}

// UnlockAccount unlocks user account
func (r *UserRepository) UnlockAccount(userID string) error {
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"locked_until":          nil,
			"failed_login_attempts": 0,
		}).Error
}

// UpdateLastLogin updates last login timestamp and IP
func (r *UserRepository) UpdateLastLogin(userID, ip string) error {
	now := time.Now()
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Updates(map[string]interface{}{
			"last_login_at":         now,
			"last_login_ip":         ip,
			"failed_login_attempts": 0,
		}).Error
}

// ============ Email Verification Methods ============

// VerifyEmail marks user email as verified
func (r *UserRepository) VerifyEmail(userID string) error {
	return r.db.Model(&models.User{}).
		Where("id = ?", userID).
		Update("email_verified", true).Error
}
