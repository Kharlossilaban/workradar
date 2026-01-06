package models

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

// AuditAction represents the type of database action
type AuditAction string

const (
	AuditActionCreate AuditAction = "CREATE"
	AuditActionRead   AuditAction = "READ"
	AuditActionUpdate AuditAction = "UPDATE"
	AuditActionDelete AuditAction = "DELETE"
	AuditActionLogin  AuditAction = "LOGIN"
	AuditActionLogout AuditAction = "LOGOUT"
)

// AuditLog records all database activities for compliance and security
type AuditLog struct {
	ID          string      `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID      *string     `gorm:"type:varchar(36);index:idx_audit_user" json:"user_id"`
	Action      AuditAction `gorm:"type:varchar(20);not null;index:idx_audit_action" json:"action"`
	TableName   string      `gorm:"type:varchar(100);index:idx_audit_table" json:"table_name"`
	RecordID    *string     `gorm:"type:varchar(36)" json:"record_id"`
	OldValue    *string     `gorm:"type:text" json:"old_value,omitempty"`
	NewValue    *string     `gorm:"type:text" json:"new_value,omitempty"`
	IPAddress   string      `gorm:"type:varchar(45);index:idx_audit_ip" json:"ip_address"` // IPv6 compatible
	UserAgent   string      `gorm:"type:varchar(500)" json:"user_agent"`
	RequestPath string      `gorm:"type:varchar(255)" json:"request_path"`
	StatusCode  int         `gorm:"type:int" json:"status_code"`
	Duration    int64       `gorm:"type:bigint" json:"duration_ms"` // Duration in milliseconds
	CreatedAt   time.Time   `gorm:"index:idx_audit_created" json:"created_at"`
}

// BeforeCreate hook untuk generate UUID
func (a *AuditLog) BeforeCreate(tx *gorm.DB) error {
	if a.ID == "" {
		a.ID = uuid.New().String()
	}
	return nil
}

// SecurityEventSeverity represents the severity level of security events
type SecurityEventSeverity string

const (
	SeverityInfo     SecurityEventSeverity = "INFO"
	SeverityWarning  SecurityEventSeverity = "WARNING"
	SeverityHigh     SecurityEventSeverity = "HIGH"
	SeverityCritical SecurityEventSeverity = "CRITICAL"
)

// SecurityEventType represents the type of security event
type SecurityEventType string

const (
	EventFailedLogin         SecurityEventType = "FAILED_LOGIN"
	EventSuccessLogin        SecurityEventType = "SUCCESS_LOGIN"
	EventAccountLocked       SecurityEventType = "ACCOUNT_LOCKED"
	EventAccountUnlocked     SecurityEventType = "ACCOUNT_UNLOCKED"
	EventSuspiciousActivity  SecurityEventType = "SUSPICIOUS_ACTIVITY"
	EventUnauthorizedAccess  SecurityEventType = "UNAUTHORIZED_ACCESS"
	EventSQLInjectionAttempt SecurityEventType = "SQL_INJECTION_ATTEMPT"
	EventBruteForceDetected  SecurityEventType = "BRUTE_FORCE_DETECTED"
	EventIPBlocked           SecurityEventType = "IP_BLOCKED"
	EventIPUnblocked         SecurityEventType = "IP_UNBLOCKED"
	EventPasswordChanged     SecurityEventType = "PASSWORD_CHANGED"
	EventMFAEnabled          SecurityEventType = "MFA_ENABLED"
	EventMFADisabled         SecurityEventType = "MFA_DISABLED"
	EventSessionTimeout      SecurityEventType = "SESSION_TIMEOUT"
	EventDataExport          SecurityEventType = "DATA_EXPORT"
	EventBulkAccess          SecurityEventType = "BULK_ACCESS"
)

// SecurityEvent records security-related events
type SecurityEvent struct {
	ID         string                `gorm:"type:varchar(36);primaryKey" json:"id"`
	EventType  SecurityEventType     `gorm:"type:varchar(50);not null;index:idx_sec_event_type" json:"event_type"`
	Severity   SecurityEventSeverity `gorm:"type:enum('INFO','WARNING','HIGH','CRITICAL');default:'INFO';index:idx_sec_severity" json:"severity"`
	UserID     *string               `gorm:"type:varchar(36);index:idx_sec_user" json:"user_id"`
	IPAddress  string                `gorm:"type:varchar(45);index:idx_sec_ip" json:"ip_address"`
	Details    string                `gorm:"type:text" json:"details"`
	UserAgent  string                `gorm:"type:varchar(500)" json:"user_agent"`
	Resolved   bool                  `gorm:"default:false" json:"resolved"`
	ResolvedAt *time.Time            `json:"resolved_at,omitempty"`
	ResolvedBy *string               `gorm:"type:varchar(36)" json:"resolved_by,omitempty"`
	CreatedAt  time.Time             `gorm:"index:idx_sec_created" json:"created_at"`
}

// BeforeCreate hook untuk generate UUID
func (s *SecurityEvent) BeforeCreate(tx *gorm.DB) error {
	if s.ID == "" {
		s.ID = uuid.New().String()
	}
	return nil
}

// LoginAttempt tracks login attempts for brute force detection
type LoginAttempt struct {
	ID         string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	Email      string    `gorm:"type:varchar(255);index:idx_login_email" json:"email"`
	IPAddress  string    `gorm:"type:varchar(45);index:idx_login_ip" json:"ip_address"`
	Success    bool      `gorm:"default:false" json:"success"`
	UserAgent  string    `gorm:"type:varchar(500)" json:"user_agent"`
	FailReason *string   `gorm:"type:varchar(255)" json:"fail_reason,omitempty"`
	CreatedAt  time.Time `gorm:"index:idx_login_created" json:"created_at"`
}

// BeforeCreate hook untuk generate UUID
func (l *LoginAttempt) BeforeCreate(tx *gorm.DB) error {
	if l.ID == "" {
		l.ID = uuid.New().String()
	}
	return nil
}

// BlockedIP stores temporarily blocked IP addresses
type BlockedIP struct {
	ID           string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	IPAddress    string    `gorm:"type:varchar(45);uniqueIndex" json:"ip_address"`
	Reason       string    `gorm:"type:varchar(255)" json:"reason"`
	BlockedAt    time.Time `json:"blocked_at"`
	BlockedUntil time.Time `gorm:"index:idx_blocked_until" json:"blocked_until"`
	AttemptCount int       `gorm:"default:0" json:"attempt_count"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// BeforeCreate hook untuk generate UUID
func (b *BlockedIP) BeforeCreate(tx *gorm.DB) error {
	if b.ID == "" {
		b.ID = uuid.New().String()
	}
	return nil
}

// PasswordHistory stores previous password hashes to prevent reuse
type PasswordHistory struct {
	ID           string    `gorm:"type:varchar(36);primaryKey" json:"id"`
	UserID       string    `gorm:"type:varchar(36);not null;index:idx_pwd_history_user" json:"user_id"`
	PasswordHash string    `gorm:"type:varchar(255);not null" json:"-"`
	CreatedAt    time.Time `json:"created_at"`
}

// BeforeCreate hook untuk generate UUID
func (p *PasswordHistory) BeforeCreate(tx *gorm.DB) error {
	if p.ID == "" {
		p.ID = uuid.New().String()
	}
	return nil
}
