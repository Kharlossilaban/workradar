package repository

import (
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/pkg/utils"
	"gorm.io/gorm"
)

// SecureUserRepository wraps UserRepository with encryption for sensitive fields
// This implements Field-Level Encryption (FLE) for PII data
type SecureUserRepository struct {
	*UserRepository
	encryption *utils.EncryptionService
}

// NewSecureUserRepository creates a new secure user repository
func NewSecureUserRepository(db *gorm.DB) *SecureUserRepository {
	return &SecureUserRepository{
		UserRepository: NewUserRepository(db),
		encryption:     utils.GetEncryptionService(),
	}
}

// Create creates a new user with encrypted sensitive fields
func (r *SecureUserRepository) Create(user *models.User) error {
	// Encrypt sensitive fields before storing
	r.encryptUserFields(user)

	err := r.UserRepository.Create(user)
	if err != nil {
		return err
	}

	// Decrypt for response
	r.decryptUserFields(user)
	return nil
}

// FindByID finds a user and decrypts sensitive fields
func (r *SecureUserRepository) FindByID(id string) (*models.User, error) {
	user, err := r.UserRepository.FindByID(id)
	if err != nil {
		return nil, err
	}

	// Decrypt sensitive fields for use
	r.decryptUserFields(user)
	return user, nil
}

// FindByEmail finds user by email with encryption support
// Note: Email is stored encrypted, so we need to search by hash
func (r *SecureUserRepository) FindByEmail(email string) (*models.User, error) {
	// If encryption is disabled, use direct search
	if !r.encryption.IsEnabled {
		return r.UserRepository.FindByEmail(email)
	}

	// When encryption is enabled, email is stored encrypted
	// We use email_hash for searching
	emailHash := r.encryption.HashForSearch(email)

	var user models.User
	err := r.UserRepository.db.Where("email_hash = ?", emailHash).First(&user).Error
	if err != nil {
		// Fallback to direct email search for backward compatibility
		// This handles users created before encryption was enabled
		fallbackUser, fallbackErr := r.UserRepository.FindByEmail(email)
		if fallbackErr != nil {
			return nil, fallbackErr
		}
		r.decryptUserFields(fallbackUser)
		return fallbackUser, nil
	}

	r.decryptUserFields(&user)
	return &user, nil
}

// FindByGoogleID finds user by Google ID
func (r *SecureUserRepository) FindByGoogleID(googleID string) (*models.User, error) {
	user, err := r.UserRepository.FindByGoogleID(googleID)
	if err != nil {
		return nil, err
	}

	r.decryptUserFields(user)
	return user, nil
}

// FindOrCreateGoogleUser finds or creates Google user with encryption
func (r *SecureUserRepository) FindOrCreateGoogleUser(googleID, email, username, picture string) (*models.User, bool, error) {
	user, isNew, err := r.UserRepository.FindOrCreateGoogleUser(googleID, email, username, picture)
	if err != nil {
		return nil, false, err
	}

	if isNew {
		// Encrypt fields for newly created user
		r.encryptUserFields(user)
		if updateErr := r.UserRepository.Update(user); updateErr != nil {
			return nil, false, updateErr
		}
	}

	r.decryptUserFields(user)
	return user, isNew, nil
}

// Update updates user with encryption
func (r *SecureUserRepository) Update(user *models.User) error {
	// Encrypt sensitive fields before update
	r.encryptUserFields(user)

	err := r.UserRepository.Update(user)
	if err != nil {
		return err
	}

	// Decrypt for response
	r.decryptUserFields(user)
	return nil
}

// GetByID alias for FindByID with decryption
func (r *SecureUserRepository) GetByID(id string) (*models.User, error) {
	return r.FindByID(id)
}

// encryptUserFields encrypts sensitive user data
func (r *SecureUserRepository) encryptUserFields(user *models.User) {
	if !r.encryption.IsEnabled {
		return
	}

	// Encrypt email
	if user.Email != "" {
		// Store searchable hash for email lookup
		user.EmailHash = r.encryption.HashForSearch(user.Email)
		// Encrypt actual email
		if encrypted, err := r.encryption.EncryptEmail(user.Email); err == nil {
			user.EncryptedEmail = encrypted
		}
	}

	// Encrypt phone if exists
	if user.Phone != nil && *user.Phone != "" {
		if encrypted, err := r.encryption.EncryptPhone(*user.Phone); err == nil {
			user.EncryptedPhone = &encrypted
		}
	}

	// Note: MFA secret is already encrypted in MFA service
	// Profile picture URL and other non-PII fields don't need encryption
}

// decryptUserFields decrypts sensitive user data
func (r *SecureUserRepository) decryptUserFields(user *models.User) {
	if !r.encryption.IsEnabled {
		return
	}

	// Decrypt email if encrypted version exists
	if user.EncryptedEmail != "" {
		if decrypted, err := r.encryption.DecryptEmail(user.EncryptedEmail); err == nil {
			user.Email = decrypted
		}
	}

	// Decrypt phone if encrypted version exists
	if user.EncryptedPhone != nil && *user.EncryptedPhone != "" {
		if decrypted, err := r.encryption.DecryptPhone(*user.EncryptedPhone); err == nil {
			user.Phone = &decrypted
		}
	}
}

// MaskUserPII returns user with masked PII for logging/debugging
func (r *SecureUserRepository) MaskUserPII(user *models.User) *models.User {
	maskedUser := *user

	// Mask email
	maskedUser.Email = utils.MaskEmail(user.Email)

	// Mask phone
	if user.Phone != nil && *user.Phone != "" {
		masked := utils.MaskPhone(*user.Phone)
		maskedUser.Phone = &masked
	}

	// Clear sensitive fields
	maskedUser.PasswordHash = "[REDACTED]"
	if maskedUser.MFASecret != nil {
		redacted := "[REDACTED]"
		maskedUser.MFASecret = &redacted
	}

	return &maskedUser
}

// EncryptExistingUsers encrypts data for existing users (migration helper)
func (r *SecureUserRepository) EncryptExistingUsers() error {
	if !r.encryption.IsEnabled {
		return nil
	}

	var users []models.User
	if err := r.UserRepository.db.Find(&users).Error; err != nil {
		return err
	}

	for _, user := range users {
		// Skip if already encrypted
		if user.EncryptedEmail != "" {
			continue
		}

		r.encryptUserFields(&user)
		if err := r.UserRepository.db.Save(&user).Error; err != nil {
			return err
		}
	}

	return nil
}
