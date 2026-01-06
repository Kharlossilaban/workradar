package services

import (
	"sync"
	"time"
)

// TokenBlacklistService manages blacklisted tokens
type TokenBlacklistService struct {
	blacklist map[string]time.Time
	mu        sync.RWMutex
	cleanup   *time.Ticker
}

var blacklistInstance *TokenBlacklistService

// GetTokenBlacklistService returns singleton instance
func GetTokenBlacklistService() *TokenBlacklistService {
	if blacklistInstance == nil {
		blacklistInstance = &TokenBlacklistService{
			blacklist: make(map[string]time.Time),
			cleanup:   time.NewTicker(1 * time.Hour),
		}

		// Start cleanup goroutine
		go blacklistInstance.cleanupExpiredTokens()
	}

	return blacklistInstance
}

// AddToken menambahkan token ke blacklist
func (s *TokenBlacklistService) AddToken(jti string, expiresAt time.Time) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.blacklist[jti] = expiresAt
}

// IsBlacklisted checks if token is blacklisted
func (s *TokenBlacklistService) IsBlacklisted(jti string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	expiresAt, exists := s.blacklist[jti]
	if !exists {
		return false
	}

	// Check if token sudah expired (otomatis tidak perlu di blacklist lagi)
	if time.Now().After(expiresAt) {
		return false
	}

	return true
}

// cleanupExpiredTokens removes expired tokens dari blacklist
func (s *TokenBlacklistService) cleanupExpiredTokens() {
	for range s.cleanup.C {
		s.mu.Lock()
		now := time.Now()

		for jti, expiresAt := range s.blacklist {
			if now.After(expiresAt) {
				delete(s.blacklist, jti)
			}
		}

		s.mu.Unlock()
	}
}
