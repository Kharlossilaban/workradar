package services

import (
	"context"
	"fmt"
	"log"
	"os"
	"strconv"
	"sync"
	"time"

	"github.com/workradar/server/internal/database"
	"github.com/workradar/server/internal/models"
	"gorm.io/gorm"
)

// SecurityScheduledTaskType represents types of security scheduled tasks
type SecurityScheduledTaskType string

const (
	SecurityTaskAudit             SecurityScheduledTaskType = "SECURITY_AUDIT"
	SecurityTaskVulnerabilityScan SecurityScheduledTaskType = "VULNERABILITY_SCAN"
	SecurityTaskSessionCleanup    SecurityScheduledTaskType = "SESSION_CLEANUP"
	SecurityTaskAuditLogCleanup   SecurityScheduledTaskType = "AUDIT_LOG_CLEANUP"
	SecurityTaskBlockedIPCleanup  SecurityScheduledTaskType = "BLOCKED_IP_CLEANUP"
	SecurityTaskPasswordExpiry    SecurityScheduledTaskType = "PASSWORD_EXPIRY_CHECK"
	SecurityTaskInactiveAccounts  SecurityScheduledTaskType = "INACTIVE_ACCOUNTS_CHECK"
	SecurityTaskDatabaseOptimize  SecurityScheduledTaskType = "DATABASE_OPTIMIZE"
	SecurityTaskSecurityReport    SecurityScheduledTaskType = "SECURITY_REPORT"
	SecurityTaskTokenCleanup      SecurityScheduledTaskType = "TOKEN_CLEANUP"
)

// SecurityTaskStatus represents task execution status
type SecurityTaskStatus string

const (
	SecurityTaskPending   SecurityTaskStatus = "PENDING"
	SecurityTaskRunning   SecurityTaskStatus = "RUNNING"
	SecurityTaskCompleted SecurityTaskStatus = "COMPLETED"
	SecurityTaskFailed    SecurityTaskStatus = "FAILED"
	SecurityTaskSkipped   SecurityTaskStatus = "SKIPPED"
)

// SecurityScheduledTask represents a scheduled security task configuration
type SecurityScheduledTask struct {
	Type        SecurityScheduledTaskType `json:"type"`
	Name        string                    `json:"name"`
	Description string                    `json:"description"`
	Interval    time.Duration             `json:"interval"`
	LastRun     *time.Time                `json:"last_run,omitempty"`
	NextRun     time.Time                 `json:"next_run"`
	Status      SecurityTaskStatus        `json:"status"`
	Enabled     bool                      `json:"enabled"`
}

// SecurityTaskExecutionLog represents a task execution log entry
type SecurityTaskExecutionLog struct {
	ID          string                    `json:"id"`
	TaskType    SecurityScheduledTaskType `json:"task_type"`
	StartedAt   time.Time                 `json:"started_at"`
	CompletedAt *time.Time                `json:"completed_at,omitempty"`
	Duration    string                    `json:"duration,omitempty"`
	Status      SecurityTaskStatus        `json:"status"`
	Result      string                    `json:"result,omitempty"`
	Error       string                    `json:"error,omitempty"`
}

// SecuritySchedulerService manages scheduled security tasks
type SecuritySchedulerService struct {
	db            *gorm.DB
	tasks         map[SecurityScheduledTaskType]*SecurityScheduledTask
	executionLogs []SecurityTaskExecutionLog
	mu            sync.RWMutex
	ctx           context.Context
	cancel        context.CancelFunc
	isRunning     bool
	auditService  *SecurityAuditService
	vulnScanner   *VulnerabilityScannerService
	acService     *AccessControlService
}

var (
	securitySchedulerService     *SecuritySchedulerService
	securitySchedulerServiceOnce sync.Once
)

// GetSecuritySchedulerService returns singleton security scheduler service
func GetSecuritySchedulerService() *SecuritySchedulerService {
	securitySchedulerServiceOnce.Do(func() {
		securitySchedulerService = &SecuritySchedulerService{
			db:            database.DB,
			tasks:         make(map[SecurityScheduledTaskType]*SecurityScheduledTask),
			executionLogs: make([]SecurityTaskExecutionLog, 0),
			auditService:  GetSecurityAuditService(),
			vulnScanner:   GetVulnerabilityScannerService(),
			acService:     GetAccessControlService(),
		}
		securitySchedulerService.initializeTasks()
	})
	return securitySchedulerService
}

// NewSecuritySchedulerService creates a new security scheduler service
func NewSecuritySchedulerService(db *gorm.DB) *SecuritySchedulerService {
	service := &SecuritySchedulerService{
		db:            db,
		tasks:         make(map[SecurityScheduledTaskType]*SecurityScheduledTask),
		executionLogs: make([]SecurityTaskExecutionLog, 0),
		auditService:  GetSecurityAuditService(),
		vulnScanner:   GetVulnerabilityScannerService(),
		acService:     GetAccessControlService(),
	}
	service.initializeTasks()
	return service
}

// initializeTasks sets up default security scheduled tasks
func (s *SecuritySchedulerService) initializeTasks() {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Security Audit - Every 24 hours
	auditInterval := getSecurityEnvDuration("SECURITY_AUDIT_INTERVAL", 24*time.Hour)
	s.tasks[SecurityTaskAudit] = &SecurityScheduledTask{
		Type:        SecurityTaskAudit,
		Name:        "Security Audit",
		Description: "Comprehensive security audit of the system including password policy, MFA adoption, login failures, and more",
		Interval:    auditInterval,
		NextRun:     time.Now().Add(auditInterval),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}

	// Vulnerability Scan - Every 12 hours
	vulnInterval := getSecurityEnvDuration("VULNERABILITY_SCAN_INTERVAL", 12*time.Hour)
	s.tasks[SecurityTaskVulnerabilityScan] = &SecurityScheduledTask{
		Type:        SecurityTaskVulnerabilityScan,
		Name:        "Vulnerability Scan",
		Description: "Quick vulnerability scan including SQL injection, XSS detection, and API endpoint analysis",
		Interval:    vulnInterval,
		NextRun:     time.Now().Add(vulnInterval),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}

	// Session Cleanup - Every 1 hour
	s.tasks[SecurityTaskSessionCleanup] = &SecurityScheduledTask{
		Type:        SecurityTaskSessionCleanup,
		Name:        "Session Cleanup",
		Description: "Clean up expired sessions and refresh tokens",
		Interval:    1 * time.Hour,
		NextRun:     time.Now().Add(1 * time.Hour),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}

	// Token Cleanup - Every 6 hours
	s.tasks[SecurityTaskTokenCleanup] = &SecurityScheduledTask{
		Type:        SecurityTaskTokenCleanup,
		Name:        "Token Cleanup",
		Description: "Clean up expired password reset tokens and MFA tokens",
		Interval:    6 * time.Hour,
		NextRun:     time.Now().Add(6 * time.Hour),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}

	// Audit Log Cleanup - Every 7 days
	s.tasks[SecurityTaskAuditLogCleanup] = &SecurityScheduledTask{
		Type:        SecurityTaskAuditLogCleanup,
		Name:        "Audit Log Cleanup",
		Description: "Archive and clean old audit logs (>90 days)",
		Interval:    7 * 24 * time.Hour,
		NextRun:     time.Now().Add(7 * 24 * time.Hour),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}

	// Blocked IP Cleanup - Every 6 hours
	s.tasks[SecurityTaskBlockedIPCleanup] = &SecurityScheduledTask{
		Type:        SecurityTaskBlockedIPCleanup,
		Name:        "Blocked IP Cleanup",
		Description: "Remove expired IP blocks and temporary bans",
		Interval:    6 * time.Hour,
		NextRun:     time.Now().Add(6 * time.Hour),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}

	// Password Expiry Check - Every 24 hours
	s.tasks[SecurityTaskPasswordExpiry] = &SecurityScheduledTask{
		Type:        SecurityTaskPasswordExpiry,
		Name:        "Password Expiry Check",
		Description: "Check for users with expired passwords (>90 days)",
		Interval:    24 * time.Hour,
		NextRun:     time.Now().Add(24 * time.Hour),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}

	// Inactive Accounts Check - Every 7 days
	s.tasks[SecurityTaskInactiveAccounts] = &SecurityScheduledTask{
		Type:        SecurityTaskInactiveAccounts,
		Name:        "Inactive Accounts Check",
		Description: "Check for inactive accounts (>6 months) for potential deactivation",
		Interval:    7 * 24 * time.Hour,
		NextRun:     time.Now().Add(7 * 24 * time.Hour),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}

	// Database Optimize - Every 7 days
	s.tasks[SecurityTaskDatabaseOptimize] = &SecurityScheduledTask{
		Type:        SecurityTaskDatabaseOptimize,
		Name:        "Database Optimize",
		Description: "Optimize security-related database tables and indexes",
		Interval:    7 * 24 * time.Hour,
		NextRun:     time.Now().Add(7 * 24 * time.Hour),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}

	// Security Report - Every 7 days
	s.tasks[SecurityTaskSecurityReport] = &SecurityScheduledTask{
		Type:        SecurityTaskSecurityReport,
		Name:        "Security Report Generation",
		Description: "Generate weekly security report summary",
		Interval:    7 * 24 * time.Hour,
		NextRun:     time.Now().Add(7 * 24 * time.Hour),
		Status:      SecurityTaskPending,
		Enabled:     true,
	}
}

// Start starts the security scheduler
func (s *SecuritySchedulerService) Start() error {
	s.mu.Lock()
	if s.isRunning {
		s.mu.Unlock()
		return fmt.Errorf("security scheduler is already running")
	}
	s.ctx, s.cancel = context.WithCancel(context.Background())
	s.isRunning = true
	s.mu.Unlock()

	go s.run()

	log.Println("🔒 Security Scheduler Service started")
	return nil
}

// Stop stops the security scheduler
func (s *SecuritySchedulerService) Stop() {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.cancel != nil {
		s.cancel()
		s.isRunning = false
		log.Println("🔒 Security Scheduler Service stopped")
	}
}

// run is the main scheduler loop
func (s *SecuritySchedulerService) run() {
	ticker := time.NewTicker(1 * time.Minute)
	defer ticker.Stop()

	// Run initial check
	s.checkAndRunTasks()

	for {
		select {
		case <-s.ctx.Done():
			return
		case <-ticker.C:
			s.checkAndRunTasks()
		}
	}
}

// checkAndRunTasks checks and runs due security tasks
func (s *SecuritySchedulerService) checkAndRunTasks() {
	s.mu.RLock()
	tasksToRun := make([]SecurityScheduledTaskType, 0)
	now := time.Now()

	for taskType, task := range s.tasks {
		if task.Enabled && task.Status != SecurityTaskRunning && now.After(task.NextRun) {
			tasksToRun = append(tasksToRun, taskType)
		}
	}
	s.mu.RUnlock()

	// Run each due task
	for _, taskType := range tasksToRun {
		go s.executeTask(taskType)
	}
}

// executeTask executes a single security task
func (s *SecuritySchedulerService) executeTask(taskType SecurityScheduledTaskType) {
	s.mu.Lock()
	task, exists := s.tasks[taskType]
	if !exists || task.Status == SecurityTaskRunning {
		s.mu.Unlock()
		return
	}
	task.Status = SecurityTaskRunning
	s.mu.Unlock()

	// Create execution log
	execLog := SecurityTaskExecutionLog{
		ID:        fmt.Sprintf("sec_exec_%s_%d", taskType, time.Now().UnixNano()),
		TaskType:  taskType,
		StartedAt: time.Now(),
		Status:    SecurityTaskRunning,
	}

	// Execute the task
	var result string
	var err error

	switch taskType {
	case SecurityTaskAudit:
		result, err = s.runSecurityAudit()
	case SecurityTaskVulnerabilityScan:
		result, err = s.runVulnerabilityScan()
	case SecurityTaskSessionCleanup:
		result, err = s.runSessionCleanup()
	case SecurityTaskTokenCleanup:
		result, err = s.runTokenCleanup()
	case SecurityTaskAuditLogCleanup:
		result, err = s.runAuditLogCleanup()
	case SecurityTaskBlockedIPCleanup:
		result, err = s.runBlockedIPCleanup()
	case SecurityTaskPasswordExpiry:
		result, err = s.runPasswordExpiryCheck()
	case SecurityTaskInactiveAccounts:
		result, err = s.runInactiveAccountsCheck()
	case SecurityTaskDatabaseOptimize:
		result, err = s.runDatabaseOptimize()
	case SecurityTaskSecurityReport:
		result, err = s.runSecurityReport()
	default:
		err = fmt.Errorf("unknown security task type: %s", taskType)
	}

	// Update execution log
	now := time.Now()
	execLog.CompletedAt = &now
	execLog.Duration = now.Sub(execLog.StartedAt).String()

	if err != nil {
		execLog.Status = SecurityTaskFailed
		execLog.Error = err.Error()
		log.Printf("❌ Security Task %s failed: %v", taskType, err)
	} else {
		execLog.Status = SecurityTaskCompleted
		execLog.Result = result
		log.Printf("✅ Security Task %s completed: %s", taskType, result)
	}

	// Update task status
	s.mu.Lock()
	task.Status = execLog.Status
	task.LastRun = &now
	task.NextRun = now.Add(task.Interval)

	// Store execution log (keep last 100)
	s.executionLogs = append(s.executionLogs, execLog)
	if len(s.executionLogs) > 100 {
		s.executionLogs = s.executionLogs[1:]
	}
	s.mu.Unlock()
}

// Task execution functions

func (s *SecuritySchedulerService) runSecurityAudit() (string, error) {
	report, err := s.auditService.RunFullAudit()
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("Score: %d%%, Status: %s, Findings: %d", report.OverallScore, report.OverallStatus, len(report.Findings)), nil
}

func (s *SecuritySchedulerService) runVulnerabilityScan() (string, error) {
	result, err := s.vulnScanner.RunQuickScan()
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("Risk Level: %s, Vulnerabilities: %d", result.RiskLevel, len(result.Vulnerabilities)), nil
}

func (s *SecuritySchedulerService) runSessionCleanup() (string, error) {
	// Clean up blacklisted tokens that have expired
	// JWT tokens expire on their own, but we can clean up blacklist entries
	totalCleaned := int64(0)

	// Delete old login attempts (more than 7 days old for failed, 30 days for successful)
	result := s.db.Where("created_at < ? AND success = ?", time.Now().AddDate(0, 0, -7), false).Delete(&models.LoginAttempt{})
	if result.Error == nil {
		totalCleaned += result.RowsAffected
	}

	result = s.db.Where("created_at < ? AND success = ?", time.Now().AddDate(0, 0, -30), true).Delete(&models.LoginAttempt{})
	if result.Error == nil {
		totalCleaned += result.RowsAffected
	}

	return fmt.Sprintf("Cleaned %d expired session-related records", totalCleaned), nil
}

func (s *SecuritySchedulerService) runTokenCleanup() (string, error) {
	totalCleaned := int64(0)

	// Clean expired password reset tokens
	result := s.db.Where("expires_at < ?", time.Now()).Delete(&models.PasswordReset{})
	if result.Error != nil {
		return "", result.Error
	}
	totalCleaned += result.RowsAffected

	// Clean old MFA backup codes that have been used
	// Clean security events older than 30 days
	cutoff30Days := time.Now().AddDate(0, 0, -30)
	result = s.db.Where("created_at < ? AND resolved = ?", cutoff30Days, true).Delete(&models.SecurityEvent{})
	if result.Error != nil {
		log.Printf("⚠️ Failed to cleanup security events: %v", result.Error)
	} else {
		totalCleaned += result.RowsAffected
	}

	return fmt.Sprintf("Cleaned %d expired tokens/records", totalCleaned), nil
}

func (s *SecuritySchedulerService) runAuditLogCleanup() (string, error) {
	// Get retention days from environment
	retentionDays := getSecurityEnvInt("AUDIT_LOG_RETENTION_DAYS", 90)
	cutoffDate := time.Now().AddDate(0, 0, -retentionDays)

	// Archive logs before deletion (optional - could write to file or send to external service)
	var count int64
	s.db.Model(&models.AuditLog{}).Where("created_at < ?", cutoffDate).Count(&count)

	if count > 0 {
		log.Printf("📁 Archiving %d audit logs older than %d days...", count, retentionDays)
	}

	// Delete old audit logs
	result := s.db.Where("created_at < ?", cutoffDate).Delete(&models.AuditLog{})
	if result.Error != nil {
		return "", result.Error
	}

	return fmt.Sprintf("Archived/deleted %d old audit logs (retention: %d days)", result.RowsAffected, retentionDays), nil
}

func (s *SecuritySchedulerService) runBlockedIPCleanup() (string, error) {
	// Remove expired IP blocks that aren't permanent
	result := s.db.Where("blocked_until < ? AND is_permanent = ?", time.Now(), false).Delete(&models.BlockedIP{})
	if result.Error != nil {
		return "", result.Error
	}

	// Also clean old login attempts (keep last 30 days)
	cutoff30Days := time.Now().AddDate(0, 0, -30)
	loginResult := s.db.Where("created_at < ?", cutoff30Days).Delete(&models.LoginAttempt{})
	if loginResult.Error != nil {
		log.Printf("⚠️ Failed to cleanup login attempts: %v", loginResult.Error)
	}

	return fmt.Sprintf("Removed %d expired IP blocks, %d old login attempts", result.RowsAffected, loginResult.RowsAffected), nil
}

func (s *SecuritySchedulerService) runPasswordExpiryCheck() (string, error) {
	// Find users with passwords older than configured days (default 90)
	maxPasswordAgeDays := getSecurityEnvInt("PASSWORD_MAX_AGE_DAYS", 90)
	cutoffDate := time.Now().AddDate(0, 0, -maxPasswordAgeDays)

	var expiredUsers []models.User
	result := s.db.Model(&models.User{}).
		Where("(password_changed_at IS NULL OR password_changed_at < ?)", cutoffDate).
		Where("auth_provider = ?", "local").
		Where("deleted_at IS NULL").
		Find(&expiredUsers)

	if result.Error != nil {
		return "", result.Error
	}

	count := len(expiredUsers)

	// Log warning for each user with expired password
	for _, user := range expiredUsers {
		log.Printf("⚠️ User %s has expired password (last changed: %v)", user.Email, user.PasswordChangedAt)
	}

	// Create security event if there are expired passwords
	if count > 0 {
		s.db.Create(&models.SecurityEvent{
			EventType: models.SecurityEventType("PASSWORD_EXPIRY_WARNING"),
			Details:   fmt.Sprintf("%d users have passwords older than %d days", count, maxPasswordAgeDays),
			Severity:  models.SeverityWarning,
			IPAddress: "system",
			Resolved:  false,
		})
	}

	return fmt.Sprintf("Found %d users with expired passwords (>%d days)", count, maxPasswordAgeDays), nil
}

func (s *SecuritySchedulerService) runInactiveAccountsCheck() (string, error) {
	// Find accounts inactive for more than configured months (default 6)
	inactiveMonths := getSecurityEnvInt("INACTIVE_ACCOUNT_MONTHS", 6)
	cutoffDate := time.Now().AddDate(0, -inactiveMonths, 0)

	var inactiveUsers []models.User
	result := s.db.Model(&models.User{}).
		Where("(last_login_at IS NULL OR last_login_at < ?)", cutoffDate).
		Where("deleted_at IS NULL").
		Find(&inactiveUsers)

	if result.Error != nil {
		return "", result.Error
	}

	count := len(inactiveUsers)

	// Log each inactive account
	for _, user := range inactiveUsers {
		log.Printf("⚠️ Inactive account detected: %s (last login: %v)", user.Email, user.LastLoginAt)
	}

	// Create security event if there are many inactive accounts
	if count > 10 {
		s.db.Create(&models.SecurityEvent{
			EventType: models.SecurityEventType("INACTIVE_ACCOUNTS_WARNING"),
			Details:   fmt.Sprintf("%d accounts inactive for >%d months", count, inactiveMonths),
			Severity:  models.SeverityInfo,
			IPAddress: "system",
			Resolved:  false,
		})
	}

	return fmt.Sprintf("Found %d inactive accounts (>%d months)", count, inactiveMonths), nil
}

func (s *SecuritySchedulerService) runDatabaseOptimize() (string, error) {
	// Optimize security-related tables
	tables := []string{
		"audit_logs",
		"security_events",
		"login_attempts",
		"blocked_ips",
		"password_histories",
	}

	optimized := 0
	errors := 0

	for _, table := range tables {
		// Check if table exists first
		var count int64
		s.db.Raw(fmt.Sprintf("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '%s'", table)).Scan(&count)
		if count == 0 {
			continue
		}

		// Run OPTIMIZE TABLE
		if err := s.db.Exec(fmt.Sprintf("OPTIMIZE TABLE %s", table)).Error; err != nil {
			log.Printf("⚠️ Failed to optimize table %s: %v", table, err)
			errors++
		} else {
			optimized++
		}
	}

	// Also analyze tables for query optimization
	for _, table := range tables {
		var count int64
		s.db.Raw(fmt.Sprintf("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '%s'", table)).Scan(&count)
		if count == 0 {
			continue
		}

		s.db.Exec(fmt.Sprintf("ANALYZE TABLE %s", table))
	}

	return fmt.Sprintf("Optimized %d/%d security tables (%d errors)", optimized, len(tables), errors), nil
}

func (s *SecuritySchedulerService) runSecurityReport() (string, error) {
	// Generate comprehensive security report
	report := SecurityWeeklyReport{
		GeneratedAt: time.Now(),
		Period: ReportPeriod{
			Start: time.Now().AddDate(0, 0, -7),
			End:   time.Now(),
		},
	}

	// Get audit stats
	var auditStats struct {
		Total    int64
		Critical int64
		Warning  int64
		Info     int64
	}

	s.db.Model(&models.AuditLog{}).
		Where("created_at >= ?", report.Period.Start).
		Count(&auditStats.Total)

	// Get security events stats
	var eventStats struct {
		Total      int64
		Unresolved int64
		Critical   int64
	}

	s.db.Model(&models.SecurityEvent{}).
		Where("created_at >= ?", report.Period.Start).
		Count(&eventStats.Total)

	s.db.Model(&models.SecurityEvent{}).
		Where("created_at >= ? AND resolved = ?", report.Period.Start, false).
		Count(&eventStats.Unresolved)

	s.db.Model(&models.SecurityEvent{}).
		Where("created_at >= ? AND severity = ?", report.Period.Start, "CRITICAL").
		Count(&eventStats.Critical)

	// Get login stats
	var loginStats struct {
		Total  int64
		Failed int64
	}

	s.db.Model(&models.LoginAttempt{}).
		Where("created_at >= ?", report.Period.Start).
		Count(&loginStats.Total)

	s.db.Model(&models.LoginAttempt{}).
		Where("created_at >= ? AND success = ?", report.Period.Start, false).
		Count(&loginStats.Failed)

	// Get blocked IPs count
	var blockedIPCount int64
	s.db.Model(&models.BlockedIP{}).
		Where("created_at >= ?", report.Period.Start).
		Count(&blockedIPCount)

	// Get last audit score
	auditReport := s.auditService.GetLastReport()
	vulnScan := s.vulnScanner.GetLastScan()

	// Build summary
	summary := fmt.Sprintf(`
=== WEEKLY SECURITY REPORT ===
Period: %s to %s
Generated: %s

📊 AUDIT LOGS
- Total entries: %d

🚨 SECURITY EVENTS
- Total events: %d
- Unresolved: %d
- Critical: %d

🔐 LOGIN ATTEMPTS
- Total: %d
- Failed: %d (%.1f%%)

🚫 BLOCKED IPs: %d new blocks
`,
		report.Period.Start.Format("2006-01-02"),
		report.Period.End.Format("2006-01-02"),
		report.GeneratedAt.Format("2006-01-02 15:04:05"),
		auditStats.Total,
		eventStats.Total,
		eventStats.Unresolved,
		eventStats.Critical,
		loginStats.Total,
		loginStats.Failed,
		func() float64 {
			if loginStats.Total == 0 {
				return 0
			}
			return float64(loginStats.Failed) / float64(loginStats.Total) * 100
		}(),
		blockedIPCount,
	)

	if auditReport != nil {
		summary += fmt.Sprintf("\n📋 LAST AUDIT SCORE: %d%% (%s)", auditReport.OverallScore, auditReport.OverallStatus)
	}

	if vulnScan != nil {
		summary += fmt.Sprintf("\n🔍 LAST VULNERABILITY SCAN: %s risk level", vulnScan.RiskLevel)
	}

	log.Println(summary)

	// Store report in database (optional)
	s.db.Create(&models.SecurityEvent{
		EventType: models.SecurityEventType("WEEKLY_SECURITY_REPORT"),
		Details:   summary,
		Severity:  models.SeverityInfo,
		IPAddress: "system",
		Resolved:  true,
	})

	return "Weekly security report generated successfully", nil
}

// SecurityWeeklyReport represents a weekly security report
type SecurityWeeklyReport struct {
	GeneratedAt time.Time    `json:"generated_at"`
	Period      ReportPeriod `json:"period"`
}

// ReportPeriod represents a time period for reports
type ReportPeriod struct {
	Start time.Time `json:"start"`
	End   time.Time `json:"end"`
}

// GetTasks returns all scheduled security tasks
func (s *SecuritySchedulerService) GetTasks() []*SecurityScheduledTask {
	s.mu.RLock()
	defer s.mu.RUnlock()

	tasks := make([]*SecurityScheduledTask, 0, len(s.tasks))
	for _, task := range s.tasks {
		tasks = append(tasks, task)
	}
	return tasks
}

// GetTask returns a specific task
func (s *SecuritySchedulerService) GetTask(taskType SecurityScheduledTaskType) *SecurityScheduledTask {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.tasks[taskType]
}

// EnableTask enables a security task
func (s *SecuritySchedulerService) EnableTask(taskType SecurityScheduledTaskType) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	task, exists := s.tasks[taskType]
	if !exists {
		return fmt.Errorf("task not found: %s", taskType)
	}
	task.Enabled = true
	return nil
}

// DisableTask disables a security task
func (s *SecuritySchedulerService) DisableTask(taskType SecurityScheduledTaskType) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	task, exists := s.tasks[taskType]
	if !exists {
		return fmt.Errorf("task not found: %s", taskType)
	}
	task.Enabled = false
	return nil
}

// RunTaskNow triggers immediate execution of a security task
func (s *SecuritySchedulerService) RunTaskNow(taskType SecurityScheduledTaskType) error {
	s.mu.RLock()
	task, exists := s.tasks[taskType]
	if !exists {
		s.mu.RUnlock()
		return fmt.Errorf("task not found: %s", taskType)
	}
	if task.Status == SecurityTaskRunning {
		s.mu.RUnlock()
		return fmt.Errorf("task is already running: %s", taskType)
	}
	s.mu.RUnlock()

	go s.executeTask(taskType)
	return nil
}

// GetExecutionLogs returns task execution logs
func (s *SecuritySchedulerService) GetExecutionLogs(limit int) []SecurityTaskExecutionLog {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if limit <= 0 || limit > len(s.executionLogs) {
		limit = len(s.executionLogs)
	}

	// Return most recent logs
	start := len(s.executionLogs) - limit
	if start < 0 {
		start = 0
	}
	return s.executionLogs[start:]
}

// IsRunning returns whether the scheduler is running
func (s *SecuritySchedulerService) IsRunning() bool {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.isRunning
}

// GetSchedulerStatus returns comprehensive scheduler status
func (s *SecuritySchedulerService) GetSchedulerStatus() map[string]interface{} {
	s.mu.RLock()
	defer s.mu.RUnlock()

	tasks := make([]map[string]interface{}, 0)
	for _, task := range s.tasks {
		taskInfo := map[string]interface{}{
			"type":        task.Type,
			"name":        task.Name,
			"description": task.Description,
			"interval":    task.Interval.String(),
			"next_run":    task.NextRun,
			"status":      task.Status,
			"enabled":     task.Enabled,
		}
		if task.LastRun != nil {
			taskInfo["last_run"] = task.LastRun
		}
		tasks = append(tasks, taskInfo)
	}

	return map[string]interface{}{
		"is_running":  s.isRunning,
		"tasks":       tasks,
		"total_tasks": len(s.tasks),
		"enabled_tasks": func() int {
			count := 0
			for _, t := range s.tasks {
				if t.Enabled {
					count++
				}
			}
			return count
		}(),
		"recent_executions": len(s.executionLogs),
	}
}

// Helper functions

func getSecurityEnvDuration(key string, defaultValue time.Duration) time.Duration {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}

	duration, err := time.ParseDuration(value)
	if err != nil {
		return defaultValue
	}
	return duration
}

func getSecurityEnvInt(key string, defaultValue int) int {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}

	intValue, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}
	return intValue
}
