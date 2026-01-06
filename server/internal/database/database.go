package database

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/go-sql-driver/mysql"
	"github.com/workradar/server/internal/config"
	gormMysql "gorm.io/driver/mysql"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

// Connect membuat koneksi ke MySQL database dengan optional SSL/TLS
func Connect() error {
	// Check if SSL is enabled
	sslEnabled := os.Getenv("DB_SSL_ENABLED") == "true"

	var dsn string

	if sslEnabled {
		// Configure TLS
		if err := configureTLS(); err != nil {
			log.Printf("⚠️ TLS configuration failed: %v, falling back to non-TLS", err)
			dsn = config.AppConfig.GetDSN()
		} else {
			dsn = config.AppConfig.GetDSN() + "&tls=custom"
			log.Println("🔒 MySQL SSL/TLS enabled")
		}
	} else {
		dsn = config.AppConfig.GetDSN()
		log.Println("⚠️ MySQL SSL/TLS disabled (set DB_SSL_ENABLED=true for production)")
	}

	var err error
	DB, err = gorm.Open(gormMysql.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	})

	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	// Configure connection pool
	sqlDB, err := DB.DB()
	if err != nil {
		return fmt.Errorf("failed to get sql.DB: %w", err)
	}

	// Connection pool settings for security and performance
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)
	sqlDB.SetConnMaxLifetime(time.Hour)
	sqlDB.SetConnMaxIdleTime(10 * time.Minute)

	log.Println("✅ Database connected successfully")
	return nil
}

// configureTLS sets up TLS configuration for MySQL connection
func configureTLS() error {
	// Get certificate paths from environment
	caCertPath := os.Getenv("DB_SSL_CA")
	clientCertPath := os.Getenv("DB_SSL_CERT")
	clientKeyPath := os.Getenv("DB_SSL_KEY")

	// Create TLS config
	tlsConfig := &tls.Config{
		MinVersion: tls.VersionTLS12,
	}

	// Load CA certificate if provided
	if caCertPath != "" {
		caCert, err := os.ReadFile(caCertPath)
		if err != nil {
			return fmt.Errorf("failed to read CA certificate: %w", err)
		}

		caCertPool := x509.NewCertPool()
		if !caCertPool.AppendCertsFromPEM(caCert) {
			return fmt.Errorf("failed to parse CA certificate")
		}
		tlsConfig.RootCAs = caCertPool
	} else {
		// If no CA cert, skip verification (NOT recommended for production)
		tlsConfig.InsecureSkipVerify = true
		log.Println("⚠️ DB_SSL_CA not set, using InsecureSkipVerify (NOT recommended for production)")
	}

	// Load client certificate if provided (for mutual TLS)
	if clientCertPath != "" && clientKeyPath != "" {
		cert, err := tls.LoadX509KeyPair(clientCertPath, clientKeyPath)
		if err != nil {
			return fmt.Errorf("failed to load client certificate: %w", err)
		}
		tlsConfig.Certificates = []tls.Certificate{cert}
		log.Println("🔐 MySQL mutual TLS (client certificate) enabled")
	}

	// Register custom TLS config
	if err := mysql.RegisterTLSConfig("custom", tlsConfig); err != nil {
		return fmt.Errorf("failed to register TLS config: %w", err)
	}

	return nil
}

// Close menutup koneksi database
func Close() error {
	sqlDB, err := DB.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}

// GetDBStats returns database connection statistics as map
func GetDBStats() map[string]interface{} {
	sqlDB, err := DB.DB()
	if err != nil {
		return nil
	}

	stats := sqlDB.Stats()
	return map[string]interface{}{
		"max_open_connections": stats.MaxOpenConnections,
		"open_connections":     stats.OpenConnections,
		"in_use":               stats.InUse,
		"idle":                 stats.Idle,
		"wait_count":           stats.WaitCount,
		"wait_duration":        stats.WaitDuration.String(),
		"max_idle_closed":      stats.MaxIdleClosed,
		"max_lifetime_closed":  stats.MaxLifetimeClosed,
	}
}

// DBStats represents database connection statistics
type DBStats struct {
	MaxOpenConnections int
	OpenConnections    int
	InUse              int
	Idle               int
	WaitCount          int64
	WaitDuration       time.Duration
	MaxIdleClosed      int64
	MaxLifetimeClosed  int64
}

// GetDBStatsStruct returns database connection statistics as struct
func GetDBStatsStruct() *DBStats {
	sqlDB, err := DB.DB()
	if err != nil {
		return nil
	}

	stats := sqlDB.Stats()
	return &DBStats{
		MaxOpenConnections: stats.MaxOpenConnections,
		OpenConnections:    stats.OpenConnections,
		InUse:              stats.InUse,
		Idle:               stats.Idle,
		WaitCount:          stats.WaitCount,
		WaitDuration:       stats.WaitDuration,
		MaxIdleClosed:      stats.MaxIdleClosed,
		MaxLifetimeClosed:  stats.MaxLifetimeClosed,
	}
}
