package services

import (
	"github.com/workradar/server/pkg/utils"
)

// EncryptionService is a wrapper around utils.EncryptionService for backward compatibility
// The actual implementation is in pkg/utils/encryption.go to avoid import cycles
type EncryptionService = utils.EncryptionService

// GetEncryptionService returns the singleton encryption service instance
// Delegates to utils package
func GetEncryptionService() *EncryptionService {
	return utils.GetEncryptionService()
}

// NewEncryptionService creates a new encryption service
// Delegates to utils package
func NewEncryptionService(key string) (*EncryptionService, error) {
	return utils.NewEncryptionService(key)
}

// MaskEmail masks email for display (e.g., "joh***@example.com")
func MaskEmail(email string) string {
	return utils.MaskEmail(email)
}

// MaskPhone masks phone number for display (e.g., "0812***4567")
func MaskPhone(phone string) string {
	return utils.MaskPhone(phone)
}

// GenerateEncryptionKey generates a secure random encryption key
func GenerateEncryptionKey() (string, error) {
	return utils.GenerateEncryptionKey()
}

// SanitizeForLog removes sensitive data before logging
func SanitizeForLog(data map[string]interface{}) map[string]interface{} {
	return utils.SanitizeForLog(data)
}
