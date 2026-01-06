package services

import (
	"errors"
	"log"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"github.com/workradar/server/pkg/utils"
	"gorm.io/gorm"
)

type AuthService struct {
	userRepo          *repository.UserRepository
	categoryRepo      *repository.CategoryRepository
	passwordResetRepo *repository.PasswordResetRepository
	emailService      *EmailService
}

func NewAuthService(
	userRepo *repository.UserRepository,
	categoryRepo *repository.CategoryRepository,
	passwordResetRepo *repository.PasswordResetRepository,
) *AuthService {
	return &AuthService{
		userRepo:          userRepo,
		categoryRepo:      categoryRepo,
		passwordResetRepo: passwordResetRepo,
		emailService:      NewEmailService(),
	}
}

// Register membuat user baru dengan default categories
func (s *AuthService) Register(email, username, password string) (*models.User, string, error) {
	// Check if email already exists
	existing, err := s.userRepo.FindByEmail(email)
	if err == nil && existing != nil {
		return nil, "", errors.New("email already registered")
	}

	// Hash password
	hashedPassword, err := utils.HashPassword(password)
	if err != nil {
		return nil, "", err
	}

	// Create user
	user := &models.User{
		Email:        email,
		Username:     username,
		PasswordHash: hashedPassword,
		AuthProvider: models.AuthProviderLocal,
		UserType:     models.UserTypeRegular,
	}

	if err := s.userRepo.Create(user); err != nil {
		return nil, "", err
	}

	// Create default categories
	if err := s.categoryRepo.CreateDefaultCategories(user.ID); err != nil {
		return nil, "", err
	}

	// Generate JWT token
	token, err := utils.GenerateToken(user.ID, user.Email, string(user.UserType))
	if err != nil {
		return nil, "", err
	}

	return user, token, nil
}

// LoginResult represents the result of a login attempt
type LoginResult struct {
	User        *models.User `json:"user,omitempty"`
	Token       string       `json:"token,omitempty"`
	RequiresMFA bool         `json:"requires_mfa"`
	MFAToken    string       `json:"mfa_token,omitempty"` // Temporary token for MFA verification
}

// Login mengautentikasi user
func (s *AuthService) Login(email, password string) (*models.User, string, error) {
	user, err := s.userRepo.FindByEmail(email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, "", errors.New("invalid email or password")
		}
		return nil, "", err
	}

	// Check password
	if !utils.CheckPasswordHash(password, user.PasswordHash) {
		return nil, "", errors.New("invalid email or password")
	}

	// Generate JWT token
	token, err := utils.GenerateToken(user.ID, user.Email, string(user.UserType))
	if err != nil {
		return nil, "", err
	}

	return user, token, nil
}

// LoginWithMFA handles login with MFA support
func (s *AuthService) LoginWithMFA(email, password string) (*LoginResult, error) {
	user, err := s.userRepo.FindByEmail(email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("invalid email or password")
		}
		return nil, err
	}

	// Check if account is locked
	if user.LockedUntil != nil && user.LockedUntil.After(time.Now()) {
		return nil, errors.New("account is temporarily locked. Please try again later")
	}

	// Check password
	if !utils.CheckPasswordHash(password, user.PasswordHash) {
		// Increment failed login attempts
		s.userRepo.IncrementFailedLogin(user.ID)

		// Lock account after 5 failed attempts
		if user.FailedLoginAttempts >= 4 { // Will be 5 after increment
			lockUntil := time.Now().Add(30 * time.Minute)
			s.userRepo.LockAccount(user.ID, &lockUntil)
			return nil, errors.New("too many failed attempts. Account locked for 30 minutes")
		}

		return nil, errors.New("invalid email or password")
	}

	// Check if MFA is enabled
	if user.MFAEnabled {
		// Generate temporary MFA token (valid for 5 minutes)
		mfaToken, err := utils.GenerateMFAToken(user.ID)
		if err != nil {
			return nil, errors.New("failed to generate MFA token")
		}

		return &LoginResult{
			User:        user,
			RequiresMFA: true,
			MFAToken:    mfaToken,
		}, nil
	}

	// No MFA - generate full token
	token, err := utils.GenerateToken(user.ID, user.Email, string(user.UserType))
	if err != nil {
		return nil, err
	}

	// Update last login
	ip := "" // Will be set by handler
	s.userRepo.UpdateLastLogin(user.ID, ip)

	return &LoginResult{
		User:        user,
		Token:       token,
		RequiresMFA: false,
	}, nil
}

// CompleteMFALogin completes login after MFA verification
func (s *AuthService) CompleteMFALogin(userID string) (*models.User, string, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return nil, "", errors.New("user not found")
	}

	// Generate JWT token
	token, err := utils.GenerateToken(user.ID, user.Email, string(user.UserType))
	if err != nil {
		return nil, "", err
	}

	// Reset failed login and update last login
	s.userRepo.UpdateLastLogin(user.ID, "")

	return user, token, nil
}

// ForgotPassword membuat verification code dan mengirim ke email
func (s *AuthService) ForgotPassword(email string) (string, error) {
	user, err := s.userRepo.FindByEmail(email)
	if err != nil {
		return "", errors.New("user not found")
	}

	// Generate 6-digit code
	code := utils.GenerateVerificationCode()

	// Create password reset record
	reset := &models.PasswordReset{
		UserID:           user.ID,
		Email:            email,
		VerificationCode: code,
		ExpiresAt:        time.Now().Add(15 * time.Minute), // 15 minutes
		Used:             false,
	}

	if err := s.passwordResetRepo.Create(reset); err != nil {
		return "", err
	}

	// Send verification code via email
	if err := s.emailService.SendVerificationCode(email, code); err != nil {
		log.Printf("⚠️ Failed to send verification email: %v", err)
		// Don't return error - still allow development mode where email isn't configured
	}

	// In production, don't return code in response!
	// Only return code for development/testing when SMTP is not configured
	if s.emailService.IsConfigured() {
		return "", nil // Code sent via email, don't expose in API
	}

	// Development mode: return code for testing
	log.Printf("⚠️ DEV MODE: Verification code for %s: %s", email, code)
	return code, nil
}

// ResetPassword mengubah password dengan verification code
func (s *AuthService) ResetPassword(code, newPassword string) error {
	// Find valid reset token
	reset, err := s.passwordResetRepo.FindByCode(code)
	if err != nil {
		return errors.New("invalid or expired verification code")
	}

	// Hash new password
	hashedPassword, err := utils.HashPassword(newPassword)
	if err != nil {
		return err
	}

	// Update user password
	user, err := s.userRepo.FindByID(reset.UserID)
	if err != nil {
		return err
	}

	user.PasswordHash = hashedPassword
	if err := s.userRepo.Update(user); err != nil {
		return err
	}

	// Mark reset as used
	return s.passwordResetRepo.MarkAsUsed(reset.ID)
}

// UpdateProfile memperbarui profile user
func (s *AuthService) UpdateProfile(userID, username string, profilePicture *string) (*models.User, error) {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return nil, err
	}

	user.Username = username
	if profilePicture != nil {
		user.ProfilePicture = profilePicture
	}

	if err := s.userRepo.Update(user); err != nil {
		return nil, err
	}

	return user, nil
}

// ChangePassword mengubah password user (untuk edit profile)
func (s *AuthService) ChangePassword(userID, oldPassword, newPassword string) error {
	user, err := s.userRepo.FindByID(userID)
	if err != nil {
		return err
	}

	// Verify old password
	if !utils.CheckPasswordHash(oldPassword, user.PasswordHash) {
		return errors.New("invalid old password")
	}

	// Hash new password
	hashedPassword, err := utils.HashPassword(newPassword)
	if err != nil {
		return err
	}

	user.PasswordHash = hashedPassword
	return s.userRepo.Update(user)
}

// GoogleOAuthLogin handles Google OAuth login/registration
func (s *AuthService) GoogleOAuthLogin(googleID, email, username, picture string) (*models.User, string, bool, error) {
	// Find or create user
	user, isNew, err := s.userRepo.FindOrCreateGoogleUser(googleID, email, username, picture)
	if err != nil {
		return nil, "", false, err
	}

	// Create default categories if new user
	if isNew {
		if err := s.categoryRepo.CreateDefaultCategories(user.ID); err != nil {
			return nil, "", false, err
		}
	}

	// Generate JWT token
	token, err := utils.GenerateToken(user.ID, user.Email, string(user.UserType))
	if err != nil {
		return nil, "", false, err
	}

	return user, token, isNew, nil
}
