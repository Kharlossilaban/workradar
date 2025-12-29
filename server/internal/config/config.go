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

	// Optional - FCM
	FCMServerKey string

	// Optional - Midtrans
	MidtransServerKey   string
	MidtransClientKey   string
	MidtransIsProduction bool
}

var AppConfig *Config

// Load membaca environment variables dan membuat config
func Load() error {
	// Load .env file jika ada
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, using system environment variables")
	}

	AppConfig = &Config{
		Port: getEnv("PORT", "8080"),
		Env:  getEnv("ENV", "development"),

		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnv("DB_PORT", "3306"),
		DBUser:     getEnv("DB_USER", "root"),
		DBPassword: getEnv("DB_PASSWORD", ""),
		DBName:     getEnv("DB_NAME", "workradar"),

		JWTSecret: getEnv("JWT_SECRET", "default-secret-key"),
		JWTExpiry: getEnv("JWT_EXPIRY", "24h"),

		AllowedOrigins: getEnv("ALLOWED_ORIGINS", "*"),

		// Optional
		GoogleClientID:     getEnv("GOOGLE_CLIENT_ID", ""),
		GoogleClientSecret: getEnv("GOOGLE_CLIENT_SECRET", ""),
		GoogleRedirectURL:  getEnv("GOOGLE_REDIRECT_URL", ""),

		WeatherAPIKey: getEnv("WEATHER_API_KEY", ""),
		FCMServerKey:  getEnv("FCM_SERVER_KEY", ""),

		MidtransServerKey:    getEnv("MIDTRANS_SERVER_KEY", ""),
		MidtransClientKey:    getEnv("MIDTRANS_CLIENT_KEY", ""),
		MidtransIsProduction: getEnvAsBool("MIDTRANS_IS_PRODUCTION", false),
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

func getEnvAsBool(key string, defaultValue bool) bool {
	valStr := getEnv(key, "")
	if val, err := strconv.ParseBool(valStr); err == nil {
		return val
	}
	return defaultValue
}
