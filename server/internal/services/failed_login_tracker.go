package services

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"sync"
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

// ============================================
// FAILED LOGIN TRACKING SERVICE
// Minggu 10: Brute Force Prevention & Security Monitoring
// ============================================

// FailedLoginAttempt represents a failed login record
type FailedLoginAttempt struct {
	ID          string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	Email       string    `gorm:"type:varchar(255);index" json:"email"`
	IPAddress   string    `gorm:"type:varchar(45);index" json:"ip_address"`
	UserAgent   string    `gorm:"type:text" json:"user_agent"`
	Reason      string    `gorm:"type:varchar(100)" json:"reason"` // wrong_password, account_locked, etc.
	AttemptedAt time.Time `gorm:"index" json:"attempted_at"`
}

// FailedLoginStats provides statistics
type FailedLoginStats struct {
	TotalAttempts      int64                `json:"total_attempts"`
	Last24Hours        int64                `json:"last_24_hours"`
	LastHour           int64                `json:"last_hour"`
	UniqueIPs          int64                `json:"unique_ips"`
	UniqueEmails       int64                `json:"unique_emails"`
	TopAttackedEmails  []EmailAttackStats   `json:"top_attacked_emails"`
	TopAttackerIPs     []IPAttackStats      `json:"top_attacker_ips"`
	HourlyDistribution map[int]int64        `json:"hourly_distribution"`
	RecentAttempts     []FailedLoginAttempt `json:"recent_attempts"`
}

// EmailAttackStats stats per email
type EmailAttackStats struct {
	Email    string `json:"email"`
	Attempts int64  `json:"attempts"`
}

// IPAttackStats stats per IP
type IPAttackStats struct {
	IPAddress string `json:"ip_address"`
	Attempts  int64  `json:"attempts"`
}

// FailedLoginTracker tracks failed login attempts
type FailedLoginTracker struct {
	db           *gorm.DB
	auditService *AuditService
	alertService *SecurityAlertService
	mu           sync.RWMutex
	recentCache  []FailedLoginAttempt
	cacheLimit   int
}

// NewFailedLoginTracker creates a new tracker
func NewFailedLoginTracker(db *gorm.DB, auditService *AuditService, alertService *SecurityAlertService) *FailedLoginTracker {
	tracker := &FailedLoginTracker{
		db:           db,
		auditService: auditService,
		alertService: alertService,
		recentCache:  make([]FailedLoginAttempt, 0),
		cacheLimit:   100,
	}

	// Auto-migrate
	db.AutoMigrate(&FailedLoginAttempt{})

	// Start monitoring goroutine
	go tracker.monitorAttackPatterns()

	return tracker
}

// RecordFailedLogin records a failed login attempt
func (t *FailedLoginTracker) RecordFailedLogin(email, ip, userAgent, reason string) error {
	t.mu.Lock()
	defer t.mu.Unlock()

	attempt := FailedLoginAttempt{
		ID:          generateUUID(),
		Email:       email,
		IPAddress:   ip,
		UserAgent:   userAgent,
		Reason:      reason,
		AttemptedAt: time.Now(),
	}

	// Save to database
	if err := t.db.Create(&attempt).Error; err != nil {
		return err
	}

	// Update cache
	t.recentCache = append(t.recentCache, attempt)
	if len(t.recentCache) > t.cacheLimit {
		t.recentCache = t.recentCache[1:]
	}

	// Check for attack patterns
	go t.checkAttackPattern(email, ip)

	return nil
}

// checkAttackPattern checks for potential attack
func (t *FailedLoginTracker) checkAttackPattern(email, ip string) {
	// Count recent attempts from same IP
	var ipCount int64
	oneMinuteAgo := time.Now().Add(-1 * time.Minute)
	t.db.Model(&FailedLoginAttempt{}).
		Where("ip_address = ? AND attempted_at > ?", ip, oneMinuteAgo).
		Count(&ipCount)

	// Alert if more than 10 attempts per minute from same IP
	if ipCount >= 10 && t.alertService != nil {
		t.alertService.SendAlert(SecurityAlert{
			Type:     AlertTypeBruteForce,
			Severity: AlertSeverityHigh,
			Title:    "Brute Force Attack Detected",
			Message:  "Multiple failed login attempts from IP: " + ip,
			Data: map[string]interface{}{
				"ip_address":   ip,
				"attempts":     ipCount,
				"time_window":  "1 minute",
				"target_email": email,
			},
		})
	}

	// Count recent attempts for same email
	var emailCount int64
	fiveMinutesAgo := time.Now().Add(-5 * time.Minute)
	t.db.Model(&FailedLoginAttempt{}).
		Where("email = ? AND attempted_at > ?", email, fiveMinutesAgo).
		Count(&emailCount)

	// Alert if more than 5 attempts in 5 minutes for same email
	if emailCount >= 5 && t.alertService != nil {
		t.alertService.SendAlert(SecurityAlert{
			Type:     AlertTypeAccountAttack,
			Severity: AlertSeverityMedium,
			Title:    "Account Under Attack",
			Message:  "Multiple failed login attempts for: " + maskEmail(email),
			Data: map[string]interface{}{
				"email":       maskEmail(email),
				"attempts":    emailCount,
				"time_window": "5 minutes",
			},
		})
	}
}

// GetStats returns failed login statistics
func (t *FailedLoginTracker) GetStats() (*FailedLoginStats, error) {
	stats := &FailedLoginStats{
		HourlyDistribution: make(map[int]int64),
	}

	now := time.Now()
	yesterday := now.Add(-24 * time.Hour)
	lastHour := now.Add(-1 * time.Hour)

	// Total attempts
	t.db.Model(&FailedLoginAttempt{}).Count(&stats.TotalAttempts)

	// Last 24 hours
	t.db.Model(&FailedLoginAttempt{}).
		Where("attempted_at > ?", yesterday).
		Count(&stats.Last24Hours)

	// Last hour
	t.db.Model(&FailedLoginAttempt{}).
		Where("attempted_at > ?", lastHour).
		Count(&stats.LastHour)

	// Unique IPs in last 24 hours
	t.db.Model(&FailedLoginAttempt{}).
		Where("attempted_at > ?", yesterday).
		Distinct("ip_address").
		Count(&stats.UniqueIPs)

	// Unique emails in last 24 hours
	t.db.Model(&FailedLoginAttempt{}).
		Where("attempted_at > ?", yesterday).
		Distinct("email").
		Count(&stats.UniqueEmails)

	// Top attacked emails
	var emailStats []struct {
		Email string
		Count int64
	}
	t.db.Model(&FailedLoginAttempt{}).
		Select("email, count(*) as count").
		Where("attempted_at > ?", yesterday).
		Group("email").
		Order("count DESC").
		Limit(10).
		Scan(&emailStats)

	stats.TopAttackedEmails = make([]EmailAttackStats, len(emailStats))
	for i, e := range emailStats {
		stats.TopAttackedEmails[i] = EmailAttackStats{
			Email:    maskEmail(e.Email),
			Attempts: e.Count,
		}
	}

	// Top attacker IPs
	var ipStats []struct {
		IPAddress string
		Count     int64
	}
	t.db.Model(&FailedLoginAttempt{}).
		Select("ip_address, count(*) as count").
		Where("attempted_at > ?", yesterday).
		Group("ip_address").
		Order("count DESC").
		Limit(10).
		Scan(&ipStats)

	stats.TopAttackerIPs = make([]IPAttackStats, len(ipStats))
	for i, ip := range ipStats {
		stats.TopAttackerIPs[i] = IPAttackStats{
			IPAddress: ip.IPAddress,
			Attempts:  ip.Count,
		}
	}

	// Hourly distribution
	var hourlyStats []struct {
		Hour  int
		Count int64
	}
	t.db.Model(&FailedLoginAttempt{}).
		Select("HOUR(attempted_at) as hour, count(*) as count").
		Where("attempted_at > ?", yesterday).
		Group("HOUR(attempted_at)").
		Scan(&hourlyStats)

	for _, h := range hourlyStats {
		stats.HourlyDistribution[h.Hour] = h.Count
	}

	// Recent attempts
	var recent []FailedLoginAttempt
	t.db.Where("attempted_at > ?", lastHour).
		Order("attempted_at DESC").
		Limit(20).
		Find(&recent)

	// Mask emails in recent attempts
	for i := range recent {
		recent[i].Email = maskEmail(recent[i].Email)
	}
	stats.RecentAttempts = recent

	return stats, nil
}

// GetAttemptsForEmail returns attempts for a specific email
func (t *FailedLoginTracker) GetAttemptsForEmail(email string, since time.Time) ([]FailedLoginAttempt, error) {
	var attempts []FailedLoginAttempt
	err := t.db.Where("email = ? AND attempted_at > ?", email, since).
		Order("attempted_at DESC").
		Find(&attempts).Error
	return attempts, err
}

// GetAttemptsForIP returns attempts for a specific IP
func (t *FailedLoginTracker) GetAttemptsForIP(ip string, since time.Time) ([]FailedLoginAttempt, error) {
	var attempts []FailedLoginAttempt
	err := t.db.Where("ip_address = ? AND attempted_at > ?", ip, since).
		Order("attempted_at DESC").
		Find(&attempts).Error
	return attempts, err
}

// CleanupOldRecords removes old records
func (t *FailedLoginTracker) CleanupOldRecords(olderThan time.Duration) error {
	cutoff := time.Now().Add(-olderThan)
	return t.db.Where("attempted_at < ?", cutoff).Delete(&FailedLoginAttempt{}).Error
}

// monitorAttackPatterns runs periodic monitoring
func (t *FailedLoginTracker) monitorAttackPatterns() {
	ticker := time.NewTicker(1 * time.Minute)
	for range ticker.C {
		t.analyzeRecentPatterns()
	}
}

// analyzeRecentPatterns analyzes recent attack patterns
func (t *FailedLoginTracker) analyzeRecentPatterns() {
	// This could be expanded with ML-based anomaly detection
	// For now, basic pattern detection

	oneMinuteAgo := time.Now().Add(-1 * time.Minute)

	// Check for distributed attack (many IPs, same email)
	var distributed []struct {
		Email   string
		IPCount int64
	}
	t.db.Model(&FailedLoginAttempt{}).
		Select("email, count(distinct ip_address) as ip_count").
		Where("attempted_at > ?", oneMinuteAgo).
		Group("email").
		Having("ip_count > 3").
		Scan(&distributed)

	for _, d := range distributed {
		if t.alertService != nil {
			t.alertService.SendAlert(SecurityAlert{
				Type:     AlertTypeDistributedAttack,
				Severity: AlertSeverityCritical,
				Title:    "Distributed Attack Detected",
				Message:  "Multiple IPs attacking same account",
				Data: map[string]interface{}{
					"email":    maskEmail(d.Email),
					"ip_count": d.IPCount,
				},
			})
		}
	}
}

// ============================================
// SECURITY ALERT SERVICE
// Minggu 10: Real-Time Security Alerts
// ============================================

// AlertType represents alert type
type AlertType string

const (
	AlertTypeBruteForce        AlertType = "BRUTE_FORCE"
	AlertTypeAccountAttack     AlertType = "ACCOUNT_ATTACK"
	AlertTypeDistributedAttack AlertType = "DISTRIBUTED_ATTACK"
	AlertTypeNewDevice         AlertType = "NEW_DEVICE"
	AlertTypeSuspiciousLogin   AlertType = "SUSPICIOUS_LOGIN"
	AlertTypeAccountLocked     AlertType = "ACCOUNT_LOCKED"
)

// AlertSeverity represents alert severity
type AlertSeverity string

const (
	AlertSeverityLow      AlertSeverity = "LOW"
	AlertSeverityMedium   AlertSeverity = "MEDIUM"
	AlertSeverityHigh     AlertSeverity = "HIGH"
	AlertSeverityCritical AlertSeverity = "CRITICAL"
)

// SecurityAlert represents a security alert
type SecurityAlert struct {
	ID        string                 `json:"id"`
	Type      AlertType              `json:"type"`
	Severity  AlertSeverity          `json:"severity"`
	Title     string                 `json:"title"`
	Message   string                 `json:"message"`
	Data      map[string]interface{} `json:"data,omitempty"`
	CreatedAt time.Time              `json:"created_at"`
	Handled   bool                   `json:"handled"`
}

// SecurityAlertService manages security alerts
type SecurityAlertService struct {
	db            *gorm.DB
	auditService  *AuditService
	alertHandlers []AlertHandler
	alertChan     chan SecurityAlert
	mu            sync.RWMutex
	recentAlerts  []SecurityAlert
}

// AlertHandler is a function that handles alerts
type AlertHandler func(alert SecurityAlert) error

// NewSecurityAlertService creates a new alert service
func NewSecurityAlertService(db *gorm.DB, auditService *AuditService) *SecurityAlertService {
	service := &SecurityAlertService{
		db:            db,
		auditService:  auditService,
		alertHandlers: make([]AlertHandler, 0),
		alertChan:     make(chan SecurityAlert, 100),
		recentAlerts:  make([]SecurityAlert, 0),
	}

	// Start alert processor
	go service.processAlerts()

	return service
}

// RegisterHandler registers an alert handler
func (s *SecurityAlertService) RegisterHandler(handler AlertHandler) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.alertHandlers = append(s.alertHandlers, handler)
}

// SendAlert sends a security alert
func (s *SecurityAlertService) SendAlert(alert SecurityAlert) {
	alert.ID = generateUUID()
	alert.CreatedAt = time.Now()

	// Non-blocking send
	select {
	case s.alertChan <- alert:
	default:
		// Channel full, log warning
	}
}

// processAlerts processes alerts in background
func (s *SecurityAlertService) processAlerts() {
	for alert := range s.alertChan {
		// Store in recent alerts
		s.mu.Lock()
		s.recentAlerts = append(s.recentAlerts, alert)
		if len(s.recentAlerts) > 100 {
			s.recentAlerts = s.recentAlerts[1:]
		}
		s.mu.Unlock()

		// Log to audit
		if s.auditService != nil {
			details, _ := json.Marshal(alert)
			s.auditService.LogSecurityEvent(
				models.SecurityEventType("SECURITY_ALERT"),
				models.SecurityEventSeverity(alert.Severity),
				nil,
				"",
				string(details),
				"",
			)
		}

		// Call handlers
		s.mu.RLock()
		handlers := s.alertHandlers
		s.mu.RUnlock()

		for _, handler := range handlers {
			go handler(alert)
		}
	}
}

// GetRecentAlerts returns recent alerts
func (s *SecurityAlertService) GetRecentAlerts(limit int) []SecurityAlert {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if limit <= 0 || limit > len(s.recentAlerts) {
		limit = len(s.recentAlerts)
	}

	// Return most recent first
	result := make([]SecurityAlert, limit)
	for i := 0; i < limit; i++ {
		result[i] = s.recentAlerts[len(s.recentAlerts)-1-i]
	}
	return result
}

// ============================================
// HELPER FUNCTIONS
// ============================================

// maskEmail masks email for display
func maskEmail(email string) string {
	if len(email) < 5 {
		return "***"
	}

	atIndex := -1
	for i, c := range email {
		if c == '@' {
			atIndex = i
			break
		}
	}

	if atIndex < 0 || atIndex < 3 {
		return email[:3] + "***"
	}

	return email[:3] + "***" + email[atIndex:]
}

// generateUUID generates a simple UUID
func generateUUID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b[:4]) + "-" + hex.EncodeToString(b[4:6]) + "-" + hex.EncodeToString(b[6:8]) + "-" + hex.EncodeToString(b[8:10]) + "-" + hex.EncodeToString(b[10:])
}
