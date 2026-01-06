package services

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"math"
	"sync"
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

// ============================================
// PROGRESSIVE DELAY SERVICE
// Minggu 7 & 10: Brute Force Prevention
// ============================================

// ProgressiveDelayConfig holds delay configuration
type ProgressiveDelayConfig struct {
	BaseDelaySeconds    float64       // Base delay in seconds
	MaxDelaySeconds     float64       // Maximum delay
	DelayMultiplier     float64       // Multiplier for exponential backoff
	ResetAfter          time.Duration // Reset counter after this duration of no attempts
	LockoutThreshold    int           // Number of failures before lockout
	LockoutDuration     time.Duration // Duration of lockout
	EnableIPTracking    bool          // Track by IP
	EnableEmailTracking bool          // Track by email
}

// DefaultProgressiveDelayConfig returns default config
func DefaultProgressiveDelayConfig() ProgressiveDelayConfig {
	return ProgressiveDelayConfig{
		BaseDelaySeconds:    1.0,
		MaxDelaySeconds:     60.0,
		DelayMultiplier:     2.0,
		ResetAfter:          15 * time.Minute,
		LockoutThreshold:    5,
		LockoutDuration:     30 * time.Minute,
		EnableIPTracking:    true,
		EnableEmailTracking: true,
	}
}

// AttemptRecord tracks login attempts
type AttemptRecord struct {
	Attempts     int
	LastAttempt  time.Time
	FirstAttempt time.Time
	LockedUntil  *time.Time
	CurrentDelay time.Duration
}

// ProgressiveDelayService manages progressive delays
type ProgressiveDelayService struct {
	config        ProgressiveDelayConfig
	ipAttempts    map[string]*AttemptRecord
	emailAttempts map[string]*AttemptRecord
	mu            sync.RWMutex
	db            *gorm.DB
	auditService  *AuditService
}

// NewProgressiveDelayService creates a new service
func NewProgressiveDelayService(db *gorm.DB, auditService *AuditService, config ...ProgressiveDelayConfig) *ProgressiveDelayService {
	cfg := DefaultProgressiveDelayConfig()
	if len(config) > 0 {
		cfg = config[0]
	}

	service := &ProgressiveDelayService{
		config:        cfg,
		ipAttempts:    make(map[string]*AttemptRecord),
		emailAttempts: make(map[string]*AttemptRecord),
		db:            db,
		auditService:  auditService,
	}

	// Start cleanup goroutine
	go service.cleanupExpiredRecords()

	return service
}

// RecordFailedAttempt records a failed login attempt
func (s *ProgressiveDelayService) RecordFailedAttempt(email, ip string) (delay time.Duration, isLocked bool, lockUntil *time.Time) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	var maxDelay time.Duration

	// Track by email
	if s.config.EnableEmailTracking && email != "" {
		record := s.getOrCreateRecord(s.emailAttempts, email, now)
		d, locked, until := s.processAttempt(record, now)
		if d > maxDelay {
			maxDelay = d
		}
		if locked {
			isLocked = true
			lockUntil = until
		}
	}

	// Track by IP
	if s.config.EnableIPTracking && ip != "" {
		record := s.getOrCreateRecord(s.ipAttempts, ip, now)
		d, locked, until := s.processAttempt(record, now)
		if d > maxDelay {
			maxDelay = d
		}
		if locked {
			isLocked = true
			lockUntil = until
		}
	}

	return maxDelay, isLocked, lockUntil
}

// getOrCreateRecord gets or creates an attempt record
func (s *ProgressiveDelayService) getOrCreateRecord(records map[string]*AttemptRecord, key string, now time.Time) *AttemptRecord {
	record, exists := records[key]
	if !exists {
		record = &AttemptRecord{
			FirstAttempt: now,
		}
		records[key] = record
	}

	// Reset if too old
	if now.Sub(record.LastAttempt) > s.config.ResetAfter {
		record.Attempts = 0
		record.FirstAttempt = now
		record.LockedUntil = nil
		record.CurrentDelay = 0
	}

	return record
}

// processAttempt processes a failed attempt
func (s *ProgressiveDelayService) processAttempt(record *AttemptRecord, now time.Time) (delay time.Duration, isLocked bool, lockUntil *time.Time) {
	// Check if currently locked
	if record.LockedUntil != nil && now.Before(*record.LockedUntil) {
		return 0, true, record.LockedUntil
	}

	// Clear lockout if expired
	if record.LockedUntil != nil && now.After(*record.LockedUntil) {
		record.LockedUntil = nil
		record.Attempts = 0
	}

	// Increment attempts
	record.Attempts++
	record.LastAttempt = now

	// Check for lockout
	if record.Attempts >= s.config.LockoutThreshold {
		lockTime := now.Add(s.config.LockoutDuration)
		record.LockedUntil = &lockTime
		return 0, true, &lockTime
	}

	// Calculate exponential delay
	// delay = baseDelay * (multiplier ^ (attempts - 1))
	exponent := float64(record.Attempts - 1)
	delaySeconds := s.config.BaseDelaySeconds * math.Pow(s.config.DelayMultiplier, exponent)

	// Cap at max delay
	if delaySeconds > s.config.MaxDelaySeconds {
		delaySeconds = s.config.MaxDelaySeconds
	}

	delay = time.Duration(delaySeconds * float64(time.Second))
	record.CurrentDelay = delay

	return delay, false, nil
}

// RecordSuccessfulLogin resets the counters for successful login
func (s *ProgressiveDelayService) RecordSuccessfulLogin(email, ip string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	if email != "" {
		delete(s.emailAttempts, email)
	}
	if ip != "" {
		delete(s.ipAttempts, ip)
	}
}

// CheckIfLocked checks if email or IP is locked
func (s *ProgressiveDelayService) CheckIfLocked(email, ip string) (isLocked bool, lockUntil *time.Time, remainingDelay time.Duration) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	now := time.Now()

	// Check email lockout
	if record, exists := s.emailAttempts[email]; exists {
		if record.LockedUntil != nil && now.Before(*record.LockedUntil) {
			return true, record.LockedUntil, 0
		}
		if record.CurrentDelay > 0 {
			timeSinceAttempt := now.Sub(record.LastAttempt)
			if timeSinceAttempt < record.CurrentDelay {
				remainingDelay = record.CurrentDelay - timeSinceAttempt
			}
		}
	}

	// Check IP lockout
	if record, exists := s.ipAttempts[ip]; exists {
		if record.LockedUntil != nil && now.Before(*record.LockedUntil) {
			return true, record.LockedUntil, 0
		}
		if record.CurrentDelay > 0 {
			timeSinceAttempt := now.Sub(record.LastAttempt)
			if timeSinceAttempt < record.CurrentDelay {
				d := record.CurrentDelay - timeSinceAttempt
				if d > remainingDelay {
					remainingDelay = d
				}
			}
		}
	}

	return false, nil, remainingDelay
}

// GetAttemptStats returns statistics for an email/IP
func (s *ProgressiveDelayService) GetAttemptStats(email, ip string) map[string]interface{} {
	s.mu.RLock()
	defer s.mu.RUnlock()

	stats := map[string]interface{}{}

	if record, exists := s.emailAttempts[email]; exists {
		stats["email_attempts"] = record.Attempts
		stats["email_locked"] = record.LockedUntil != nil && time.Now().Before(*record.LockedUntil)
	}

	if record, exists := s.ipAttempts[ip]; exists {
		stats["ip_attempts"] = record.Attempts
		stats["ip_locked"] = record.LockedUntil != nil && time.Now().Before(*record.LockedUntil)
	}

	return stats
}

// cleanupExpiredRecords periodically cleans up expired records
func (s *ProgressiveDelayService) cleanupExpiredRecords() {
	ticker := time.NewTicker(5 * time.Minute)
	for range ticker.C {
		s.mu.Lock()
		now := time.Now()

		// Cleanup email records
		for key, record := range s.emailAttempts {
			if now.Sub(record.LastAttempt) > s.config.ResetAfter {
				delete(s.emailAttempts, key)
			}
		}

		// Cleanup IP records
		for key, record := range s.ipAttempts {
			if now.Sub(record.LastAttempt) > s.config.ResetAfter {
				delete(s.ipAttempts, key)
			}
		}

		s.mu.Unlock()
	}
}

// ============================================
// SESSION MANAGEMENT SERVICE
// Minggu 7: Session Management
// ============================================

// SessionInfo represents an active session
type SessionInfo struct {
	ID           string    `json:"id"`
	UserID       string    `json:"user_id"`
	DeviceInfo   string    `json:"device_info"`
	IPAddress    string    `json:"ip_address"`
	UserAgent    string    `json:"user_agent"`
	Location     string    `json:"location,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
	LastActivity time.Time `json:"last_activity"`
	ExpiresAt    time.Time `json:"expires_at"`
	IsCurrent    bool      `json:"is_current,omitempty"`
}

// ActiveSession database model
type ActiveSession struct {
	ID           string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID       string    `gorm:"type:varchar(36);index" json:"user_id"`
	TokenHash    string    `gorm:"type:varchar(64);uniqueIndex" json:"-"` // SHA-256 of token
	DeviceInfo   string    `gorm:"type:varchar(255)" json:"device_info"`
	IPAddress    string    `gorm:"type:varchar(45)" json:"ip_address"`
	UserAgent    string    `gorm:"type:text" json:"user_agent"`
	Location     string    `gorm:"type:varchar(255)" json:"location,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
	LastActivity time.Time `json:"last_activity"`
	ExpiresAt    time.Time `json:"expires_at"`
}

// SessionManagementService manages user sessions
type SessionManagementService struct {
	db             *gorm.DB
	auditService   *AuditService
	mu             sync.RWMutex
	activeSessions map[string][]SessionInfo // userID -> sessions
	maxSessions    int
}

// NewSessionManagementService creates a new session management service
func NewSessionManagementService(db *gorm.DB, auditService *AuditService, maxSessions int) *SessionManagementService {
	if maxSessions <= 0 {
		maxSessions = 5 // Default max 5 sessions per user
	}

	service := &SessionManagementService{
		db:             db,
		auditService:   auditService,
		activeSessions: make(map[string][]SessionInfo),
		maxSessions:    maxSessions,
	}

	// Auto-migrate
	db.AutoMigrate(&ActiveSession{})

	// Start cleanup goroutine
	go service.cleanupExpiredSessions()

	return service
}

// CreateSession creates a new session
func (s *SessionManagementService) CreateSession(userID, tokenHash, deviceInfo, ipAddress, userAgent string, ttl time.Duration) (*SessionInfo, error) {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	sessionID := generateSessionID()

	session := ActiveSession{
		ID:           sessionID,
		UserID:       userID,
		TokenHash:    tokenHash,
		DeviceInfo:   deviceInfo,
		IPAddress:    ipAddress,
		UserAgent:    userAgent,
		CreatedAt:    now,
		LastActivity: now,
		ExpiresAt:    now.Add(ttl),
	}

	// Check session limit
	var count int64
	s.db.Model(&ActiveSession{}).Where("user_id = ?", userID).Count(&count)

	if int(count) >= s.maxSessions {
		// Remove oldest session
		var oldest ActiveSession
		s.db.Where("user_id = ?", userID).Order("created_at ASC").First(&oldest)
		s.db.Delete(&oldest)
	}

	// Save new session
	if err := s.db.Create(&session).Error; err != nil {
		return nil, err
	}

	// Log session creation
	if s.auditService != nil {
		details := map[string]interface{}{
			"session_id":  sessionID,
			"device_info": deviceInfo,
			"ip_address":  ipAddress,
		}
		detailsJSON, _ := json.Marshal(details)
		s.auditService.LogSecurityEvent(
			models.SecurityEventType("SESSION_CREATED"),
			models.SeverityInfo,
			&userID,
			ipAddress,
			string(detailsJSON),
			userAgent,
		)
	}

	return &SessionInfo{
		ID:           session.ID,
		UserID:       session.UserID,
		DeviceInfo:   session.DeviceInfo,
		IPAddress:    session.IPAddress,
		UserAgent:    session.UserAgent,
		CreatedAt:    session.CreatedAt,
		LastActivity: session.LastActivity,
		ExpiresAt:    session.ExpiresAt,
	}, nil
}

// GetUserSessions returns all sessions for a user
func (s *SessionManagementService) GetUserSessions(userID string, currentTokenHash string) ([]SessionInfo, error) {
	var sessions []ActiveSession
	if err := s.db.Where("user_id = ? AND expires_at > ?", userID, time.Now()).
		Order("last_activity DESC").
		Find(&sessions).Error; err != nil {
		return nil, err
	}

	result := make([]SessionInfo, len(sessions))
	for i, sess := range sessions {
		result[i] = SessionInfo{
			ID:           sess.ID,
			UserID:       sess.UserID,
			DeviceInfo:   sess.DeviceInfo,
			IPAddress:    sess.IPAddress,
			UserAgent:    sess.UserAgent,
			Location:     sess.Location,
			CreatedAt:    sess.CreatedAt,
			LastActivity: sess.LastActivity,
			ExpiresAt:    sess.ExpiresAt,
			IsCurrent:    sess.TokenHash == currentTokenHash,
		}
	}

	return result, nil
}

// InvalidateSession invalidates a specific session
func (s *SessionManagementService) InvalidateSession(userID, sessionID string) error {
	return s.db.Where("id = ? AND user_id = ?", sessionID, userID).Delete(&ActiveSession{}).Error
}

// InvalidateAllSessions invalidates all sessions for a user
func (s *SessionManagementService) InvalidateAllSessions(userID string, exceptTokenHash string) error {
	query := s.db.Where("user_id = ?", userID)
	if exceptTokenHash != "" {
		query = query.Where("token_hash != ?", exceptTokenHash)
	}
	return query.Delete(&ActiveSession{}).Error
}

// ValidateSession validates a session by token hash
func (s *SessionManagementService) ValidateSession(tokenHash string) (*ActiveSession, error) {
	var session ActiveSession
	if err := s.db.Where("token_hash = ? AND expires_at > ?", tokenHash, time.Now()).
		First(&session).Error; err != nil {
		return nil, err
	}

	// Update last activity
	s.db.Model(&session).Update("last_activity", time.Now())

	return &session, nil
}

// RefreshSession extends session expiry
func (s *SessionManagementService) RefreshSession(tokenHash string, ttl time.Duration) error {
	return s.db.Model(&ActiveSession{}).
		Where("token_hash = ?", tokenHash).
		Updates(map[string]interface{}{
			"last_activity": time.Now(),
			"expires_at":    time.Now().Add(ttl),
		}).Error
}

// cleanupExpiredSessions periodically cleans up expired sessions
func (s *SessionManagementService) cleanupExpiredSessions() {
	ticker := time.NewTicker(1 * time.Hour)
	for range ticker.C {
		s.db.Where("expires_at < ?", time.Now()).Delete(&ActiveSession{})
	}
}

// generateSessionID generates a random session ID
func generateSessionID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)
}

// ============================================
// DEVICE FINGERPRINTING
// ============================================

// DeviceFingerprint represents a device fingerprint
type DeviceFingerprint struct {
	UserAgent  string `json:"user_agent"`
	AcceptLang string `json:"accept_lang"`
	Platform   string `json:"platform"`
	Timezone   string `json:"timezone"`
	ScreenRes  string `json:"screen_res"`
	ColorDepth string `json:"color_depth"`
}

// ParseDeviceInfo extracts device info from user agent
func ParseDeviceInfo(userAgent string) string {
	// Simple device detection
	ua := userAgent

	switch {
	case containsStr(ua, "iPhone"):
		return "iPhone"
	case containsStr(ua, "iPad"):
		return "iPad"
	case containsStr(ua, "Android"):
		if containsStr(ua, "Mobile") {
			return "Android Phone"
		}
		return "Android Tablet"
	case containsStr(ua, "Windows"):
		return "Windows PC"
	case containsStr(ua, "Macintosh"):
		return "Mac"
	case containsStr(ua, "Linux"):
		return "Linux PC"
	default:
		return "Unknown Device"
	}
}
