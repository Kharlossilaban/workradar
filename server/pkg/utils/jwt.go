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

// GenerateAccessToken membuat short-lived access token (15 minutes)
func GenerateAccessToken(userID, email, userType string) (string, error) {
	expirationTime := time.Now().Add(15 * time.Minute)

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
