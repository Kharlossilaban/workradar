package repository

import (
	"time"

	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

// AuditRepository handles audit log database operations
type AuditRepository struct {
	db *gorm.DB
}

// NewAuditRepository creates a new audit repository
func NewAuditRepository(db *gorm.DB) *AuditRepository {
	return &AuditRepository{db: db}
}

// ==================== AUDIT LOG OPERATIONS ====================

// CreateAuditLog creates a new audit log entry
func (r *AuditRepository) CreateAuditLog(log *models.AuditLog) error {
	return r.db.Create(log).Error
}

// GetAuditLogsByUserID gets audit logs for a specific user
func (r *AuditRepository) GetAuditLogsByUserID(userID string, limit, offset int) ([]models.AuditLog, error) {
	var logs []models.AuditLog
	err := r.db.Where("user_id = ?", userID).
		Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&logs).Error
	return logs, err
}

// GetAuditLogsByTable gets audit logs for a specific table
func (r *AuditRepository) GetAuditLogsByTable(tableName string, limit, offset int) ([]models.AuditLog, error) {
	var logs []models.AuditLog
	err := r.db.Where("table_name = ?", tableName).
		Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&logs).Error
	return logs, err
}

// GetAuditLogsByDateRange gets audit logs within a date range
func (r *AuditRepository) GetAuditLogsByDateRange(start, end time.Time, limit, offset int) ([]models.AuditLog, error) {
	var logs []models.AuditLog
	err := r.db.Where("created_at BETWEEN ? AND ?", start, end).
		Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&logs).Error
	return logs, err
}

// GetAuditLogsByIP gets audit logs for a specific IP address
func (r *AuditRepository) GetAuditLogsByIP(ipAddress string, limit, offset int) ([]models.AuditLog, error) {
	var logs []models.AuditLog
	err := r.db.Where("ip_address = ?", ipAddress).
		Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&logs).Error
	return logs, err
}

// ==================== SECURITY EVENT OPERATIONS ====================

// CreateSecurityEvent creates a new security event
func (r *AuditRepository) CreateSecurityEvent(event *models.SecurityEvent) error {
	return r.db.Create(event).Error
}

// GetSecurityEventsBySeverity gets security events by severity level
func (r *AuditRepository) GetSecurityEventsBySeverity(severity models.SecurityEventSeverity, limit, offset int) ([]models.SecurityEvent, error) {
	var events []models.SecurityEvent
	err := r.db.Where("severity = ?", severity).
		Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&events).Error
	return events, err
}

// GetUnresolvedSecurityEvents gets all unresolved security events
func (r *AuditRepository) GetUnresolvedSecurityEvents(limit, offset int) ([]models.SecurityEvent, error) {
	var events []models.SecurityEvent
	err := r.db.Where("resolved = ?", false).
		Order("FIELD(severity, 'CRITICAL', 'HIGH', 'WARNING', 'INFO')").
		Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&events).Error
	return events, err
}

// GetSecurityEventsByType gets security events by type
func (r *AuditRepository) GetSecurityEventsByType(eventType models.SecurityEventType, limit, offset int) ([]models.SecurityEvent, error) {
	var events []models.SecurityEvent
	err := r.db.Where("event_type = ?", eventType).
		Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&events).Error
	return events, err
}

// GetSecurityEventsByIP gets security events for a specific IP
func (r *AuditRepository) GetSecurityEventsByIP(ipAddress string, limit, offset int) ([]models.SecurityEvent, error) {
	var events []models.SecurityEvent
	err := r.db.Where("ip_address = ?", ipAddress).
		Order("created_at DESC").
		Limit(limit).Offset(offset).
		Find(&events).Error
	return events, err
}

// ResolveSecurityEvent marks a security event as resolved
func (r *AuditRepository) ResolveSecurityEvent(eventID, resolvedBy string) error {
	now := time.Now()
	return r.db.Model(&models.SecurityEvent{}).
		Where("id = ?", eventID).
		Updates(map[string]interface{}{
			"resolved":    true,
			"resolved_at": now,
			"resolved_by": resolvedBy,
		}).Error
}

// CountSecurityEventsByTypeAndTime counts events of a type within a time window
func (r *AuditRepository) CountSecurityEventsByTypeAndTime(eventType models.SecurityEventType, since time.Time) (int64, error) {
	var count int64
	err := r.db.Model(&models.SecurityEvent{}).
		Where("event_type = ? AND created_at > ?", eventType, since).
		Count(&count).Error
	return count, err
}

// ==================== LOGIN ATTEMPT OPERATIONS ====================

// CreateLoginAttempt creates a new login attempt record
func (r *AuditRepository) CreateLoginAttempt(attempt *models.LoginAttempt) error {
	return r.db.Create(attempt).Error
}

// GetFailedLoginAttemptsByIP gets failed login attempts from an IP within a time window
func (r *AuditRepository) GetFailedLoginAttemptsByIP(ipAddress string, since time.Time) ([]models.LoginAttempt, error) {
	var attempts []models.LoginAttempt
	err := r.db.Where("ip_address = ? AND success = ? AND created_at > ?", ipAddress, false, since).
		Order("created_at DESC").
		Find(&attempts).Error
	return attempts, err
}

// CountFailedLoginAttemptsByIP counts failed login attempts from an IP within a time window
func (r *AuditRepository) CountFailedLoginAttemptsByIP(ipAddress string, since time.Time) (int64, error) {
	var count int64
	err := r.db.Model(&models.LoginAttempt{}).
		Where("ip_address = ? AND success = ? AND created_at > ?", ipAddress, false, since).
		Count(&count).Error
	return count, err
}

// GetFailedLoginAttemptsByEmail gets failed login attempts for an email within a time window
func (r *AuditRepository) GetFailedLoginAttemptsByEmail(email string, since time.Time) ([]models.LoginAttempt, error) {
	var attempts []models.LoginAttempt
	err := r.db.Where("email = ? AND success = ? AND created_at > ?", email, false, since).
		Order("created_at DESC").
		Find(&attempts).Error
	return attempts, err
}

// CountFailedLoginAttemptsByEmail counts failed login attempts for an email within a time window
func (r *AuditRepository) CountFailedLoginAttemptsByEmail(email string, since time.Time) (int64, error) {
	var count int64
	err := r.db.Model(&models.LoginAttempt{}).
		Where("email = ? AND success = ? AND created_at > ?", email, false, since).
		Count(&count).Error
	return count, err
}

// ==================== BLOCKED IP OPERATIONS ====================

// CreateBlockedIP creates a new blocked IP record
func (r *AuditRepository) CreateBlockedIP(blocked *models.BlockedIP) error {
	return r.db.Create(blocked).Error
}

// GetBlockedIP gets a blocked IP record if it's still active
func (r *AuditRepository) GetBlockedIP(ipAddress string) (*models.BlockedIP, error) {
	var blocked models.BlockedIP
	err := r.db.Where("ip_address = ? AND blocked_until > ?", ipAddress, time.Now()).First(&blocked).Error
	if err != nil {
		return nil, err
	}
	return &blocked, nil
}

// IsIPBlocked checks if an IP is currently blocked
func (r *AuditRepository) IsIPBlocked(ipAddress string) (bool, error) {
	var count int64
	err := r.db.Model(&models.BlockedIP{}).
		Where("ip_address = ? AND blocked_until > ?", ipAddress, time.Now()).
		Count(&count).Error
	return count > 0, err
}

// UpdateBlockedIP updates an existing blocked IP (extends block time)
func (r *AuditRepository) UpdateBlockedIP(blocked *models.BlockedIP) error {
	return r.db.Save(blocked).Error
}

// UnblockIP removes an IP from the blocklist
func (r *AuditRepository) UnblockIP(ipAddress string) error {
	return r.db.Where("ip_address = ?", ipAddress).Delete(&models.BlockedIP{}).Error
}

// GetAllBlockedIPs gets all currently blocked IPs
func (r *AuditRepository) GetAllBlockedIPs() ([]models.BlockedIP, error) {
	var blocked []models.BlockedIP
	err := r.db.Where("blocked_until > ?", time.Now()).
		Order("blocked_at DESC").
		Find(&blocked).Error
	return blocked, err
}

// CleanupExpiredBlocks removes expired IP blocks
func (r *AuditRepository) CleanupExpiredBlocks() error {
	return r.db.Where("blocked_until < ?", time.Now()).Delete(&models.BlockedIP{}).Error
}

// ==================== PASSWORD HISTORY OPERATIONS ====================

// CreatePasswordHistory creates a new password history entry
func (r *AuditRepository) CreatePasswordHistory(history *models.PasswordHistory) error {
	return r.db.Create(history).Error
}

// GetPasswordHistory gets password history for a user (last N passwords)
func (r *AuditRepository) GetPasswordHistory(userID string, limit int) ([]models.PasswordHistory, error) {
	var history []models.PasswordHistory
	err := r.db.Where("user_id = ?", userID).
		Order("created_at DESC").
		Limit(limit).
		Find(&history).Error
	return history, err
}

// CleanupOldPasswordHistory removes old password history entries (keep only last N)
func (r *AuditRepository) CleanupOldPasswordHistory(userID string, keepCount int) error {
	// Get IDs to keep
	var keep []models.PasswordHistory
	r.db.Where("user_id = ?", userID).
		Order("created_at DESC").
		Limit(keepCount).
		Find(&keep)

	if len(keep) < keepCount {
		return nil // Nothing to cleanup
	}

	keepIDs := make([]string, len(keep))
	for i, h := range keep {
		keepIDs[i] = h.ID
	}

	// Delete entries not in keep list
	return r.db.Where("user_id = ? AND id NOT IN ?", userID, keepIDs).
		Delete(&models.PasswordHistory{}).Error
}
