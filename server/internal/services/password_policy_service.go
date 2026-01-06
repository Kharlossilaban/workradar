package services

import (
	"errors"
	"regexp"
	"strings"
	"unicode"
)

// PasswordPolicy defines password requirements
type PasswordPolicy struct {
	MinLength               int
	RequireUppercase        bool
	RequireLowercase        bool
	RequireDigit            bool
	RequireSpecial          bool
	SpecialCharacters       string
	MaxConsecutiveRepeats   int // Max consecutive same characters (e.g., "aaa" = 3)
	DisallowCommonPasswords bool
}

// DefaultPasswordPolicy returns the recommended password policy
func DefaultPasswordPolicy() PasswordPolicy {
	return PasswordPolicy{
		MinLength:               8,
		RequireUppercase:        true,
		RequireLowercase:        true,
		RequireDigit:            true,
		RequireSpecial:          true,
		SpecialCharacters:       "!@#$%^&*()_+-=[]{}|;:',.<>?/`~",
		MaxConsecutiveRepeats:   3,
		DisallowCommonPasswords: true,
	}
}

// StrictPasswordPolicy returns stricter password requirements for VIP or admin
func StrictPasswordPolicy() PasswordPolicy {
	return PasswordPolicy{
		MinLength:               12,
		RequireUppercase:        true,
		RequireLowercase:        true,
		RequireDigit:            true,
		RequireSpecial:          true,
		SpecialCharacters:       "!@#$%^&*()_+-=[]{}|;:',.<>?/`~",
		MaxConsecutiveRepeats:   2,
		DisallowCommonPasswords: true,
	}
}

// PasswordValidationResult contains validation result details
type PasswordValidationResult struct {
	IsValid  bool     `json:"is_valid"`
	Strength string   `json:"strength"` // weak, medium, strong, very_strong
	Score    int      `json:"score"`    // 0-100
	Errors   []string `json:"errors"`
	Warnings []string `json:"warnings"`
}

// ValidatePassword validates a password against the policy
func ValidatePassword(password string, policy PasswordPolicy) PasswordValidationResult {
	result := PasswordValidationResult{
		IsValid:  true,
		Errors:   []string{},
		Warnings: []string{},
		Score:    0,
	}

	// Check minimum length
	if len(password) < policy.MinLength {
		result.IsValid = false
		result.Errors = append(result.Errors,
			customSprintf("Password minimal %d karakter (saat ini: %d karakter)", policy.MinLength, len(password)))
	} else {
		result.Score += 20
	}

	// Check for uppercase
	hasUpper := false
	for _, c := range password {
		if unicode.IsUpper(c) {
			hasUpper = true
			break
		}
	}
	if policy.RequireUppercase && !hasUpper {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password harus mengandung huruf besar (A-Z)")
	} else if hasUpper {
		result.Score += 15
	}

	// Check for lowercase
	hasLower := false
	for _, c := range password {
		if unicode.IsLower(c) {
			hasLower = true
			break
		}
	}
	if policy.RequireLowercase && !hasLower {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password harus mengandung huruf kecil (a-z)")
	} else if hasLower {
		result.Score += 15
	}

	// Check for digits
	hasDigit := false
	for _, c := range password {
		if unicode.IsDigit(c) {
			hasDigit = true
			break
		}
	}
	if policy.RequireDigit && !hasDigit {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password harus mengandung angka (0-9)")
	} else if hasDigit {
		result.Score += 15
	}

	// Check for special characters
	hasSpecial := false
	for _, c := range password {
		if strings.ContainsRune(policy.SpecialCharacters, c) {
			hasSpecial = true
			break
		}
	}
	if policy.RequireSpecial && !hasSpecial {
		result.IsValid = false
		result.Errors = append(result.Errors,
			customSprintf("Password harus mengandung karakter spesial (%s)", policy.SpecialCharacters[:10]+"..."))
	} else if hasSpecial {
		result.Score += 15
	}

	// Check for consecutive repeating characters
	if policy.MaxConsecutiveRepeats > 0 {
		consecutiveCount := 1
		var lastChar rune
		for _, c := range password {
			if c == lastChar {
				consecutiveCount++
				if consecutiveCount > policy.MaxConsecutiveRepeats {
					result.IsValid = false
					result.Errors = append(result.Errors,
						customSprintf("Password tidak boleh mengandung lebih dari %d karakter berulang berturut-turut", policy.MaxConsecutiveRepeats))
					break
				}
			} else {
				consecutiveCount = 1
			}
			lastChar = c
		}
	}

	// Check for common passwords
	if policy.DisallowCommonPasswords && isCommonPassword(password) {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password terlalu umum dan mudah ditebak")
	}

	// Check for sequential characters
	if hasSequentialChars(password) {
		result.Warnings = append(result.Warnings, "Password mengandung karakter berurutan (misal: 123, abc)")
		result.Score -= 10
	}

	// Bonus for length
	if len(password) >= 12 {
		result.Score += 10
	}
	if len(password) >= 16 {
		result.Score += 10
	}

	// Cap score at 100
	if result.Score > 100 {
		result.Score = 100
	}
	if result.Score < 0 {
		result.Score = 0
	}

	// Determine strength
	switch {
	case result.Score >= 80:
		result.Strength = "very_strong"
	case result.Score >= 60:
		result.Strength = "strong"
	case result.Score >= 40:
		result.Strength = "medium"
	default:
		result.Strength = "weak"
	}

	return result
}

// customSprintf is a simple sprintf replacement
func customSprintf(format string, args ...interface{}) string {
	result := format
	for _, arg := range args {
		switch v := arg.(type) {
		case int:
			result = strings.Replace(result, "%d", intToString(v), 1)
		case string:
			result = strings.Replace(result, "%s", v, 1)
		}
	}
	return result
}

func intToString(n int) string {
	if n == 0 {
		return "0"
	}

	negative := n < 0
	if negative {
		n = -n
	}

	digits := make([]byte, 0, 20)
	for n > 0 {
		digits = append(digits, byte('0'+n%10))
		n /= 10
	}

	// Reverse
	for i, j := 0, len(digits)-1; i < j; i, j = i+1, j-1 {
		digits[i], digits[j] = digits[j], digits[i]
	}

	if negative {
		return "-" + string(digits)
	}
	return string(digits)
}

// isCommonPassword checks if password is in common password list
func isCommonPassword(password string) bool {
	lowerPassword := strings.ToLower(password)

	commonPasswords := []string{
		// Top 100 most common passwords
		"password", "123456", "12345678", "qwerty", "abc123",
		"monkey", "1234567", "letmein", "trustno1", "dragon",
		"baseball", "iloveyou", "master", "sunshine", "ashley",
		"bailey", "passw0rd", "shadow", "123123", "654321",
		"superman", "qazwsx", "michael", "football", "password1",
		"password123", "batman", "login", "admin", "welcome",
		"hello", "charlie", "donald", "password!", "qwerty123",
		"admin123", "root", "toor", "pass", "test",
		"guest", "master123", "changeme", "123456789", "12345",
		"1234", "123", "1", "password1!", "!@#$%^&*",
		// Indonesian common passwords
		"rahasia", "cinta", "sayang", "indonesia", "jakarta",
		"abcdef", "qweasd", "123qwe", "q1w2e3r4", "asdfgh",
		// Keyboard patterns
		"qwertyuiop", "asdfghjkl", "zxcvbnm", "1qaz2wsx",
		// Simple patterns
		"aaaaaaaa", "11111111", "00000000",
	}

	for _, common := range commonPasswords {
		if lowerPassword == common {
			return true
		}
	}

	return false
}

// hasSequentialChars checks for sequential characters
func hasSequentialChars(password string) bool {
	sequences := []string{
		"012", "123", "234", "345", "456", "567", "678", "789",
		"abc", "bcd", "cde", "def", "efg", "fgh", "ghi", "hij",
		"ijk", "jkl", "klm", "lmn", "mno", "nop", "opq", "pqr",
		"qrs", "rst", "stu", "tuv", "uvw", "vwx", "wxy", "xyz",
	}

	lowerPassword := strings.ToLower(password)

	for _, seq := range sequences {
		if strings.Contains(lowerPassword, seq) {
			return true
		}
	}

	// Check reverse sequences
	for _, seq := range sequences {
		reversed := reverseString(seq)
		if strings.Contains(lowerPassword, reversed) {
			return true
		}
	}

	return false
}

func reverseString(s string) string {
	runes := []rune(s)
	for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
		runes[i], runes[j] = runes[j], runes[i]
	}
	return string(runes)
}

// GeneratePasswordStrengthFeedback provides user-friendly feedback
func GeneratePasswordStrengthFeedback(result PasswordValidationResult) map[string]interface{} {
	feedback := map[string]interface{}{
		"strength": result.Strength,
		"score":    result.Score,
		"is_valid": result.IsValid,
		"errors":   result.Errors,
		"warnings": result.Warnings,
	}

	// Add color for frontend
	switch result.Strength {
	case "very_strong":
		feedback["color"] = "#4CAF50" // Green
		feedback["message"] = "Password sangat kuat! 💪"
	case "strong":
		feedback["color"] = "#8BC34A" // Light green
		feedback["message"] = "Password kuat 👍"
	case "medium":
		feedback["color"] = "#FF9800" // Orange
		feedback["message"] = "Password cukup, tapi bisa lebih kuat"
	default:
		feedback["color"] = "#F44336" // Red
		feedback["message"] = "Password terlalu lemah ⚠️"
	}

	// Add suggestions
	suggestions := []string{}
	if result.Score < 80 {
		if len(result.Errors) == 0 {
			// Password valid but could be stronger
			suggestions = append(suggestions, "Tambahkan lebih banyak karakter spesial")
			suggestions = append(suggestions, "Gunakan kombinasi kata yang tidak berhubungan")
			suggestions = append(suggestions, "Tambahkan angka di tengah password")
		}
	}
	feedback["suggestions"] = suggestions

	return feedback
}

// ValidatePasswordChange validates password change (checks history, etc)
func ValidatePasswordChange(currentPassword, newPassword string, auditService *AuditService, userID string) error {
	// Validate new password against policy
	result := ValidatePassword(newPassword, DefaultPasswordPolicy())
	if !result.IsValid {
		return errors.New(strings.Join(result.Errors, "; "))
	}

	// Check if new password is same as current
	if currentPassword == newPassword {
		return errors.New("Password baru tidak boleh sama dengan password saat ini")
	}

	// Note: Password history check is done with hashed passwords in auth_service
	// This function validates the plain text password rules only

	return nil
}

// EmailValidator validates email format
type EmailValidator struct {
	pattern *regexp.Regexp
}

// NewEmailValidator creates a new email validator
func NewEmailValidator() *EmailValidator {
	// RFC 5322 compliant email regex (simplified)
	pattern := regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
	return &EmailValidator{pattern: pattern}
}

// Validate validates an email address
func (v *EmailValidator) Validate(email string) error {
	if email == "" {
		return errors.New("Email tidak boleh kosong")
	}

	if len(email) > 254 {
		return errors.New("Email terlalu panjang (maksimal 254 karakter)")
	}

	if !v.pattern.MatchString(email) {
		return errors.New("Format email tidak valid")
	}

	// Check for disposable email domains (optional)
	disposableDomains := []string{
		"mailinator.com", "guerrillamail.com", "temp-mail.org",
		"10minutemail.com", "throwaway.email", "fakeinbox.com",
	}

	parts := strings.Split(email, "@")
	if len(parts) == 2 {
		domain := strings.ToLower(parts[1])
		for _, d := range disposableDomains {
			if domain == d {
				return errors.New("Email dari domain sementara tidak diizinkan")
			}
		}
	}

	return nil
}

// UsernameValidator validates username format
type UsernameValidator struct {
	MinLength int
	MaxLength int
}

// NewUsernameValidator creates a new username validator
func NewUsernameValidator() *UsernameValidator {
	return &UsernameValidator{
		MinLength: 3,
		MaxLength: 50,
	}
}

// Validate validates a username
func (v *UsernameValidator) Validate(username string) error {
	if username == "" {
		return errors.New("Username tidak boleh kosong")
	}

	if len(username) < v.MinLength {
		return errors.New(customSprintf("Username minimal %d karakter", v.MinLength))
	}

	if len(username) > v.MaxLength {
		return errors.New(customSprintf("Username maksimal %d karakter", v.MaxLength))
	}

	// Only allow alphanumeric, underscore, and dot
	for _, c := range username {
		if !unicode.IsLetter(c) && !unicode.IsDigit(c) && c != '_' && c != '.' && c != ' ' {
			return errors.New("Username hanya boleh mengandung huruf, angka, underscore (_), titik (.), dan spasi")
		}
	}

	// Check for reserved usernames
	reserved := []string{
		"admin", "administrator", "root", "system", "support",
		"help", "info", "contact", "sales", "billing",
		"api", "www", "mail", "ftp", "test",
	}

	lowerUsername := strings.ToLower(username)
	for _, r := range reserved {
		if lowerUsername == r {
			return errors.New("Username tidak tersedia")
		}
	}

	return nil
}
