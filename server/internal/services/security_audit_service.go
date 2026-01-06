package services

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/workradar/server/internal/database"
	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

// AuditCheckType represents different types of security audit checks
type AuditCheckType string

const (
	AuditCheckPasswordPolicy      AuditCheckType = "password_policy"
	AuditCheckMFAAdoption         AuditCheckType = "mfa_adoption"
	AuditCheckFailedLogins        AuditCheckType = "failed_logins"
	AuditCheckInactiveAccounts    AuditCheckType = "inactive_accounts"
	AuditCheckPrivilegeEscalation AuditCheckType = "privilege_escalation"
	AuditCheckDataAccess          AuditCheckType = "data_access"
	AuditCheckSessionSecurity     AuditCheckType = "session_security"
	AuditCheckEncryption          AuditCheckType = "encryption"
	AuditCheckDatabaseHealth      AuditCheckType = "database_health"
	AuditCheckAPIUsage            AuditCheckType = "api_usage"
)

// AuditSeverity represents the severity level of audit findings
type AuditSeverity string

const (
	AuditSeverityInfo     AuditSeverity = "INFO"
	AuditSeverityLow      AuditSeverity = "LOW"
	AuditSeverityMedium   AuditSeverity = "MEDIUM"
	AuditSeverityHigh     AuditSeverity = "HIGH"
	AuditSeverityCritical AuditSeverity = "CRITICAL"
)

// AuditFinding represents a security audit finding
type AuditFinding struct {
	ID          string         `json:"id"`
	CheckType   AuditCheckType `json:"check_type"`
	Severity    AuditSeverity  `json:"severity"`
	Title       string         `json:"title"`
	Description string         `json:"description"`
	Remediation string         `json:"remediation"`
	AffectedIDs []string       `json:"affected_ids,omitempty"`
	Count       int            `json:"count"`
	CreatedAt   time.Time      `json:"created_at"`
}

// AuditReport represents a complete security audit report
type AuditReport struct {
	ID            string         `json:"id"`
	StartedAt     time.Time      `json:"started_at"`
	CompletedAt   time.Time      `json:"completed_at"`
	Duration      string         `json:"duration"`
	TotalChecks   int            `json:"total_checks"`
	PassedChecks  int            `json:"passed_checks"`
	FailedChecks  int            `json:"failed_checks"`
	Findings      []AuditFinding `json:"findings"`
	Summary       AuditSummary   `json:"summary"`
	OverallScore  int            `json:"overall_score"`  // 0-100
	OverallStatus string         `json:"overall_status"` // PASS, WARNING, FAIL
}

// AuditSummary provides summary statistics
type AuditSummary struct {
	CriticalCount int `json:"critical_count"`
	HighCount     int `json:"high_count"`
	MediumCount   int `json:"medium_count"`
	LowCount      int `json:"low_count"`
	InfoCount     int `json:"info_count"`
}

// SecurityAuditService handles automated security audits
type SecurityAuditService struct {
	db              *gorm.DB
	auditService    *AuditService
	mu              sync.RWMutex
	lastReport      *AuditReport
	auditHistory    []*AuditReport
	isRunning       bool
	schedulerCtx    context.Context
	schedulerCancel context.CancelFunc
}

var (
	securityAuditService     *SecurityAuditService
	securityAuditServiceOnce sync.Once
)

// GetSecurityAuditService returns singleton security audit service
func GetSecurityAuditService() *SecurityAuditService {
	securityAuditServiceOnce.Do(func() {
		securityAuditService = &SecurityAuditService{
			db:           database.DB,
			auditService: GetAuditService(),
		}
	})
	return securityAuditService
}

// NewSecurityAuditService creates a new security audit service
func NewSecurityAuditService(db *gorm.DB, auditService *AuditService) *SecurityAuditService {
	return &SecurityAuditService{
		db:           db,
		auditService: auditService,
	}
}

// RunFullAudit performs a complete security audit
func (s *SecurityAuditService) RunFullAudit() (*AuditReport, error) {
	s.mu.Lock()
	if s.isRunning {
		s.mu.Unlock()
		return nil, fmt.Errorf("audit already in progress")
	}
	s.isRunning = true
	s.mu.Unlock()

	defer func() {
		s.mu.Lock()
		s.isRunning = false
		s.mu.Unlock()
	}()

	startTime := time.Now()
	report := &AuditReport{
		ID:        fmt.Sprintf("audit_%d", startTime.Unix()),
		StartedAt: startTime,
		Findings:  make([]AuditFinding, 0),
	}

	// Run all audit checks
	checks := []func() *AuditFinding{
		s.checkPasswordPolicy,
		s.checkMFAAdoption,
		s.checkFailedLogins,
		s.checkInactiveAccounts,
		s.checkPrivilegeEscalation,
		s.checkDataAccess,
		s.checkSessionSecurity,
		s.checkEncryption,
		s.checkDatabaseHealth,
		s.checkAPIUsage,
	}

	report.TotalChecks = len(checks)

	for _, check := range checks {
		finding := check()
		if finding != nil {
			report.Findings = append(report.Findings, *finding)
			report.FailedChecks++
		} else {
			report.PassedChecks++
		}
	}

	// Calculate summary
	report.Summary = s.calculateSummary(report.Findings)
	report.OverallScore = s.calculateScore(report)
	report.OverallStatus = s.determineStatus(report.OverallScore)
	report.CompletedAt = time.Now()
	report.Duration = report.CompletedAt.Sub(startTime).String()

	// Store last report and history
	s.mu.Lock()
	s.lastReport = report
	// Keep last 10 audit reports in history
	s.auditHistory = append(s.auditHistory, report)
	if len(s.auditHistory) > 10 {
		s.auditHistory = s.auditHistory[1:]
	}
	s.mu.Unlock()

	// Log audit completion
	log.Printf("🔍 Security Audit Complete: Score=%d%% Status=%s Findings=%d",
		report.OverallScore, report.OverallStatus, len(report.Findings))

	return report, nil
}

// checkPasswordPolicy checks password policy compliance
func (s *SecurityAuditService) checkPasswordPolicy() *AuditFinding {
	var count int64

	// Check users with weak passwords (no password_changed_at or very old)
	cutoffDate := time.Now().AddDate(0, 0, -90) // 90 days
	s.db.Model(&models.User{}).
		Where("password_changed_at IS NULL OR password_changed_at < ?", cutoffDate).
		Where("auth_provider = ?", "local").
		Count(&count)

	if count > 0 {
		return &AuditFinding{
			ID:          fmt.Sprintf("pwd_%d", time.Now().Unix()),
			CheckType:   AuditCheckPasswordPolicy,
			Severity:    AuditSeverityMedium,
			Title:       "Outdated Passwords Detected",
			Description: fmt.Sprintf("%d users have passwords older than 90 days or never changed", count),
			Remediation: "Enforce password rotation policy and notify affected users to update passwords",
			Count:       int(count),
			CreatedAt:   time.Now(),
		}
	}
	return nil
}

// checkMFAAdoption checks MFA adoption rate
func (s *SecurityAuditService) checkMFAAdoption() *AuditFinding {
	var totalUsers, mfaEnabled int64

	s.db.Model(&models.User{}).Where("deleted_at IS NULL").Count(&totalUsers)
	s.db.Model(&models.User{}).Where("deleted_at IS NULL AND mfa_enabled = ?", true).Count(&mfaEnabled)

	if totalUsers == 0 {
		return nil
	}

	adoptionRate := float64(mfaEnabled) / float64(totalUsers) * 100

	if adoptionRate < 50 {
		severity := AuditSeverityMedium
		if adoptionRate < 25 {
			severity = AuditSeverityHigh
		}

		return &AuditFinding{
			ID:          fmt.Sprintf("mfa_%d", time.Now().Unix()),
			CheckType:   AuditCheckMFAAdoption,
			Severity:    severity,
			Title:       "Low MFA Adoption Rate",
			Description: fmt.Sprintf("Only %.1f%% of users have MFA enabled (%d/%d)", adoptionRate, mfaEnabled, totalUsers),
			Remediation: "Encourage or enforce MFA for all users, especially admin accounts",
			Count:       int(totalUsers - mfaEnabled),
			CreatedAt:   time.Now(),
		}
	}
	return nil
}

// checkFailedLogins checks for suspicious failed login patterns
func (s *SecurityAuditService) checkFailedLogins() *AuditFinding {
	var count int64
	cutoffTime := time.Now().Add(-24 * time.Hour)

	// Check for accounts with multiple failed logins in last 24 hours
	s.db.Model(&models.User{}).
		Where("failed_login_attempts >= ? AND updated_at >= ?", 3, cutoffTime).
		Count(&count)

	if count > 0 {
		severity := AuditSeverityMedium
		if count > 10 {
			severity = AuditSeverityHigh
		}

		return &AuditFinding{
			ID:          fmt.Sprintf("login_%d", time.Now().Unix()),
			CheckType:   AuditCheckFailedLogins,
			Severity:    severity,
			Title:       "Multiple Failed Login Attempts",
			Description: fmt.Sprintf("%d accounts have 3+ failed login attempts in the last 24 hours", count),
			Remediation: "Review login attempts for potential brute force attacks. Consider blocking suspicious IPs.",
			Count:       int(count),
			CreatedAt:   time.Now(),
		}
	}
	return nil
}

// checkInactiveAccounts checks for inactive accounts
func (s *SecurityAuditService) checkInactiveAccounts() *AuditFinding {
	var count int64
	cutoffDate := time.Now().AddDate(0, -6, 0) // 6 months

	s.db.Model(&models.User{}).
		Where("(last_login_at IS NULL OR last_login_at < ?) AND deleted_at IS NULL", cutoffDate).
		Count(&count)

	if count > 0 {
		return &AuditFinding{
			ID:          fmt.Sprintf("inactive_%d", time.Now().Unix()),
			CheckType:   AuditCheckInactiveAccounts,
			Severity:    AuditSeverityLow,
			Title:       "Inactive Accounts Detected",
			Description: fmt.Sprintf("%d accounts have been inactive for more than 6 months", count),
			Remediation: "Review and consider deactivating or deleting inactive accounts to reduce attack surface",
			Count:       int(count),
			CreatedAt:   time.Now(),
		}
	}
	return nil
}

// checkPrivilegeEscalation checks for privilege escalation attempts
func (s *SecurityAuditService) checkPrivilegeEscalation() *AuditFinding {
	var count int64
	cutoffTime := time.Now().Add(-7 * 24 * time.Hour) // 7 days

	// Check audit logs for role changes
	s.db.Model(&models.AuditLog{}).
		Where("action IN ? AND created_at >= ?", []string{"UPGRADE_TO_VIP", "ROLE_CHANGE", "PERMISSION_GRANT"}, cutoffTime).
		Count(&count)

	if count > 5 {
		return &AuditFinding{
			ID:          fmt.Sprintf("priv_%d", time.Now().Unix()),
			CheckType:   AuditCheckPrivilegeEscalation,
			Severity:    AuditSeverityMedium,
			Title:       "Multiple Privilege Changes Detected",
			Description: fmt.Sprintf("%d privilege/role changes in the last 7 days", count),
			Remediation: "Review recent privilege changes for unauthorized modifications",
			Count:       int(count),
			CreatedAt:   time.Now(),
		}
	}
	return nil
}

// checkDataAccess checks for unusual data access patterns
func (s *SecurityAuditService) checkDataAccess() *AuditFinding {
	var count int64
	cutoffTime := time.Now().Add(-1 * time.Hour)

	// Check for users accessing excessive amounts of data
	s.db.Model(&models.AuditLog{}).
		Where("created_at >= ?", cutoffTime).
		Group("user_id").
		Having("COUNT(*) > ?", 100).
		Count(&count)

	if count > 0 {
		return &AuditFinding{
			ID:          fmt.Sprintf("access_%d", time.Now().Unix()),
			CheckType:   AuditCheckDataAccess,
			Severity:    AuditSeverityHigh,
			Title:       "Unusual Data Access Pattern",
			Description: fmt.Sprintf("%d users accessed more than 100 records in the last hour", count),
			Remediation: "Investigate high-volume data access for potential data exfiltration",
			Count:       int(count),
			CreatedAt:   time.Now(),
		}
	}
	return nil
}

// checkSessionSecurity checks session security
func (s *SecurityAuditService) checkSessionSecurity() *AuditFinding {
	var count int64

	// Check for users logged in from multiple IPs (potential session hijacking)
	cutoffTime := time.Now().Add(-24 * time.Hour)

	// This is a simplified check - in production, you'd want more sophisticated detection
	s.db.Model(&models.LoginAttempt{}).
		Where("success = ? AND created_at >= ?", true, cutoffTime).
		Group("user_id").
		Having("COUNT(DISTINCT ip_address) > ?", 3).
		Count(&count)

	if count > 0 {
		return &AuditFinding{
			ID:          fmt.Sprintf("session_%d", time.Now().Unix()),
			CheckType:   AuditCheckSessionSecurity,
			Severity:    AuditSeverityMedium,
			Title:       "Multiple Login Locations Detected",
			Description: fmt.Sprintf("%d users logged in from more than 3 different IPs in 24 hours", count),
			Remediation: "Review for potential account sharing or session hijacking",
			Count:       int(count),
			CreatedAt:   time.Now(),
		}
	}
	return nil
}

// checkEncryption checks encryption configuration
func (s *SecurityAuditService) checkEncryption() *AuditFinding {
	// Check if encryption is enabled
	encService := GetEncryptionService()
	if !encService.IsEnabled {
		return &AuditFinding{
			ID:          fmt.Sprintf("enc_%d", time.Now().Unix()),
			CheckType:   AuditCheckEncryption,
			Severity:    AuditSeverityCritical,
			Title:       "Field-Level Encryption Disabled",
			Description: "ENCRYPTION_KEY is not set. Sensitive data is not encrypted at rest.",
			Remediation: "Set ENCRYPTION_KEY environment variable immediately for production use",
			Count:       1,
			CreatedAt:   time.Now(),
		}
	}
	return nil
}

// checkDatabaseHealth checks database health metrics
func (s *SecurityAuditService) checkDatabaseHealth() *AuditFinding {
	stats := database.GetDBStatsStruct()
	if stats == nil {
		return nil
	}

	// Check for connection pool issues
	if stats.MaxOpenConnections > 0 && stats.OpenConnections > stats.MaxOpenConnections*80/100 {
		return &AuditFinding{
			ID:        fmt.Sprintf("db_%d", time.Now().Unix()),
			CheckType: AuditCheckDatabaseHealth,
			Severity:  AuditSeverityMedium,
			Title:     "High Database Connection Usage",
			Description: fmt.Sprintf("Database connection pool is at %d%% capacity (%d/%d)",
				stats.OpenConnections*100/stats.MaxOpenConnections,
				stats.OpenConnections, stats.MaxOpenConnections),
			Remediation: "Consider increasing connection pool size or optimizing queries",
			Count:       1,
			CreatedAt:   time.Now(),
		}
	}
	return nil
}

// checkAPIUsage checks API usage patterns
func (s *SecurityAuditService) checkAPIUsage() *AuditFinding {
	var count int64
	cutoffTime := time.Now().Add(-1 * time.Hour)

	// Check for blocked IPs
	s.db.Model(&models.BlockedIP{}).
		Where("blocked_until > ? OR is_permanent = ?", time.Now(), true).
		Count(&count)

	if count > 10 {
		return &AuditFinding{
			ID:          fmt.Sprintf("api_%d", time.Now().Unix()),
			CheckType:   AuditCheckAPIUsage,
			Severity:    AuditSeverityMedium,
			Title:       "High Number of Blocked IPs",
			Description: fmt.Sprintf("%d IPs are currently blocked", count),
			Remediation: "Review blocked IPs and consider implementing additional rate limiting",
			Count:       int(count),
			CreatedAt:   time.Now(),
		}
	}

	// Check for security events
	var securityEventCount int64
	s.db.Model(&models.SecurityEvent{}).
		Where("created_at >= ? AND severity IN ?", cutoffTime, []string{"HIGH", "CRITICAL"}).
		Count(&securityEventCount)

	if securityEventCount > 5 {
		return &AuditFinding{
			ID:          fmt.Sprintf("api_%d", time.Now().Unix()),
			CheckType:   AuditCheckAPIUsage,
			Severity:    AuditSeverityHigh,
			Title:       "High Volume Security Events",
			Description: fmt.Sprintf("%d high/critical security events in the last hour", securityEventCount),
			Remediation: "Immediate review of security events required",
			Count:       int(securityEventCount),
			CreatedAt:   time.Now(),
		}
	}

	return nil
}

// calculateSummary calculates audit summary
func (s *SecurityAuditService) calculateSummary(findings []AuditFinding) AuditSummary {
	summary := AuditSummary{}
	for _, f := range findings {
		switch f.Severity {
		case AuditSeverityCritical:
			summary.CriticalCount++
		case AuditSeverityHigh:
			summary.HighCount++
		case AuditSeverityMedium:
			summary.MediumCount++
		case AuditSeverityLow:
			summary.LowCount++
		case AuditSeverityInfo:
			summary.InfoCount++
		}
	}
	return summary
}

// calculateScore calculates overall security score
func (s *SecurityAuditService) calculateScore(report *AuditReport) int {
	if report.TotalChecks == 0 {
		return 100
	}

	// Base score from passed checks
	baseScore := float64(report.PassedChecks) / float64(report.TotalChecks) * 100

	// Penalties for severity
	penalty := float64(0)
	penalty += float64(report.Summary.CriticalCount) * 20
	penalty += float64(report.Summary.HighCount) * 10
	penalty += float64(report.Summary.MediumCount) * 5
	penalty += float64(report.Summary.LowCount) * 2

	score := int(baseScore - penalty)
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}

	return score
}

// determineStatus determines overall status based on score
func (s *SecurityAuditService) determineStatus(score int) string {
	if score >= 80 {
		return "PASS"
	} else if score >= 50 {
		return "WARNING"
	}
	return "FAIL"
}

// GetLastReport returns the last audit report
func (s *SecurityAuditService) GetLastReport() *AuditReport {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.lastReport
}

// GetAuditHistory returns the history of audit reports
func (s *SecurityAuditService) GetAuditHistory() []*AuditReport {
	s.mu.RLock()
	defer s.mu.RUnlock()

	// Return a copy to prevent external modification
	history := make([]*AuditReport, len(s.auditHistory))
	copy(history, s.auditHistory)
	return history
}

// IsRunning returns whether an audit is currently running
func (s *SecurityAuditService) IsRunning() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.isRunning
}

// StartScheduler starts the automated audit scheduler
func (s *SecurityAuditService) StartScheduler(interval time.Duration) {
	s.mu.Lock()
	if s.schedulerCtx != nil {
		s.mu.Unlock()
		return
	}
	s.schedulerCtx, s.schedulerCancel = context.WithCancel(context.Background())
	s.mu.Unlock()

	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		log.Printf("🔍 Security Audit Scheduler started (interval: %s)", interval)

		// Run initial audit
		if _, err := s.RunFullAudit(); err != nil {
			log.Printf("❌ Initial security audit failed: %v", err)
		}

		for {
			select {
			case <-s.schedulerCtx.Done():
				log.Println("🔍 Security Audit Scheduler stopped")
				return
			case <-ticker.C:
				if _, err := s.RunFullAudit(); err != nil {
					log.Printf("❌ Scheduled security audit failed: %v", err)
				}
			}
		}
	}()
}

// StopScheduler stops the automated audit scheduler
func (s *SecurityAuditService) StopScheduler() {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.schedulerCancel != nil {
		s.schedulerCancel()
		s.schedulerCtx = nil
		s.schedulerCancel = nil
	}
}
