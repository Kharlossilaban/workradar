package config

import (
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

type Config struct {
	// Server
	Port string
	Env  string

	// Database
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string

	// JWT
	JWTSecret string
	JWTExpiry string

	// CORS
	AllowedOrigins string

	// Optional - Google OAuth
	GoogleClientID     string
	GoogleClientSecret string
	GoogleRedirectURL  string

	// Optional - Weather API
	WeatherAPIKey string

	// Optional - Firebase FCM (HTTP v1 API)
	FirebaseProjectID       string
	FirebaseCredentialsFile string

	// Optional - Midtrans
	MidtransServerKey    string
	MidtransClientKey    string
	MidtransIsProduction bool

	// Optional - Gemini AI
	GeminiAPIKey string

	// Optional - SMTP Email
	SMTPHost      string
	SMTPPort      string
	SMTPUsername  string
	SMTPPassword  string
	SMTPFromName  string
	SMTPFromEmail string
}

var AppConfig *Config

// Load membaca environment variables dan membuat config
func Load() error {
	// Debug: Print current working directory
	wd, err := os.Getwd()
	if err != nil {
		log.Printf("❌ Error getting working directory: %v\n", err)
	} else {
		log.Printf("📁 Current working directory: %s\n", wd)
	}

	// Check if .env file exists
	envPath := ".env"
	if _, err := os.Stat(envPath); err == nil {
		log.Printf("✅ .env file found at: %s\n", envPath)
	} else {
		log.Printf("❌ .env file NOT found: %v\n", err)
	}

	// Load .env file jika ada (tidak error jika tidak ditemukan)
	_ = godotenv.Load() // Ignore error, use system env vars if .env not found
	log.Println("✅ Using environment variables (from .env or system)")

	// Debug: Print DB password status
	dbPass := os.Getenv("DB_PASSWORD")
	if dbPass == "" {
		log.Println("❌ WARNING: DB_PASSWORD is empty!")
	} else {
		log.Printf("✅ DB_PASSWORD loaded (length: %d characters)\n", len(dbPass))
	}

	AppConfig = &Config{
		Port: getEnv("PORT", "8080"),
		Env:  getEnv("ENV", "production"),

		// Support Railway MySQL environment variables
		DBHost:     getFirstEnv([]string{"DB_HOST", "MYSQLHOST"}, "localhost"),
		DBPort:     getFirstEnv([]string{"DB_PORT", "MYSQLPORT"}, "3306"),
		DBUser:     getFirstEnv([]string{"DB_USER", "MYSQLUSER"}, "root"),
		DBPassword: getFirstEnv([]string{"DB_PASSWORD", "MYSQLPASSWORD"}, ""),
		DBName:     getFirstEnv([]string{"DB_NAME", "MYSQLDATABASE"}, "railway"),

		JWTSecret: getEnv("JWT_SECRET", "default-secret-key"),
		JWTExpiry: getEnv("JWT_EXPIRY", "24h"),

		AllowedOrigins: getEnv("ALLOWED_ORIGINS", "*"),

		// Optional
		GoogleClientID:     getEnv("GOOGLE_CLIENT_ID", ""),
		GoogleClientSecret: getEnv("GOOGLE_CLIENT_SECRET", ""),
		GoogleRedirectURL:  getEnv("GOOGLE_REDIRECT_URL", ""),

		WeatherAPIKey: getEnv("WEATHER_API_KEY", ""),

		FirebaseProjectID:       getEnv("FIREBASE_PROJECT_ID", ""),
		FirebaseCredentialsFile: getEnv("FIREBASE_CREDENTIALS_FILE", ""),

		MidtransServerKey:    getEnv("MIDTRANS_SERVER_KEY", ""),
		MidtransClientKey:    getEnv("MIDTRANS_CLIENT_KEY", ""),
		MidtransIsProduction: getEnvAsBool("MIDTRANS_IS_PRODUCTION", false),

		GeminiAPIKey: getEnv("GEMINI_API_KEY", ""),

		// SMTP Email Configuration
		SMTPHost:      getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:      getEnv("SMTP_PORT", "587"),
		SMTPUsername:  getEnv("SMTP_USERNAME", ""),
		SMTPPassword:  getEnv("SMTP_PASSWORD", ""),
		SMTPFromName:  getEnv("SMTP_FROM_NAME", "Workradar"),
		SMTPFromEmail: getEnv("SMTP_FROM_EMAIL", "noreply@workradar.app"),
	}

	// Debug: Print final DB password status
	if AppConfig.DBPassword == "" {
		log.Println("❌ CRITICAL: AppConfig.DBPassword is EMPTY after loading!")
	} else {
		log.Printf("✅ AppConfig.DBPassword set (length: %d characters)\n", len(AppConfig.DBPassword))
	}

	return nil
}

// GetDSN returns MySQL connection string
func (c *Config) GetDSN() string {
	return fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		c.DBUser,
		c.DBPassword,
		c.DBHost,
		c.DBPort,
		c.DBName,
	)
}

// Helper functions
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getFirstEnv tries multiple environment variable keys and returns the first non-empty value
func getFirstEnv(keys []string, defaultValue string) string {
	for _, key := range keys {
		if value := os.Getenv(key); value != "" {
			return value
		}
	}
	return defaultValue
}

func getEnvAsBool(key string, defaultValue bool) bool {
	valStr := getEnv(key, "")
	if val, err := strconv.ParseBool(valStr); err == nil {
		return val
	}
	return defaultValue
}
