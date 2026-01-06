package utils

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/workradar/server/internal/config"
)

type Claims struct {
	UserID   string `json:"user_id"`
	Email    string `json:"email"`
	UserType string `json:"user_type"`
	Type     string `json:"type"` // "access" or "refresh"
	jwt.RegisteredClaims
}

// GenerateAccessToken membuat access token (24 hours for development)
func GenerateAccessToken(userID, email, userType string) (string, error) {
	expirationTime := time.Now().Add(24 * time.Hour) // Extended for better UX

	claims := &Claims{
		UserID:   userID,
		Email:    email,
		UserType: userType,
		Type:     "access",
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.New().String(), // JTI untuk blacklisting
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(config.AppConfig.JWTSecret))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

// GenerateRefreshToken membuat long-lived refresh token (7 days)
func GenerateRefreshToken(userID, email, userType string) (string, error) {
	expirationTime := time.Now().Add(7 * 24 * time.Hour)

	claims := &Claims{
		UserID:   userID,
		Email:    email,
		UserType: userType,
		Type:     "refresh",
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.New().String(), // JTI untuk blacklisting
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(config.AppConfig.JWTSecret))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

// GenerateToken (legacy) - untuk backward compatibility
// Deprecated: Use GenerateAccessToken and GenerateRefreshToken instead
func GenerateToken(userID, email, userType string) (string, error) {
	return GenerateAccessToken(userID, email, userType)
}

// ValidateToken memvalidasi JWT token dan return claims
func ValidateToken(tokenString string) (*Claims, error) {
	claims := &Claims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(config.AppConfig.JWTSecret), nil
	})

	if err != nil {
		return nil, err
	}

	if !token.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil
}

// GetJTI extracts JTI from token string
func GetJTI(tokenString string) (string, error) {
	claims, err := ValidateToken(tokenString)
	if err != nil {
		return "", err
	}

	return claims.ID, nil
}

// MFAClaims for temporary MFA token
type MFAClaims struct {
	UserID string `json:"user_id"`
	Type   string `json:"type"`
	jwt.RegisteredClaims
}

// GenerateMFAToken creates a temporary token for MFA verification (5 minutes)
func GenerateMFAToken(userID string) (string, error) {
	expirationTime := time.Now().Add(5 * time.Minute) // Short-lived

	claims := &MFAClaims{
		UserID: userID,
		Type:   "mfa_pending",
		RegisteredClaims: jwt.RegisteredClaims{
			ID:        uuid.New().String(),
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString([]byte(config.AppConfig.JWTSecret))
	if err != nil {
		return "", err
	}

	return tokenString, nil
}

// ValidateMFAToken validates the temporary MFA token
func ValidateMFAToken(tokenString string) (*MFAClaims, error) {
	claims := &MFAClaims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		return []byte(config.AppConfig.JWTSecret), nil
	})

	if err != nil {
		return nil, err
	}

	if !token.Valid {
		return nil, errors.New("invalid MFA token")
	}

	if claims.Type != "mfa_pending" {
		return nil, errors.New("invalid token type")
	}

	return claims, nil
}
