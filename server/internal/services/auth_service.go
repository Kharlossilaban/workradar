package services

import (
	"errors"
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

	// TODO: Send email with code (for now return code)
	// In production, integrate with email service
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
