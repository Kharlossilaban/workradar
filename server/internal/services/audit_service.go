package services

import (
	"encoding/json"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/workradar/server/internal/database"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
)

// AuditService handles audit logging and security event management
type AuditService struct {
	auditRepo *repository.AuditRepository
}

var (
	auditServiceInstance *AuditService
	auditServiceOnce     sync.Once
)

// GetAuditService returns singleton audit service
func GetAuditService() *AuditService {
	auditServiceOnce.Do(func() {
		auditRepo := repository.NewAuditRepository(database.DB)
		auditServiceInstance = &AuditService{
			auditRepo: auditRepo,
		}
	})
	return auditServiceInstance
}

// NewAuditService creates a new audit service
func NewAuditService(auditRepo *repository.AuditRepository) *AuditService {
	return &AuditService{
		auditRepo: auditRepo,
	}
}

// ==================== AUDIT LOGGING ====================

// LogCreate logs a CREATE operation
func (s *AuditService) LogCreate(userID *string, tableName, recordID string, newValue interface{}, ip, userAgent, path string, statusCode int, duration int64) {
	newValueJSON := s.toJSON(newValue)

	audit := &models.AuditLog{
		UserID:      userID,
		Action:      models.AuditActionCreate,
		TableName:   tableName,
		RecordID:    &recordID,
		NewValue:    newValueJSON,
		IPAddress:   ip,
		UserAgent:   userAgent,
		RequestPath: path,
		StatusCode:  statusCode,
		Duration:    duration,
		CreatedAt:   time.Now(),
	}

	if err := s.auditRepo.CreateAuditLog(audit); err != nil {
		log.Printf("❌ Failed to create audit log (CREATE): %v", err)
	}
}

// LogUpdate logs an UPDATE operation
func (s *AuditService) LogUpdate(userID *string, tableName, recordID string, oldValue, newValue interface{}, ip, userAgent, path string, statusCode int, duration int64) {
	oldValueJSON := s.toJSON(oldValue)
	newValueJSON := s.toJSON(newValue)

	audit := &models.AuditLog{
		UserID:      userID,
		Action:      models.AuditActionUpdate,
		TableName:   tableName,
		RecordID:    &recordID,
		OldValue:    oldValueJSON,
		NewValue:    newValueJSON,
		IPAddress:   ip,
		UserAgent:   userAgent,
		RequestPath: path,
		StatusCode:  statusCode,
		Duration:    duration,
		CreatedAt:   time.Now(),
	}

	if err := s.auditRepo.CreateAuditLog(audit); err != nil {
		log.Printf("❌ Failed to create audit log (UPDATE): %v", err)
	}
}

// LogDelete logs a DELETE operation
func (s *AuditService) LogDelete(userID *string, tableName, recordID string, oldValue interface{}, ip, userAgent, path string, statusCode int, duration int64) {
	oldValueJSON := s.toJSON(oldValue)

	audit := &models.AuditLog{
		UserID:      userID,
		Action:      models.AuditActionDelete,
		TableName:   tableName,
		RecordID:    &recordID,
		OldValue:    oldValueJSON,
		IPAddress:   ip,
		UserAgent:   userAgent,
		RequestPath: path,
		StatusCode:  statusCode,
		Duration:    duration,
		CreatedAt:   time.Now(),
	}

	if err := s.auditRepo.CreateAuditLog(audit); err != nil {
		log.Printf("❌ Failed to create audit log (DELETE): %v", err)
	}
}

// LogRead logs a READ/ACCESS operation (untuk data sensitif)
func (s *AuditService) LogRead(userID *string, tableName, recordID string, ip, userAgent, path string, statusCode int, duration int64) {
	audit := &models.AuditLog{
		UserID:      userID,
		Action:      models.AuditActionRead,
		TableName:   tableName,
		RecordID:    &recordID,
		IPAddress:   ip,
		UserAgent:   userAgent,
		RequestPath: path,
		StatusCode:  statusCode,
		Duration:    duration,
		CreatedAt:   time.Now(),
	}

	if err := s.auditRepo.CreateAuditLog(audit); err != nil {
		log.Printf("❌ Failed to create audit log (READ): %v", err)
	}
}

// LogLogin logs a LOGIN operation
func (s *AuditService) LogLogin(userID *string, success bool, ip, userAgent, path string, statusCode int, duration int64) {
	action := models.AuditActionLogin

	audit := &models.AuditLog{
		UserID:      userID,
		Action:      action,
		TableName:   "users",
		IPAddress:   ip,
		UserAgent:   userAgent,
		RequestPath: path,
		StatusCode:  statusCode,
		Duration:    duration,
		CreatedAt:   time.Now(),
	}

	if err := s.auditRepo.CreateAuditLog(audit); err != nil {
		log.Printf("❌ Failed to create audit log (LOGIN): %v", err)
	}
}

// LogLogout logs a LOGOUT operation
func (s *AuditService) LogLogout(userID string, ip, userAgent, path string) {
	audit := &models.AuditLog{
		UserID:      &userID,
		Action:      models.AuditActionLogout,
		TableName:   "users",
		IPAddress:   ip,
		UserAgent:   userAgent,
		RequestPath: path,
		StatusCode:  200,
		Duration:    0,
		CreatedAt:   time.Now(),
	}

	if err := s.auditRepo.CreateAuditLog(audit); err != nil {
		log.Printf("❌ Failed to create audit log (LOGOUT): %v", err)
	}
}

// ==================== SECURITY EVENTS ====================

// LogSecurityEvent logs a security event
func (s *AuditService) LogSecurityEvent(eventType models.SecurityEventType, severity models.SecurityEventSeverity, userID *string, ip, details, userAgent string) {
	event := &models.SecurityEvent{
		EventType: eventType,
		Severity:  severity,
		UserID:    userID,
		IPAddress: ip,
		Details:   details,
		UserAgent: userAgent,
		CreatedAt: time.Now(),
	}

	if err := s.auditRepo.CreateSecurityEvent(event); err != nil {
		log.Printf("❌ Failed to create security event: %v", err)
	}

	// Log to console for critical events
	if severity == models.SeverityCritical || severity == models.SeverityHigh {
		log.Printf("🚨 SECURITY EVENT [%s] %s: %s (IP: %s)", severity, eventType, details, ip)
	}
}

// LogFailedLogin logs a failed login attempt
func (s *AuditService) LogFailedLogin(email, ip, userAgent, reason string) {
	// Create login attempt record
	attempt := &models.LoginAttempt{
		Email:      email,
		IPAddress:  ip,
		Success:    false,
		UserAgent:  userAgent,
		FailReason: &reason,
		CreatedAt:  time.Now(),
	}

	if err := s.auditRepo.CreateLoginAttempt(attempt); err != nil {
		log.Printf("❌ Failed to create login attempt record: %v", err)
	}

	// Log security event
	s.LogSecurityEvent(
		models.EventFailedLogin,
		models.SeverityWarning,
		nil,
		ip,
		fmt.Sprintf("Failed login attempt for email: %s. Reason: %s", email, reason),
		userAgent,
	)
}

// LogSuccessLogin logs a successful login
func (s *AuditService) LogSuccessLogin(userID, email, ip, userAgent string) {
	// Create login attempt record
	attempt := &models.LoginAttempt{
		Email:     email,
		IPAddress: ip,
		Success:   true,
		UserAgent: userAgent,
		CreatedAt: time.Now(),
	}

	if err := s.auditRepo.CreateLoginAttempt(attempt); err != nil {
		log.Printf("❌ Failed to create login attempt record: %v", err)
	}

	// Log security event
	s.LogSecurityEvent(
		models.EventSuccessLogin,
		models.SeverityInfo,
		&userID,
		ip,
		fmt.Sprintf("Successful login for user: %s", email),
		userAgent,
	)
}

// ==================== THREAT DETECTION ====================

// CheckBruteForce checks for brute force attack patterns
func (s *AuditService) CheckBruteForce(ip string, maxAttempts int, windowMinutes int) (bool, int64, error) {
	since := time.Now().Add(-time.Duration(windowMinutes) * time.Minute)
	count, err := s.auditRepo.CountFailedLoginAttemptsByIP(ip, since)
	if err != nil {
		return false, 0, err
	}

	isBruteForce := count >= int64(maxAttempts)

	if isBruteForce {
		s.LogSecurityEvent(
			models.EventBruteForceDetected,
			models.SeverityCritical,
			nil,
			ip,
			fmt.Sprintf("Brute force attack detected: %d failed attempts in %d minutes", count, windowMinutes),
			"",
		)
	}

	return isBruteForce, count, nil
}

// CheckAccountBruteForce checks for brute force on a specific account
func (s *AuditService) CheckAccountBruteForce(email string, maxAttempts int, windowMinutes int) (bool, int64, error) {
	since := time.Now().Add(-time.Duration(windowMinutes) * time.Minute)
	count, err := s.auditRepo.CountFailedLoginAttemptsByEmail(email, since)
	if err != nil {
		return false, 0, err
	}

	return count >= int64(maxAttempts), count, nil
}

// BlockIP blocks an IP address temporarily
func (s *AuditService) BlockIP(ip, reason string, durationMinutes int) error {
	blocked := &models.BlockedIP{
		IPAddress:    ip,
		Reason:       reason,
		BlockedAt:    time.Now(),
		BlockedUntil: time.Now().Add(time.Duration(durationMinutes) * time.Minute),
		AttemptCount: 1,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	// Check if already blocked
	existing, err := s.auditRepo.GetBlockedIP(ip)
	if err == nil && existing != nil {
		// Extend block time and increment count
		existing.BlockedUntil = time.Now().Add(time.Duration(durationMinutes) * time.Minute)
		existing.AttemptCount++
		existing.UpdatedAt = time.Now()
		return s.auditRepo.UpdateBlockedIP(existing)
	}

	err = s.auditRepo.CreateBlockedIP(blocked)
	if err != nil {
		return err
	}

	// Log security event
	s.LogSecurityEvent(
		models.EventIPBlocked,
		models.SeverityHigh,
		nil,
		ip,
		fmt.Sprintf("IP blocked for %d minutes. Reason: %s", durationMinutes, reason),
		"",
	)

	log.Printf("🚫 IP BLOCKED: %s for %d minutes. Reason: %s", ip, durationMinutes, reason)
	return nil
}

// IsIPBlocked checks if an IP is currently blocked
func (s *AuditService) IsIPBlocked(ip string) (bool, error) {
	return s.auditRepo.IsIPBlocked(ip)
}

// UnblockIP removes an IP from the blocklist
func (s *AuditService) UnblockIP(ip string) error {
	err := s.auditRepo.UnblockIP(ip)
	if err != nil {
		return err
	}

	// Log security event
	s.LogSecurityEvent(
		models.EventIPUnblocked,
		models.SeverityInfo,
		nil,
		ip,
		"IP unblocked",
		"",
	)

	return nil
}

// ==================== PASSWORD HISTORY ====================

// AddPasswordToHistory adds a password hash to user's history
func (s *AuditService) AddPasswordToHistory(userID, passwordHash string) error {
	history := &models.PasswordHistory{
		UserID:       userID,
		PasswordHash: passwordHash,
		CreatedAt:    time.Now(),
	}

	err := s.auditRepo.CreatePasswordHistory(history)
	if err != nil {
		return err
	}

	// Cleanup old entries (keep last 3)
	return s.auditRepo.CleanupOldPasswordHistory(userID, 3)
}

// IsPasswordInHistory checks if password was used recently
func (s *AuditService) IsPasswordInHistory(userID, passwordHash string, checkCount int) (bool, error) {
	history, err := s.auditRepo.GetPasswordHistory(userID, checkCount)
	if err != nil {
		return false, err
	}

	for _, h := range history {
		if h.PasswordHash == passwordHash {
			return true, nil
		}
	}

	return false, nil
}

// ==================== HELPER FUNCTIONS ====================

func (s *AuditService) toJSON(data interface{}) *string {
	if data == nil {
		return nil
	}

	// Sanitize sensitive data before logging
	sanitized := s.sanitizeForAudit(data)

	bytes, err := json.Marshal(sanitized)
	if err != nil {
		return nil
	}
	str := string(bytes)
	return &str
}

func (s *AuditService) sanitizeForAudit(data interface{}) interface{} {
	// Convert to map if possible
	switch v := data.(type) {
	case map[string]interface{}:
		return s.sanitizeMap(v)
	default:
		// For struct types, marshal and unmarshal to map
		bytes, err := json.Marshal(data)
		if err != nil {
			return data
		}
		var m map[string]interface{}
		if err := json.Unmarshal(bytes, &m); err != nil {
			return data
		}
		return s.sanitizeMap(m)
	}
}

func (s *AuditService) sanitizeMap(m map[string]interface{}) map[string]interface{} {
	sensitiveKeys := []string{
		"password", "password_hash", "secret", "token",
		"api_key", "credit_card", "cvv", "ssn",
		"fcm_token", "mfa_secret",
	}

	result := make(map[string]interface{})
	for k, v := range m {
		// Check if key is sensitive
		isSensitive := false
		keyLower := toLowerString(k)
		for _, sensitive := range sensitiveKeys {
			if containsStr(keyLower, sensitive) {
				isSensitive = true
				break
			}
		}

		if isSensitive {
			result[k] = "***REDACTED***"
		} else {
			result[k] = v
		}
	}
	return result
}

func toLowerString(s string) string {
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

func containsStr(s, substr string) bool {
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

// ==================== REPORTING & ANALYTICS ====================

// GetAuditLogsByUser gets audit logs for a user
func (s *AuditService) GetAuditLogsByUser(userID string, limit, offset int) ([]models.AuditLog, error) {
	return s.auditRepo.GetAuditLogsByUserID(userID, limit, offset)
}

// GetSecurityEventsBySeverity gets security events by severity
func (s *AuditService) GetSecurityEventsBySeverity(severity models.SecurityEventSeverity, limit, offset int) ([]models.SecurityEvent, error) {
	return s.auditRepo.GetSecurityEventsBySeverity(severity, limit, offset)
}

// GetUnresolvedSecurityEvents gets all unresolved security events
func (s *AuditService) GetUnresolvedSecurityEvents(limit, offset int) ([]models.SecurityEvent, error) {
	return s.auditRepo.GetUnresolvedSecurityEvents(limit, offset)
}

// ResolveSecurityEvent marks a security event as resolved
func (s *AuditService) ResolveSecurityEvent(eventID, resolvedBy string) error {
	return s.auditRepo.ResolveSecurityEvent(eventID, resolvedBy)
}

// GetBlockedIPs gets all currently blocked IPs
func (s *AuditService) GetBlockedIPs() ([]models.BlockedIP, error) {
	return s.auditRepo.GetAllBlockedIPs()
}

// CleanupExpiredBlocks removes expired IP blocks
func (s *AuditService) CleanupExpiredBlocks() error {
	return s.auditRepo.CleanupExpiredBlocks()
}
