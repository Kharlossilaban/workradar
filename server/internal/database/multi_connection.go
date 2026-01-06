package database

import (
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	"github.com/workradar/server/internal/config"
	gormMysql "gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

// DBRole represents database user role
type DBRole string

const (
	// DBRoleRead for read-only operations (reporting, analytics)
	DBRoleRead DBRole = "read"
	// DBRoleApp for application operations (normal CRUD except delete users)
	DBRoleApp DBRole = "app"
	// DBRoleAdmin for administrative operations (migrations, maintenance)
	DBRoleAdmin DBRole = "admin"
)

// MultiConnectionManager manages multiple database connections with different privileges
type MultiConnectionManager struct {
	mu          sync.RWMutex
	connections map[DBRole]*gorm.DB
	enabled     bool
}

var (
	connManager     *MultiConnectionManager
	connManagerOnce sync.Once
)

// GetConnectionManager returns singleton connection manager
func GetConnectionManager() *MultiConnectionManager {
	connManagerOnce.Do(func() {
		connManager = &MultiConnectionManager{
			connections: make(map[DBRole]*gorm.DB),
			enabled:     os.Getenv("DB_MULTI_USER_ENABLED") == "true",
		}
	})
	return connManager
}

// Initialize sets up all database connections
func (m *MultiConnectionManager) Initialize() error {
	if !m.enabled {
		log.Println("⚠️ Multi-user database connections disabled (single connection mode)")
		// Use default connection for all roles
		m.connections[DBRoleRead] = DB
		m.connections[DBRoleApp] = DB
		m.connections[DBRoleAdmin] = DB
		return nil
	}

	log.Println("🔐 Initializing multi-user database connections...")

	// Initialize read-only connection
	if err := m.initConnection(DBRoleRead); err != nil {
		log.Printf("⚠️ Failed to initialize read connection: %v, using default", err)
		m.connections[DBRoleRead] = DB
	}

	// Initialize app connection
	if err := m.initConnection(DBRoleApp); err != nil {
		log.Printf("⚠️ Failed to initialize app connection: %v, using default", err)
		m.connections[DBRoleApp] = DB
	}

	// Initialize admin connection
	if err := m.initConnection(DBRoleAdmin); err != nil {
		log.Printf("⚠️ Failed to initialize admin connection: %v, using default", err)
		m.connections[DBRoleAdmin] = DB
	}

	log.Println("✅ Multi-user database connections initialized")
	return nil
}

// initConnection initializes a single connection for a role
func (m *MultiConnectionManager) initConnection(role DBRole) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	var user, password string

	switch role {
	case DBRoleRead:
		user = os.Getenv("DB_USER_READ")
		password = os.Getenv("DB_PASSWORD_READ")
		if user == "" {
			user = "workradar_read"
		}
	case DBRoleApp:
		user = os.Getenv("DB_USER_APP")
		password = os.Getenv("DB_PASSWORD_APP")
		if user == "" {
			user = "workradar_app"
		}
	case DBRoleAdmin:
		user = os.Getenv("DB_USER_ADMIN")
		password = os.Getenv("DB_PASSWORD_ADMIN")
		if user == "" {
			user = "workradar_admin"
		}
	default:
		return fmt.Errorf("unknown database role: %s", role)
	}

	if password == "" {
		return fmt.Errorf("password not set for role: %s", role)
	}

	// Build DSN
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		user,
		password,
		config.AppConfig.DBHost,
		config.AppConfig.DBPort,
		config.AppConfig.DBName,
	)

	// Add TLS if enabled
	if os.Getenv("DB_SSL_ENABLED") == "true" {
		dsn += "&tls=custom"
	}

	// Configure logger based on role
	var logMode logger.LogLevel
	switch role {
	case DBRoleRead:
		logMode = logger.Silent // Less verbose for read operations
	case DBRoleApp:
		logMode = logger.Warn
	case DBRoleAdmin:
		logMode = logger.Info
	}

	db, err := gorm.Open(gormMysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logMode),
	})
	if err != nil {
		return fmt.Errorf("failed to connect as %s: %w", role, err)
	}

	// Configure connection pool based on role
	sqlDB, err := db.DB()
	if err != nil {
		return err
	}

	switch role {
	case DBRoleRead:
		// Read connections can have more idle connections for analytics
		sqlDB.SetMaxIdleConns(20)
		sqlDB.SetMaxOpenConns(50)
	case DBRoleApp:
		// App connections are the main workload
		sqlDB.SetMaxIdleConns(10)
		sqlDB.SetMaxOpenConns(100)
	case DBRoleAdmin:
		// Admin connections are rarely used
		sqlDB.SetMaxIdleConns(2)
		sqlDB.SetMaxOpenConns(10)
	}

	sqlDB.SetConnMaxLifetime(time.Hour)
	sqlDB.SetConnMaxIdleTime(10 * time.Minute)

	m.connections[role] = db
	log.Printf("✅ Database connection for role '%s' established", role)
	return nil
}

// GetDB returns database connection for specific role
func (m *MultiConnectionManager) GetDB(role DBRole) *gorm.DB {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if db, exists := m.connections[role]; exists {
		return db
	}

	// Fallback to default DB
	return DB
}

// GetReadDB returns read-only database connection
func (m *MultiConnectionManager) GetReadDB() *gorm.DB {
	return m.GetDB(DBRoleRead)
}

// GetAppDB returns application database connection
func (m *MultiConnectionManager) GetAppDB() *gorm.DB {
	return m.GetDB(DBRoleApp)
}

// GetAdminDB returns admin database connection
func (m *MultiConnectionManager) GetAdminDB() *gorm.DB {
	return m.GetDB(DBRoleAdmin)
}

// Close closes all connections
func (m *MultiConnectionManager) Close() error {
	m.mu.Lock()
	defer m.mu.Unlock()

	var lastErr error
	for role, db := range m.connections {
		if db != DB { // Don't close the main DB connection
			sqlDB, err := db.DB()
			if err != nil {
				lastErr = err
				continue
			}
			if err := sqlDB.Close(); err != nil {
				lastErr = err
				log.Printf("⚠️ Failed to close connection for role %s: %v", role, err)
			}
		}
	}

	return lastErr
}

// GetStats returns connection statistics for all roles
func (m *MultiConnectionManager) GetStats() map[string]interface{} {
	m.mu.RLock()
	defer m.mu.RUnlock()

	stats := make(map[string]interface{})

	for role, db := range m.connections {
		sqlDB, err := db.DB()
		if err != nil {
			stats[string(role)] = map[string]string{"error": err.Error()}
			continue
		}

		dbStats := sqlDB.Stats()
		stats[string(role)] = map[string]interface{}{
			"max_open_connections": dbStats.MaxOpenConnections,
			"open_connections":     dbStats.OpenConnections,
			"in_use":               dbStats.InUse,
			"idle":                 dbStats.Idle,
			"wait_count":           dbStats.WaitCount,
			"wait_duration":        dbStats.WaitDuration.String(),
		}
	}

	return stats
}

// IsMultiUserEnabled returns whether multi-user mode is enabled
func (m *MultiConnectionManager) IsMultiUserEnabled() bool {
	return m.enabled
}

// HealthCheck performs health check on all connections
func (m *MultiConnectionManager) HealthCheck() map[string]bool {
	m.mu.RLock()
	defer m.mu.RUnlock()

	health := make(map[string]bool)

	for role, db := range m.connections {
		sqlDB, err := db.DB()
		if err != nil {
			health[string(role)] = false
			continue
		}

		err = sqlDB.Ping()
		health[string(role)] = err == nil
	}

	return health
}
