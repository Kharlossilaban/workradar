package utils

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"
)

// EncryptionService handles encryption/decryption of sensitive data using AES-256-GCM
// This is placed in utils to avoid import cycles between repository and services
type EncryptionService struct {
	key       []byte
	gcm       cipher.AEAD
	IsEnabled bool
	mu        sync.RWMutex
}

var (
	globalEncryptionService *EncryptionService
	encryptionOnce          sync.Once
)

// GetEncryptionService returns the singleton encryption service instance
func GetEncryptionService() *EncryptionService {
	encryptionOnce.Do(func() {
		globalEncryptionService = &EncryptionService{}
		if err := globalEncryptionService.initializeFromEnv(); err != nil {
			fmt.Printf("⚠️ Encryption service initialization failed: %v\n", err)
			globalEncryptionService.IsEnabled = false
		}
	})
	return globalEncryptionService
}

// NewEncryptionService creates a new encryption service
// key should be at least 32 characters for AES-256
func NewEncryptionService(key string) (*EncryptionService, error) {
	if key == "" {
		return nil, fmt.Errorf("encryption key cannot be empty")
	}

	// Derive 32-byte key using SHA-256 (allows any key length >= 32)
	hash := sha256.Sum256([]byte(key))

	service := &EncryptionService{
		key: hash[:],
	}

	// Create cipher block
	block, err := aes.NewCipher(service.key)
	if err != nil {
		return nil, fmt.Errorf("failed to create cipher: %w", err)
	}

	// Create GCM mode
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("failed to create GCM: %w", err)
	}

	service.gcm = gcm
	service.IsEnabled = true

	return service, nil
}

// initializeFromEnv initializes encryption from environment variable
func (s *EncryptionService) initializeFromEnv() error {
	encryptionKey := os.Getenv("ENCRYPTION_KEY")

	if encryptionKey == "" {
		fmt.Println("⚠️ WARNING: ENCRYPTION_KEY not set. Field-level encryption is DISABLED.")
		fmt.Println("⚠️ Set ENCRYPTION_KEY environment variable (min 32 chars) for production use.")
		s.IsEnabled = false
		return nil
	}

	if len(encryptionKey) < 32 {
		return fmt.Errorf("ENCRYPTION_KEY must be at least 32 characters, got %d", len(encryptionKey))
	}

	// Derive 32-byte key using SHA-256
	hash := sha256.Sum256([]byte(encryptionKey))
	s.key = hash[:]

	// Create cipher block
	block, err := aes.NewCipher(s.key)
	if err != nil {
		return fmt.Errorf("failed to create cipher: %w", err)
	}

	// Create GCM mode
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return fmt.Errorf("failed to create GCM: %w", err)
	}

	s.gcm = gcm
	s.IsEnabled = true

	fmt.Println("✅ Encryption service initialized with AES-256-GCM")
	return nil
}

// Encrypt encrypts plaintext using AES-256-GCM
func (s *EncryptionService) Encrypt(plaintext string) (string, error) {
	if plaintext == "" {
		return "", nil
	}

	// If encryption is disabled, return plaintext
	if !s.IsEnabled {
		return plaintext, nil
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	// Generate nonce
	nonce := make([]byte, s.gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", fmt.Errorf("failed to generate nonce: %w", err)
	}

	// Encrypt (nonce is prepended to ciphertext)
	ciphertext := s.gcm.Seal(nonce, nonce, []byte(plaintext), nil)

	// Encode to base64 for storage
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt decrypts ciphertext using AES-256-GCM
func (s *EncryptionService) Decrypt(ciphertext string) (string, error) {
	if ciphertext == "" {
		return "", nil
	}

	// If encryption is disabled, return ciphertext as-is
	if !s.IsEnabled {
		return ciphertext, nil
	}

	s.mu.RLock()
	defer s.mu.RUnlock()

	// Decode from base64
	data, err := base64.StdEncoding.DecodeString(ciphertext)
	if err != nil {
		// If decoding fails, assume it's plaintext (migration scenario)
		return ciphertext, nil
	}

	// Extract nonce
	nonceSize := s.gcm.NonceSize()
	if len(data) < nonceSize {
		// Too short to be encrypted, return as-is (plaintext migration)
		return ciphertext, nil
	}

	nonce, cipherBytes := data[:nonceSize], data[nonceSize:]

	// Decrypt
	plaintext, err := s.gcm.Open(nil, nonce, cipherBytes, nil)
	if err != nil {
		// Decryption failed - might be plaintext from before encryption was enabled
		return ciphertext, nil
	}

	return string(plaintext), nil
}

// EncryptEmail encrypts email address
func (s *EncryptionService) EncryptEmail(email string) (string, error) {
	return s.Encrypt(strings.ToLower(email))
}

// DecryptEmail decrypts email address
func (s *EncryptionService) DecryptEmail(encrypted string) (string, error) {
	return s.Decrypt(encrypted)
}

// EncryptPhone encrypts phone number
func (s *EncryptionService) EncryptPhone(phone string) (string, error) {
	return s.Encrypt(phone)
}

// DecryptPhone decrypts phone number
func (s *EncryptionService) DecryptPhone(encrypted string) (string, error) {
	return s.Decrypt(encrypted)
}

// HashForSearch creates a deterministic hash for searching encrypted data
func (s *EncryptionService) HashForSearch(data string) string {
	if data == "" || !s.IsEnabled {
		return data
	}

	// Combine with key for keyed hash
	combined := append(s.key, []byte(strings.ToLower(data))...)
	hash := sha256.Sum256(combined)

	return hex.EncodeToString(hash[:])
}

// EncryptSensitiveFields encrypts sensitive user data before storing in database
func (s *EncryptionService) EncryptSensitiveFields(data map[string]string) (map[string]string, error) {
	encrypted := make(map[string]string)

	for key, value := range data {
		encryptedValue, err := s.Encrypt(value)
		if err != nil {
			return nil, fmt.Errorf("failed to encrypt field %s: %w", key, err)
		}
		encrypted[key] = encryptedValue
	}

	return encrypted, nil
}

// DecryptSensitiveFields decrypts sensitive user data after retrieving from database
func (s *EncryptionService) DecryptSensitiveFields(data map[string]string) (map[string]string, error) {
	decrypted := make(map[string]string)

	for key, value := range data {
		decryptedValue, err := s.Decrypt(value)
		if err != nil {
			return nil, fmt.Errorf("failed to decrypt field %s: %w", key, err)
		}
		decrypted[key] = decryptedValue
	}

	return decrypted, nil
}

// MaskEmail masks email for display (e.g., "joh***@example.com")
func MaskEmail(email string) string {
	if email == "" {
		return ""
	}

	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return email
	}

	username := parts[0]
	domain := parts[1]

	if len(username) <= 3 {
		return username[:1] + "***@" + domain
	}

	return username[:3] + "***@" + domain
}

// MaskPhone masks phone number for display (e.g., "0812***4567")
func MaskPhone(phone string) string {
	if phone == "" {
		return ""
	}

	if len(phone) <= 4 {
		return "***"
	}

	return phone[:4] + "***" + phone[len(phone)-4:]
}

// GenerateEncryptionKey generates a secure random encryption key
func GenerateEncryptionKey() (string, error) {
	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(key), nil
}

// RotateKey rotates encryption key (requires re-encryption of existing data)
func (s *EncryptionService) RotateKey(newKey string) error {
	if len(newKey) < 32 {
		return fmt.Errorf("new key must be at least 32 characters")
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	// Derive new key
	hash := sha256.Sum256([]byte(newKey))

	// Create new cipher
	block, err := aes.NewCipher(hash[:])
	if err != nil {
		return err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return err
	}

	s.key = hash[:]
	s.gcm = gcm

	return nil
}

// SanitizeForLog removes sensitive data before logging
func SanitizeForLog(data map[string]interface{}) map[string]interface{} {
	sensitiveKeys := []string{
		"password",
		"token",
		"secret",
		"api_key",
		"credential",
		"authorization",
	}

	sanitized := make(map[string]interface{})
	for key, value := range data {
		// Check if key contains sensitive terms
		isSensitive := false
		for _, sensitiveKey := range sensitiveKeys {
			if containsIgnoreCase(key, sensitiveKey) {
				isSensitive = true
				break
			}
		}

		if isSensitive {
			sanitized[key] = "***REDACTED***"
		} else {
			sanitized[key] = value
		}
	}

	return sanitized
}

func containsIgnoreCase(s, substr string) bool {
	s = toLowerSimple(s)
	substr = toLowerSimple(substr)
	return len(s) >= len(substr) && findSubstring(s, substr)
}

func toLowerSimple(s string) string {
	result := make([]byte, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c >= 'A' && c <= 'Z' {
			result[i] = c + 32
		} else {
			result[i] = c
		}
	}
	return string(result)
}

func findSubstring(s, substr string) bool {
	if len(substr) > len(s) {
		return false
	}
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
