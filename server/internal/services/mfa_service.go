package services

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha1"
	"encoding/base32"
	"encoding/binary"
	"fmt"
	"strings"
	"time"

	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
)

// MFAService handles Multi-Factor Authentication using TOTP
type MFAService struct {
	userRepo *repository.UserRepository
}

// NewMFAService creates a new MFA service instance
func NewMFAService(userRepo *repository.UserRepository) *MFAService {
	return &MFAService{
		userRepo: userRepo,
	}
}

// MFASetupResponse contains the data needed for MFA setup
type MFASetupResponse struct {
	Secret     string `json:"secret"`
	QRCodeURL  string `json:"qr_code_url"`
	ManualCode string `json:"manual_code"`
}

// GenerateSecret generates a new TOTP secret for a user
func (s *MFAService) GenerateSecret(userID string) (*MFASetupResponse, error) {
	// Get user to get email for QR code
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}

	// Generate random secret (20 bytes = 160 bits, standard for TOTP)
	secret := make([]byte, 20)
	if _, err := rand.Read(secret); err != nil {
		return nil, fmt.Errorf("failed to generate secret: %w", err)
	}

	// Encode secret to base32 (standard for TOTP)
	secretBase32 := base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(secret)

	// Create otpauth URL for QR code (compatible with Google Authenticator)
	issuer := "Workradar"
	accountName := user.Email
	otpauthURL := fmt.Sprintf("otpauth://totp/%s:%s?secret=%s&issuer=%s&algorithm=SHA1&digits=6&period=30",
		issuer, accountName, secretBase32, issuer)

	// Store secret temporarily (user must verify before it's fully enabled)
	if err := s.userRepo.UpdateMFASecret(userID, secretBase32); err != nil {
		return nil, fmt.Errorf("failed to save secret: %w", err)
	}

	// Format manual code for easier reading (groups of 4)
	manualCode := formatSecretForDisplay(secretBase32)

	return &MFASetupResponse{
		Secret:     secretBase32,
		QRCodeURL:  otpauthURL,
		ManualCode: manualCode,
	}, nil
}

// VerifyAndEnable verifies a TOTP code and enables MFA if correct
func (s *MFAService) VerifyAndEnable(userID, code string) error {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	if user.MFASecret == nil || *user.MFASecret == "" {
		return fmt.Errorf("MFA not set up - please generate secret first")
	}

	// Verify the code
	if !s.VerifyCode(*user.MFASecret, code) {
		return fmt.Errorf("invalid verification code")
	}

	// Enable MFA
	if err := s.userRepo.EnableMFA(userID); err != nil {
		return fmt.Errorf("failed to enable MFA: %w", err)
	}

	return nil
}

// VerifyCode verifies a TOTP code against the secret
func (s *MFAService) VerifyCode(secret, code string) bool {
	// Allow for time drift (check current, previous, and next time steps)
	currentTime := time.Now().Unix()
	timeStep := int64(30) // 30 seconds per step (standard TOTP)

	for i := int64(-1); i <= 1; i++ {
		timestamp := currentTime + (i * timeStep)
		expectedCode := generateTOTP(secret, timestamp/timeStep)
		if expectedCode == code {
			return true
		}
	}

	return false
}

// VerifyLogin verifies TOTP code during login
func (s *MFAService) VerifyLogin(userID, code string) error {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	if !user.MFAEnabled {
		return fmt.Errorf("MFA not enabled for this user")
	}

	if user.MFASecret == nil || *user.MFASecret == "" {
		return fmt.Errorf("MFA secret not found")
	}

	if !s.VerifyCode(*user.MFASecret, code) {
		return fmt.Errorf("invalid MFA code")
	}

	return nil
}

// DisableMFA disables MFA for a user after verifying current code
func (s *MFAService) DisableMFA(userID, code string) error {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}

	if !user.MFAEnabled {
		return fmt.Errorf("MFA is not enabled")
	}

	// Verify code before disabling
	if user.MFASecret != nil && !s.VerifyCode(*user.MFASecret, code) {
		return fmt.Errorf("invalid verification code")
	}

	// Disable MFA
	if err := s.userRepo.DisableMFA(userID); err != nil {
		return fmt.Errorf("failed to disable MFA: %w", err)
	}

	return nil
}

// IsMFAEnabled checks if MFA is enabled for a user
func (s *MFAService) IsMFAEnabled(userID string) (bool, error) {
	user, err := s.userRepo.GetByID(userID)
	if err != nil {
		return false, err
	}
	return user.MFAEnabled, nil
}

// GetMFAStatus returns MFA status for a user
func (s *MFAService) GetMFAStatus(userID string) (*models.User, error) {
	return s.userRepo.GetByID(userID)
}

// generateTOTP generates a 6-digit TOTP code
func generateTOTP(secret string, counter int64) string {
	// Decode base32 secret
	key, err := base32.StdEncoding.WithPadding(base32.NoPadding).DecodeString(strings.ToUpper(secret))
	if err != nil {
		return ""
	}

	// Convert counter to bytes (big-endian)
	counterBytes := make([]byte, 8)
	binary.BigEndian.PutUint64(counterBytes, uint64(counter))

	// HMAC-SHA1
	h := hmac.New(sha1.New, key)
	h.Write(counterBytes)
	hash := h.Sum(nil)

	// Dynamic truncation
	offset := hash[len(hash)-1] & 0x0f
	truncatedHash := binary.BigEndian.Uint32(hash[offset:offset+4]) & 0x7fffffff

	// Generate 6-digit code
	code := truncatedHash % 1000000

	return fmt.Sprintf("%06d", code)
}

// formatSecretForDisplay formats the secret for manual entry
func formatSecretForDisplay(secret string) string {
	var formatted strings.Builder
	for i, char := range secret {
		if i > 0 && i%4 == 0 {
			formatted.WriteString(" ")
		}
		formatted.WriteRune(char)
	}
	return formatted.String()
}

// GenerateBackupCodes generates backup codes for account recovery
// Note: This is an optional enhancement for future implementation
func (s *MFAService) GenerateBackupCodes(userID string, count int) ([]string, error) {
	codes := make([]string, count)
	for i := 0; i < count; i++ {
		code := make([]byte, 4)
		if _, err := rand.Read(code); err != nil {
			return nil, err
		}
		codes[i] = fmt.Sprintf("%08x", code)
	}
	return codes, nil
}
