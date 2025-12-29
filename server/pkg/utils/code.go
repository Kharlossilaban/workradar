package utils

import (
	"fmt"
	"math/rand"
	"time"
)

// GenerateVerificationCode membuat 6 digit code untuk password reset
func GenerateVerificationCode() string {
	rand.Seed(time.Now().UnixNano())
	code := rand.Intn(900000) + 100000 // 100000-999999
	return fmt.Sprintf("%06d", code)
}
