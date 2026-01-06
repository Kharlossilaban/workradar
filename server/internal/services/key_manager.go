package services

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"sync"
	"time"
)

// KeyType represents different types of encryption keys
type KeyType string

const (
	KeyTypeEncryption KeyType = "encryption"
	KeyTypeJWT        KeyType = "jwt"
	KeyTypeHMAC       KeyType = "hmac"
	KeyTypeAPI        KeyType = "api"
)

// KeyInfo holds metadata about an encryption key
type KeyInfo struct {
	ID          string     `json:"id"`
	Type        KeyType    `json:"type"`
	CreatedAt   time.Time  `json:"created_at"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
	IsActive    bool       `json:"is_active"`
	Description string     `json:"description"`
	KeyHash     string     `json:"key_hash"` // Hash of key for verification (not the actual key)
}

// KeyManager handles secure key management
type KeyManager struct {
	mu               sync.RWMutex
	keys             map[string][]byte   // Actual keys stored securely
	keyInfos         map[string]*KeyInfo // Key metadata
	rotationCallback func(keyType KeyType, oldKey, newKey []byte) error
}

var (
	keyManager     *KeyManager
	keyManagerOnce sync.Once
)

// GetKeyManager returns singleton KeyManager instance
func GetKeyManager() *KeyManager {
	keyManagerOnce.Do(func() {
		keyManager = &KeyManager{
			keys:     make(map[string][]byte),
			keyInfos: make(map[string]*KeyInfo),
		}
		// Initialize from environment
		keyManager.initializeFromEnv()
	})
	return keyManager
}

// initializeFromEnv loads keys from environment variables
func (km *KeyManager) initializeFromEnv() {
	// Load encryption key
	if encKey := os.Getenv("ENCRYPTION_KEY"); encKey != "" {
		km.StoreKey("primary_encryption", KeyTypeEncryption, []byte(encKey), "Primary AES-256 encryption key")
	}

	// Load JWT secret
	if jwtSecret := os.Getenv("JWT_SECRET"); jwtSecret != "" {
		km.StoreKey("jwt_secret", KeyTypeJWT, []byte(jwtSecret), "JWT signing secret")
	}

	// Load HMAC key
	if hmacKey := os.Getenv("HMAC_KEY"); hmacKey != "" {
		km.StoreKey("hmac_key", KeyTypeHMAC, []byte(hmacKey), "HMAC signing key")
	}
}

// StoreKey stores a new key securely
func (km *KeyManager) StoreKey(id string, keyType KeyType, key []byte, description string) error {
	km.mu.Lock()
	defer km.mu.Unlock()

	// Validate key length based on type
	if err := km.validateKeyLength(keyType, key); err != nil {
		return err
	}

	// Generate key hash for verification
	keyHash := km.hashKey(key)

	// Store the key
	km.keys[id] = key
	km.keyInfos[id] = &KeyInfo{
		ID:          id,
		Type:        keyType,
		CreatedAt:   time.Now(),
		IsActive:    true,
		Description: description,
		KeyHash:     keyHash,
	}

	return nil
}

// GetKey retrieves a key by ID
func (km *KeyManager) GetKey(id string) ([]byte, error) {
	km.mu.RLock()
	defer km.mu.RUnlock()

	key, exists := km.keys[id]
	if !exists {
		return nil, fmt.Errorf("key not found: %s", id)
	}

	info := km.keyInfos[id]
	if !info.IsActive {
		return nil, fmt.Errorf("key is not active: %s", id)
	}

	// Check expiration
	if info.ExpiresAt != nil && time.Now().After(*info.ExpiresAt) {
		return nil, fmt.Errorf("key has expired: %s", id)
	}

	// Return a copy to prevent modification
	keyCopy := make([]byte, len(key))
	copy(keyCopy, key)
	return keyCopy, nil
}

// GetKeyInfo retrieves key metadata without the actual key
func (km *KeyManager) GetKeyInfo(id string) (*KeyInfo, error) {
	km.mu.RLock()
	defer km.mu.RUnlock()

	info, exists := km.keyInfos[id]
	if !exists {
		return nil, fmt.Errorf("key not found: %s", id)
	}

	// Return a copy
	infoCopy := *info
	return &infoCopy, nil
}

// ListKeys returns info about all stored keys
func (km *KeyManager) ListKeys() []*KeyInfo {
	km.mu.RLock()
	defer km.mu.RUnlock()

	result := make([]*KeyInfo, 0, len(km.keyInfos))
	for _, info := range km.keyInfos {
		infoCopy := *info
		result = append(result, &infoCopy)
	}
	return result
}

// RotateKey rotates an existing key with a new one
func (km *KeyManager) RotateKey(id string, newKey []byte) error {
	km.mu.Lock()
	defer km.mu.Unlock()

	info, exists := km.keyInfos[id]
	if !exists {
		return fmt.Errorf("key not found: %s", id)
	}

	// Validate new key
	if err := km.validateKeyLength(info.Type, newKey); err != nil {
		return err
	}

	// Get old key for callback
	oldKey := km.keys[id]

	// Execute rotation callback if set
	if km.rotationCallback != nil {
		if err := km.rotationCallback(info.Type, oldKey, newKey); err != nil {
			return fmt.Errorf("rotation callback failed: %w", err)
		}
	}

	// Update key
	km.keys[id] = newKey
	info.KeyHash = km.hashKey(newKey)

	return nil
}

// SetRotationCallback sets a callback function for key rotation events
func (km *KeyManager) SetRotationCallback(callback func(keyType KeyType, oldKey, newKey []byte) error) {
	km.mu.Lock()
	defer km.mu.Unlock()
	km.rotationCallback = callback
}

// DeactivateKey marks a key as inactive
func (km *KeyManager) DeactivateKey(id string) error {
	km.mu.Lock()
	defer km.mu.Unlock()

	info, exists := km.keyInfos[id]
	if !exists {
		return fmt.Errorf("key not found: %s", id)
	}

	info.IsActive = false
	return nil
}

// SetKeyExpiration sets an expiration time for a key
func (km *KeyManager) SetKeyExpiration(id string, expiresAt time.Time) error {
	km.mu.Lock()
	defer km.mu.Unlock()

	info, exists := km.keyInfos[id]
	if !exists {
		return fmt.Errorf("key not found: %s", id)
	}

	info.ExpiresAt = &expiresAt
	return nil
}

// VerifyKey verifies a key matches the stored hash
func (km *KeyManager) VerifyKey(id string, key []byte) bool {
	km.mu.RLock()
	defer km.mu.RUnlock()

	info, exists := km.keyInfos[id]
	if !exists {
		return false
	}

	return km.hashKey(key) == info.KeyHash
}

// GenerateSecureKey generates a cryptographically secure random key
func (km *KeyManager) GenerateSecureKey(length int) ([]byte, error) {
	if length < 16 {
		return nil, errors.New("key length must be at least 16 bytes")
	}

	key := make([]byte, length)
	if _, err := rand.Read(key); err != nil {
		return nil, fmt.Errorf("failed to generate random key: %w", err)
	}

	return key, nil
}

// GenerateSecureKeyBase64 generates a base64-encoded secure key
func (km *KeyManager) GenerateSecureKeyBase64(byteLength int) (string, error) {
	key, err := km.GenerateSecureKey(byteLength)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(key), nil
}

// GenerateSecureKeyHex generates a hex-encoded secure key
func (km *KeyManager) GenerateSecureKeyHex(byteLength int) (string, error) {
	key, err := km.GenerateSecureKey(byteLength)
	if err != nil {
		return "", err
	}
	return hex.EncodeToString(key), nil
}

// DeriveKey derives a key from a master key using HKDF-like derivation
func (km *KeyManager) DeriveKey(masterKeyID string, info []byte, length int) ([]byte, error) {
	masterKey, err := km.GetKey(masterKeyID)
	if err != nil {
		return nil, err
	}

	// Simple key derivation using SHA-256
	// For production, consider using crypto/hkdf
	h := sha256.New()
	h.Write(masterKey)
	h.Write(info)

	derived := h.Sum(nil)
	if length > len(derived) {
		return nil, errors.New("requested key length too long")
	}

	return derived[:length], nil
}

// SecureDelete securely deletes a key from memory
func (km *KeyManager) SecureDelete(id string) {
	km.mu.Lock()
	defer km.mu.Unlock()

	if key, exists := km.keys[id]; exists {
		// Overwrite key with zeros
		for i := range key {
			key[i] = 0
		}
		delete(km.keys, id)
	}
	delete(km.keyInfos, id)
}

// Cleanup securely clears all keys from memory
func (km *KeyManager) Cleanup() {
	km.mu.Lock()
	defer km.mu.Unlock()

	for _, key := range km.keys {
		for i := range key {
			key[i] = 0
		}
	}
	km.keys = make(map[string][]byte)
	km.keyInfos = make(map[string]*KeyInfo)
}

// validateKeyLength validates key length based on type
func (km *KeyManager) validateKeyLength(keyType KeyType, key []byte) error {
	switch keyType {
	case KeyTypeEncryption:
		if len(key) < 32 {
			return errors.New("encryption key must be at least 32 bytes")
		}
	case KeyTypeJWT:
		if len(key) < 32 {
			return errors.New("JWT secret must be at least 32 bytes")
		}
	case KeyTypeHMAC:
		if len(key) < 32 {
			return errors.New("HMAC key must be at least 32 bytes")
		}
	case KeyTypeAPI:
		if len(key) < 16 {
			return errors.New("API key must be at least 16 bytes")
		}
	}
	return nil
}

// hashKey creates a secure hash of a key for verification
func (km *KeyManager) hashKey(key []byte) string {
	h := sha256.Sum256(key)
	return hex.EncodeToString(h[:])
}

// GetEncryptionKey is a convenience method to get the primary encryption key
func (km *KeyManager) GetEncryptionKey() ([]byte, error) {
	return km.GetKey("primary_encryption")
}

// GetJWTSecret is a convenience method to get the JWT secret
func (km *KeyManager) GetJWTSecret() ([]byte, error) {
	return km.GetKey("jwt_secret")
}
