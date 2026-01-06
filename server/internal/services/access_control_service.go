package services

import (
	"context"
	"errors"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/workradar/server/internal/database"
	"gorm.io/gorm"
)

// Permission represents a specific permission
type Permission string

const (
	// User permissions
	PermissionUserRead    Permission = "user:read"
	PermissionUserCreate  Permission = "user:create"
	PermissionUserUpdate  Permission = "user:update"
	PermissionUserDelete  Permission = "user:delete"
	PermissionUserUpgrade Permission = "user:upgrade"
	PermissionUserLock    Permission = "user:lock"
	PermissionUserUnlock  Permission = "user:unlock"

	// Task permissions
	PermissionTaskRead   Permission = "task:read"
	PermissionTaskCreate Permission = "task:create"
	PermissionTaskUpdate Permission = "task:update"
	PermissionTaskDelete Permission = "task:delete"

	// Category permissions
	PermissionCategoryRead   Permission = "category:read"
	PermissionCategoryCreate Permission = "category:create"
	PermissionCategoryUpdate Permission = "category:update"
	PermissionCategoryDelete Permission = "category:delete"

	// Security permissions
	PermissionAuditRead      Permission = "audit:read"
	PermissionSecurityRead   Permission = "security:read"
	PermissionSecurityManage Permission = "security:manage"

	// Payment permissions
	PermissionPaymentRead    Permission = "payment:read"
	PermissionPaymentProcess Permission = "payment:process"

	// Admin permissions
	PermissionAdminFull Permission = "admin:full"
)

// Role represents a user role with permissions
type Role string

const (
	RoleUser       Role = "user"
	RoleVIP        Role = "vip"
	RoleModerator  Role = "moderator"
	RoleAdmin      Role = "admin"
	RoleSuperAdmin Role = "superadmin"
)

// AccessControlService manages permissions and access control
type AccessControlService struct {
	mu              sync.RWMutex
	rolePermissions map[Role][]Permission
	connManager     *database.MultiConnectionManager
}

var (
	accessControlService     *AccessControlService
	accessControlServiceOnce sync.Once
)

// GetAccessControlService returns singleton access control service
func GetAccessControlService() *AccessControlService {
	accessControlServiceOnce.Do(func() {
		accessControlService = &AccessControlService{
			rolePermissions: make(map[Role][]Permission),
			connManager:     database.GetConnectionManager(),
		}
		accessControlService.initializeDefaultPermissions()
	})
	return accessControlService
}

// initializeDefaultPermissions sets up default role permissions
func (s *AccessControlService) initializeDefaultPermissions() {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Regular user permissions
	s.rolePermissions[RoleUser] = []Permission{
		PermissionUserRead,
		PermissionUserUpdate,
		PermissionTaskRead,
		PermissionTaskCreate,
		PermissionTaskUpdate,
		PermissionTaskDelete,
		PermissionCategoryRead,
		PermissionCategoryCreate,
		PermissionCategoryUpdate,
		PermissionCategoryDelete,
	}

	// VIP user permissions (same as user + some extras)
	s.rolePermissions[RoleVIP] = append(
		s.rolePermissions[RoleUser],
		PermissionPaymentRead,
	)

	// Moderator permissions
	s.rolePermissions[RoleModerator] = []Permission{
		PermissionUserRead,
		PermissionUserLock,
		PermissionUserUnlock,
		PermissionTaskRead,
		PermissionCategoryRead,
		PermissionAuditRead,
		PermissionSecurityRead,
	}

	// Admin permissions
	s.rolePermissions[RoleAdmin] = []Permission{
		PermissionUserRead,
		PermissionUserCreate,
		PermissionUserUpdate,
		PermissionUserUpgrade,
		PermissionUserLock,
		PermissionUserUnlock,
		PermissionTaskRead,
		PermissionTaskCreate,
		PermissionTaskUpdate,
		PermissionTaskDelete,
		PermissionCategoryRead,
		PermissionCategoryCreate,
		PermissionCategoryUpdate,
		PermissionCategoryDelete,
		PermissionAuditRead,
		PermissionSecurityRead,
		PermissionSecurityManage,
		PermissionPaymentRead,
		PermissionPaymentProcess,
	}

	// Super admin has all permissions
	s.rolePermissions[RoleSuperAdmin] = []Permission{
		PermissionUserRead,
		PermissionUserCreate,
		PermissionUserUpdate,
		PermissionUserDelete,
		PermissionUserUpgrade,
		PermissionUserLock,
		PermissionUserUnlock,
		PermissionTaskRead,
		PermissionTaskCreate,
		PermissionTaskUpdate,
		PermissionTaskDelete,
		PermissionCategoryRead,
		PermissionCategoryCreate,
		PermissionCategoryUpdate,
		PermissionCategoryDelete,
		PermissionAuditRead,
		PermissionSecurityRead,
		PermissionSecurityManage,
		PermissionPaymentRead,
		PermissionPaymentProcess,
		PermissionAdminFull,
	}
}

// HasPermission checks if a role has a specific permission
func (s *AccessControlService) HasPermission(role Role, permission Permission) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	permissions, exists := s.rolePermissions[role]
	if !exists {
		return false
	}

	for _, p := range permissions {
		if p == permission {
			return true
		}
	}

	return false
}

// GetRolePermissions returns all permissions for a role
func (s *AccessControlService) GetRolePermissions(role Role) []Permission {
	s.mu.RLock()
	defer s.mu.RUnlock()

	permissions, exists := s.rolePermissions[role]
	if !exists {
		return []Permission{}
	}

	// Return a copy
	result := make([]Permission, len(permissions))
	copy(result, permissions)
	return result
}

// CheckAccess verifies if a user has access to perform an action
func (s *AccessControlService) CheckAccess(userID string, permission Permission) (bool, error) {
	// Get user role from database
	role, err := s.getUserRole(userID)
	if err != nil {
		return false, err
	}

	return s.HasPermission(role, permission), nil
}

// getUserRole fetches user role from database
func (s *AccessControlService) getUserRole(userID string) (Role, error) {
	db := s.connManager.GetReadDB()
	if db == nil {
		db = database.DB
	}

	var userType string
	err := db.Table("users").
		Select("user_type").
		Where("id = ?", userID).
		Scan(&userType).Error

	if err != nil {
		return "", err
	}

	switch userType {
	case "regular":
		return RoleUser, nil
	case "vip":
		return RoleVIP, nil
	case "admin":
		return RoleAdmin, nil
	case "superadmin":
		return RoleSuperAdmin, nil
	default:
		return RoleUser, nil
	}
}

// EnforceAccess returns error if user doesn't have permission
func (s *AccessControlService) EnforceAccess(userID string, permission Permission) error {
	hasAccess, err := s.CheckAccess(userID, permission)
	if err != nil {
		return fmt.Errorf("failed to check access: %w", err)
	}

	if !hasAccess {
		return errors.New("access denied: insufficient permissions")
	}

	return nil
}

// CanAccessResource checks if user can access a specific resource
func (s *AccessControlService) CanAccessResource(userID, resourceOwnerID string, permission Permission) (bool, error) {
	// Users can always access their own resources
	if userID == resourceOwnerID {
		return true, nil
	}

	// Check if user has admin permission
	hasAdmin, err := s.CheckAccess(userID, PermissionAdminFull)
	if err != nil {
		return false, err
	}

	if hasAdmin {
		return true, nil
	}

	// Check specific permission
	return s.CheckAccess(userID, permission)
}

// GetDBForOperation returns appropriate database connection based on operation type
func (s *AccessControlService) GetDBForOperation(operationType string) *gorm.DB {
	switch operationType {
	case "read", "select", "list", "get":
		return s.connManager.GetReadDB()
	case "create", "update", "insert":
		return s.connManager.GetAppDB()
	case "delete", "migrate", "admin":
		return s.connManager.GetAdminDB()
	default:
		return s.connManager.GetAppDB()
	}
}

// ExecuteWithRole executes a function with specific database role
func (s *AccessControlService) ExecuteWithRole(role database.DBRole, fn func(*gorm.DB) error) error {
	db := s.connManager.GetDB(role)
	if db == nil {
		return errors.New("database connection not available for role")
	}
	return fn(db)
}

// StoredProcedureResult holds result from stored procedure
type StoredProcedureResult struct {
	Success bool
	Message string
}

// CallChangePassword calls sp_change_password stored procedure
func (s *AccessControlService) CallChangePassword(userID, newPasswordHash string) (*StoredProcedureResult, error) {
	db := s.connManager.GetAppDB()
	if db == nil {
		db = database.DB
	}

	var success bool
	var message string

	err := db.Raw("CALL sp_change_password(?, ?, @success, @message)", userID, newPasswordHash).Error
	if err != nil {
		return nil, err
	}

	err = db.Raw("SELECT @success, @message").Row().Scan(&success, &message)
	if err != nil {
		return nil, err
	}

	return &StoredProcedureResult{Success: success, Message: message}, nil
}

// CallUpgradeToVIP calls sp_upgrade_to_vip stored procedure
func (s *AccessControlService) CallUpgradeToVIP(userID string, durationDays int, adminUserID string) (*StoredProcedureResult, error) {
	db := s.connManager.GetAdminDB()
	if db == nil {
		db = database.DB
	}

	var success bool
	var message string

	err := db.Raw("CALL sp_upgrade_to_vip(?, ?, ?, @success, @message)", userID, durationDays, adminUserID).Error
	if err != nil {
		return nil, err
	}

	err = db.Raw("SELECT @success, @message").Row().Scan(&success, &message)
	if err != nil {
		return nil, err
	}

	return &StoredProcedureResult{Success: success, Message: message}, nil
}

// CallLockAccount calls sp_lock_account stored procedure
func (s *AccessControlService) CallLockAccount(userID, reason string, durationMinutes int, adminUserID string) (*StoredProcedureResult, error) {
	db := s.connManager.GetAdminDB()
	if db == nil {
		db = database.DB
	}

	var success bool
	var message string

	err := db.Raw("CALL sp_lock_account(?, ?, ?, ?, @success, @message)", userID, reason, durationMinutes, adminUserID).Error
	if err != nil {
		return nil, err
	}

	err = db.Raw("SELECT @success, @message").Row().Scan(&success, &message)
	if err != nil {
		return nil, err
	}

	return &StoredProcedureResult{Success: success, Message: message}, nil
}

// CallUnlockAccount calls sp_unlock_account stored procedure
func (s *AccessControlService) CallUnlockAccount(userID, adminUserID string) (*StoredProcedureResult, error) {
	db := s.connManager.GetAdminDB()
	if db == nil {
		db = database.DB
	}

	var success bool
	var message string

	err := db.Raw("CALL sp_unlock_account(?, ?, @success, @message)", userID, adminUserID).Error
	if err != nil {
		return nil, err
	}

	err = db.Raw("SELECT @success, @message").Row().Scan(&success, &message)
	if err != nil {
		return nil, err
	}

	return &StoredProcedureResult{Success: success, Message: message}, nil
}

// CallSoftDeleteUser calls sp_soft_delete_user stored procedure
func (s *AccessControlService) CallSoftDeleteUser(userID, adminUserID string) (*StoredProcedureResult, error) {
	db := s.connManager.GetAdminDB()
	if db == nil {
		db = database.DB
	}

	var success bool
	var message string

	err := db.Raw("CALL sp_soft_delete_user(?, ?, @success, @message)", userID, adminUserID).Error
	if err != nil {
		return nil, err
	}

	err = db.Raw("SELECT @success, @message").Row().Scan(&success, &message)
	if err != nil {
		return nil, err
	}

	return &StoredProcedureResult{Success: success, Message: message}, nil
}

// UserSecurityStatus holds user security information
type UserSecurityStatus struct {
	ID                   string     `json:"id"`
	Username             string     `json:"username"`
	MFAEnabled           bool       `json:"mfa_enabled"`
	FailedLoginAttempts  int        `json:"failed_login_attempts"`
	LockedUntil          *time.Time `json:"locked_until"`
	PasswordChangedAt    *time.Time `json:"password_changed_at"`
	LastLoginAt          *time.Time `json:"last_login_at"`
	LastLoginIP          *string    `json:"last_login_ip"`
	SecurityStatus       string     `json:"security_status"`
	RecentSecurityEvents int        `json:"recent_security_events"`
	RecentActivities     int        `json:"recent_activities"`
}

// GetUserSecurityStatus calls sp_get_user_security_status stored procedure
func (s *AccessControlService) GetUserSecurityStatus(userID string) (*UserSecurityStatus, error) {
	db := s.connManager.GetReadDB()
	if db == nil {
		db = database.DB
	}

	var status UserSecurityStatus
	err := db.Raw("CALL sp_get_user_security_status(?)", userID).Scan(&status).Error
	if err != nil {
		return nil, err
	}

	return &status, nil
}

// CleanupExpiredData calls sp_cleanup_expired_data stored procedure
func (s *AccessControlService) CleanupExpiredData(ctx context.Context) (map[string]int, error) {
	db := s.connManager.GetAdminDB()
	if db == nil {
		db = database.DB
	}

	var blockedCleaned, resetsCleaned int
	err := db.WithContext(ctx).
		Raw("CALL sp_cleanup_expired_data()").
		Row().
		Scan(&blockedCleaned, &resetsCleaned)

	if err != nil {
		return nil, err
	}

	return map[string]int{
		"blocked_ips_cleaned":     blockedCleaned,
		"password_resets_cleaned": resetsCleaned,
	}, nil
}

// StartCleanupScheduler starts periodic cleanup of expired data
func (s *AccessControlService) StartCleanupScheduler(interval time.Duration) {
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		for range ticker.C {
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
			result, err := s.CleanupExpiredData(ctx)
			cancel()

			if err != nil {
				log.Printf("⚠️ Cleanup failed: %v", err)
			} else {
				log.Printf("🧹 Cleanup completed: %v", result)
			}
		}
	}()
}
