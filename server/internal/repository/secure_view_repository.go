package repository

import (
	"time"

	"github.com/workradar/server/internal/database"
	"gorm.io/gorm"
)

// SecureViewRepository provides access to database views with pre-sanitized data
type SecureViewRepository struct {
	db          *gorm.DB
	connManager *database.MultiConnectionManager
}

// NewSecureViewRepository creates a new secure view repository
func NewSecureViewRepository() *SecureViewRepository {
	return &SecureViewRepository{
		db:          database.DB,
		connManager: database.GetConnectionManager(),
	}
}

// getReadDB returns read-only database connection
func (r *SecureViewRepository) getReadDB() *gorm.DB {
	if r.connManager != nil {
		return r.connManager.GetReadDB()
	}
	return r.db
}

// ============================================
// VIEW MODELS
// ============================================

// UserPublicProfile represents data from v_user_public_profiles view
type UserPublicProfile struct {
	ID             string    `json:"id"`
	Username       string    `json:"username"`
	EmailMasked    string    `json:"email_masked"`
	ProfilePicture *string   `json:"profile_picture"`
	AuthProvider   string    `json:"auth_provider"`
	UserType       string    `json:"user_type"`
	MFAEnabled     bool      `json:"mfa_enabled"`
	CreatedAt      time.Time `json:"created_at"`
}

// UserDashboard represents data from v_user_dashboard view
type UserDashboard struct {
	ID              string     `json:"id"`
	Username        string     `json:"username"`
	Email           string     `json:"email"`
	ProfilePicture  *string    `json:"profile_picture"`
	UserType        string     `json:"user_type"`
	VIPExpiresAt    *time.Time `json:"vip_expires_at"`
	MFAEnabled      bool       `json:"mfa_enabled"`
	LastLoginAt     *time.Time `json:"last_login_at"`
	TotalTasks      int        `json:"total_tasks"`
	CompletedTasks  int        `json:"completed_tasks"`
	TotalCategories int        `json:"total_categories"`
}

// TaskSummary represents data from v_task_summaries view
type TaskSummary struct {
	ID            string     `json:"id"`
	Title         string     `json:"title"`
	Priority      string     `json:"priority"`
	IsCompleted   bool       `json:"is_completed"`
	Date          *time.Time `json:"date"`
	StartTime     *string    `json:"start_time"`
	EndTime       *string    `json:"end_time"`
	UserID        string     `json:"user_id"`
	CategoryName  *string    `json:"category_name"`
	CategoryColor *string    `json:"category_color"`
}

// AuditLogSummary represents data from v_audit_logs_summary view
type AuditLogSummary struct {
	ID              uint      `json:"id"`
	Action          string    `json:"action"`
	TableName       string    `json:"table_name"`
	RecordID        string    `json:"record_id"`
	IPAddress       string    `json:"ip_address"`
	CreatedAt       time.Time `json:"created_at"`
	UserName        *string   `json:"user_name"`
	UserEmailMasked *string   `json:"user_email_masked"`
}

// SecurityEventDashboard represents data from v_security_events_dashboard view
type SecurityEventDashboard struct {
	EventDate  time.Time `json:"event_date"`
	EventType  string    `json:"event_type"`
	Severity   string    `json:"severity"`
	EventCount int       `json:"event_count"`
}

// BlockedIPActive represents data from v_blocked_ips_active view
type BlockedIPActive struct {
	IPAddress        string     `json:"ip_address"`
	Reason           string     `json:"reason"`
	BlockedAt        time.Time  `json:"blocked_at"`
	ExpiresAt        *time.Time `json:"expires_at"`
	MinutesRemaining int        `json:"minutes_remaining"`
}

// SubscriptionStatus represents data from v_subscription_status view
type SubscriptionStatus struct {
	ID                 uint       `json:"id"`
	UserID             string     `json:"user_id"`
	Username           string     `json:"username"`
	EmailMasked        string     `json:"email_masked"`
	PlanType           string     `json:"plan_type"`
	Status             string     `json:"status"`
	StartedAt          time.Time  `json:"started_at"`
	ExpiresAt          *time.Time `json:"expires_at"`
	SubscriptionHealth string     `json:"subscription_health"`
}

// PaymentHistory represents data from v_payment_history view
type PaymentHistory struct {
	ID          uint      `json:"id"`
	OrderID     string    `json:"order_id"`
	UserID      string    `json:"user_id"`
	Username    string    `json:"username"`
	Amount      float64   `json:"amount"`
	Status      string    `json:"status"`
	PaymentType string    `json:"payment_type"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// ============================================
// VIEW REPOSITORY METHODS
// ============================================

// GetPublicProfiles returns paginated public user profiles
func (r *SecureViewRepository) GetPublicProfiles(page, limit int) ([]UserPublicProfile, int64, error) {
	var profiles []UserPublicProfile
	var total int64

	db := r.getReadDB()
	offset := (page - 1) * limit

	// Count total
	if err := db.Table("v_user_public_profiles").Count(&total).Error; err != nil {
		return nil, 0, err
	}

	// Get paginated results
	if err := db.Table("v_user_public_profiles").
		Offset(offset).
		Limit(limit).
		Find(&profiles).Error; err != nil {
		return nil, 0, err
	}

	return profiles, total, nil
}

// GetPublicProfileByID returns a single public profile
func (r *SecureViewRepository) GetPublicProfileByID(id string) (*UserPublicProfile, error) {
	var profile UserPublicProfile

	db := r.getReadDB()
	if err := db.Table("v_user_public_profiles").
		Where("id = ?", id).
		First(&profile).Error; err != nil {
		return nil, err
	}

	return &profile, nil
}

// GetUserDashboard returns user dashboard data
func (r *SecureViewRepository) GetUserDashboard(userID string) (*UserDashboard, error) {
	var dashboard UserDashboard

	db := r.getReadDB()
	if err := db.Table("v_user_dashboard").
		Where("id = ?", userID).
		First(&dashboard).Error; err != nil {
		return nil, err
	}

	return &dashboard, nil
}

// GetTaskSummaries returns task summaries for a user
func (r *SecureViewRepository) GetTaskSummaries(userID string, page, limit int) ([]TaskSummary, int64, error) {
	var tasks []TaskSummary
	var total int64

	db := r.getReadDB()
	offset := (page - 1) * limit

	query := db.Table("v_task_summaries").Where("user_id = ?", userID)

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Offset(offset).Limit(limit).Find(&tasks).Error; err != nil {
		return nil, 0, err
	}

	return tasks, total, nil
}

// GetAuditLogsSummary returns audit logs summary
func (r *SecureViewRepository) GetAuditLogsSummary(page, limit int, filters map[string]interface{}) ([]AuditLogSummary, int64, error) {
	var logs []AuditLogSummary
	var total int64

	db := r.getReadDB()
	offset := (page - 1) * limit

	query := db.Table("v_audit_logs_summary")

	// Apply filters
	if action, ok := filters["action"]; ok {
		query = query.Where("action = ?", action)
	}
	if tableName, ok := filters["table_name"]; ok {
		query = query.Where("table_name = ?", tableName)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Order("created_at DESC").
		Offset(offset).
		Limit(limit).
		Find(&logs).Error; err != nil {
		return nil, 0, err
	}

	return logs, total, nil
}

// GetSecurityEventsDashboard returns security events dashboard data
func (r *SecureViewRepository) GetSecurityEventsDashboard() ([]SecurityEventDashboard, error) {
	var events []SecurityEventDashboard

	db := r.getReadDB()
	if err := db.Table("v_security_events_dashboard").
		Find(&events).Error; err != nil {
		return nil, err
	}

	return events, nil
}

// GetActiveBlockedIPs returns currently blocked IPs
func (r *SecureViewRepository) GetActiveBlockedIPs() ([]BlockedIPActive, error) {
	var blocked []BlockedIPActive

	db := r.getReadDB()
	if err := db.Table("v_blocked_ips_active").
		Find(&blocked).Error; err != nil {
		return nil, err
	}

	return blocked, nil
}

// GetSubscriptionStatuses returns subscription statuses
func (r *SecureViewRepository) GetSubscriptionStatuses(page, limit int, healthFilter string) ([]SubscriptionStatus, int64, error) {
	var statuses []SubscriptionStatus
	var total int64

	db := r.getReadDB()
	offset := (page - 1) * limit

	query := db.Table("v_subscription_status")

	if healthFilter != "" {
		query = query.Where("subscription_health = ?", healthFilter)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Offset(offset).Limit(limit).Find(&statuses).Error; err != nil {
		return nil, 0, err
	}

	return statuses, total, nil
}

// GetPaymentHistory returns payment history
func (r *SecureViewRepository) GetPaymentHistory(userID string, page, limit int) ([]PaymentHistory, int64, error) {
	var payments []PaymentHistory
	var total int64

	db := r.getReadDB()
	offset := (page - 1) * limit

	query := db.Table("v_payment_history")

	if userID != "" {
		query = query.Where("user_id = ?", userID)
	}

	if err := query.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	if err := query.Order("created_at DESC").
		Offset(offset).
		Limit(limit).
		Find(&payments).Error; err != nil {
		return nil, 0, err
	}

	return payments, total, nil
}

// ============================================
// ANALYTICS METHODS
// ============================================

// SecurityStats holds security statistics
type SecurityStats struct {
	TotalSecurityEvents int64            `json:"total_security_events"`
	ActiveBlockedIPs    int64            `json:"active_blocked_ips"`
	LockedAccounts      int64            `json:"locked_accounts"`
	MFAEnabledUsers     int64            `json:"mfa_enabled_users"`
	MFADisabledUsers    int64            `json:"mfa_disabled_users"`
	RecentFailedLogins  int64            `json:"recent_failed_logins"`
	EventsByType        map[string]int64 `json:"events_by_type"`
	EventsBySeverity    map[string]int64 `json:"events_by_severity"`
}

// GetSecurityStats returns aggregated security statistics
func (r *SecureViewRepository) GetSecurityStats() (*SecurityStats, error) {
	db := r.getReadDB()
	stats := &SecurityStats{
		EventsByType:     make(map[string]int64),
		EventsBySeverity: make(map[string]int64),
	}

	// Count total security events (last 30 days)
	db.Table("security_events").
		Where("created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)").
		Count(&stats.TotalSecurityEvents)

	// Count active blocked IPs
	db.Table("v_blocked_ips_active").Count(&stats.ActiveBlockedIPs)

	// Count locked accounts
	db.Table("users").
		Where("locked_until > NOW()").
		Count(&stats.LockedAccounts)

	// Count MFA status
	db.Table("users").Where("mfa_enabled = ?", true).Count(&stats.MFAEnabledUsers)
	db.Table("users").Where("mfa_enabled = ?", false).Count(&stats.MFADisabledUsers)

	// Count recent failed logins (last 24 hours)
	db.Table("security_events").
		Where("event_type = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)", "FAILED_LOGIN").
		Count(&stats.RecentFailedLogins)

	// Events by type
	var typeResults []struct {
		EventType string
		Count     int64
	}
	db.Table("security_events").
		Select("event_type, COUNT(*) as count").
		Where("created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)").
		Group("event_type").
		Scan(&typeResults)

	for _, r := range typeResults {
		stats.EventsByType[r.EventType] = r.Count
	}

	// Events by severity
	var severityResults []struct {
		Severity string
		Count    int64
	}
	db.Table("security_events").
		Select("severity, COUNT(*) as count").
		Where("created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)").
		Group("severity").
		Scan(&severityResults)

	for _, r := range severityResults {
		stats.EventsBySeverity[r.Severity] = r.Count
	}

	return stats, nil
}
