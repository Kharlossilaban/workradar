package utils

import (
	"html"
	"regexp"
	"strings"
	"unicode"
)

// ============================================
// SANITIZATION & INPUT VALIDATION
// Minggu 6: SQL Injection Prevention & Input Validation
// ============================================

// SanitizationConfig holds configuration for sanitization
type SanitizationConfig struct {
	MaxLength      int
	AllowHTML      bool
	AllowNewlines  bool
	TrimSpaces     bool
	ToLowercase    bool
	RemoveNonASCII bool
}

// DefaultSanitizeConfig returns default sanitization config
func DefaultSanitizeConfig() SanitizationConfig {
	return SanitizationConfig{
		MaxLength:      1000,
		AllowHTML:      false,
		AllowNewlines:  true,
		TrimSpaces:     true,
		ToLowercase:    false,
		RemoveNonASCII: false,
	}
}

// ============================================
// SQL INJECTION PATTERNS
// ============================================

var sqlInjectionPatterns = []*regexp.Regexp{
	// Basic SQL keywords with context (not standalone)
	regexp.MustCompile(`(?i)(\b(SELECT|INSERT|UPDATE|DELETE|DROP|UNION|ALTER|CREATE|TRUNCATE|EXEC|EXECUTE)\b\s+(FROM|INTO|TABLE|DATABASE))`),
	// SQL comments
	regexp.MustCompile(`(--|\#|/\*|\*/)`),
	// SQL operators with quotes (more specific - must have SQL context)
	regexp.MustCompile(`(?i)('\s*(OR|AND)\s*'?\d*'?\s*=\s*'?\d*)`),
	regexp.MustCompile(`(?i)('\s*(OR|AND)\s+\d+\s*=\s*\d+)`),
	// Hex encoding with SQL context
	regexp.MustCompile(`(?i)(0x[0-9a-f]{8,})`),
	// CHAR/CHR function
	regexp.MustCompile(`(?i)(char|chr)\s*\(`),
	// SQL wildcard abuse (URL encoded)
	regexp.MustCompile(`(\%27)|(\%22)|(\%00)`),
	// Stacked queries with SQL keywords
	regexp.MustCompile(`;\s*(SELECT|INSERT|UPDATE|DELETE|DROP)`),
	// Common injection patterns with context
	regexp.MustCompile(`(?i)('\s*OR\s*'[^']+'\s*=\s*'[^']+)`),
	regexp.MustCompile(`(?i)('\s*AND\s*'[^']+'\s*=\s*'[^']+)`),
	regexp.MustCompile(`(?i)(admin'\s*--)`),
	regexp.MustCompile(`(?i)('\s*;\s*DROP\s+TABLE)`),
	// Time-based blind injection
	regexp.MustCompile(`(?i)(SLEEP|WAITFOR|BENCHMARK|DELAY)\s*\(`),
	// Union-based injection
	regexp.MustCompile(`(?i)(UNION\s+(ALL\s+)?SELECT)`),
}

// ============================================
// XSS PATTERNS
// ============================================

var xssPatterns = []*regexp.Regexp{
	// Script tags
	regexp.MustCompile(`(?i)<\s*script[^>]*>`),
	regexp.MustCompile(`(?i)</\s*script\s*>`),
	// Event handlers
	regexp.MustCompile(`(?i)\s+on\w+\s*=`),
	// JavaScript protocol
	regexp.MustCompile(`(?i)javascript\s*:`),
	regexp.MustCompile(`(?i)vbscript\s*:`),
	// Data URI
	regexp.MustCompile(`(?i)data\s*:\s*text/html`),
	// Expression
	regexp.MustCompile(`(?i)expression\s*\(`),
	// Img src XSS
	regexp.MustCompile(`(?i)<\s*img[^>]+src\s*=\s*['"]*[^'"]*onerror`),
	// SVG XSS
	regexp.MustCompile(`(?i)<\s*svg[^>]*onload`),
	// Iframe
	regexp.MustCompile(`(?i)<\s*iframe`),
	// Object/Embed
	regexp.MustCompile(`(?i)<\s*(object|embed|applet)`),
	// Base64 encoded
	regexp.MustCompile(`(?i)base64[^"']*['"]\s*>`),
}

// ============================================
// PATH TRAVERSAL PATTERNS
// ============================================

var pathTraversalPatterns = []*regexp.Regexp{
	regexp.MustCompile(`\.\.\/`),
	regexp.MustCompile(`\.\.\\`),
	regexp.MustCompile(`%2e%2e%2f`),
	regexp.MustCompile(`%2e%2e/`),
	regexp.MustCompile(`\.\.%2f`),
	regexp.MustCompile(`%2e%2e%5c`),
	regexp.MustCompile(`/etc/passwd`),
	regexp.MustCompile(`/etc/shadow`),
	regexp.MustCompile(`c:\\windows`),
}

// ============================================
// COMMAND INJECTION PATTERNS
// ============================================

var cmdInjectionPatterns = []*regexp.Regexp{
	regexp.MustCompile(`[;&|]`),
	regexp.MustCompile("`"),
	regexp.MustCompile(`\$\(`),
	regexp.MustCompile(`\|\|`),
	regexp.MustCompile(`&&`),
	regexp.MustCompile(`>\s*/dev/`),
	regexp.MustCompile(`\bnc\s+-`),
	regexp.MustCompile(`\bcurl\s+`),
	regexp.MustCompile(`\bwget\s+`),
}

// ============================================
// VALIDATION FUNCTIONS
// ============================================

// ValidationResult contains validation details
type ValidationResult struct {
	IsValid       bool     `json:"is_valid"`
	Errors        []string `json:"errors,omitempty"`
	Warnings      []string `json:"warnings,omitempty"`
	SanitizedData string   `json:"sanitized_data,omitempty"`
	ThreatType    string   `json:"threat_type,omitempty"`
	RiskLevel     string   `json:"risk_level,omitempty"`
}

// ContainsSQLInjection checks for SQL injection patterns
func ContainsSQLInjection(input string) (bool, []string) {
	var matchedPatterns []string
	for _, pattern := range sqlInjectionPatterns {
		if pattern.MatchString(input) {
			matchedPatterns = append(matchedPatterns, pattern.String())
		}
	}
	return len(matchedPatterns) > 0, matchedPatterns
}

// ContainsXSS checks for XSS patterns
func ContainsXSS(input string) (bool, []string) {
	var matchedPatterns []string
	for _, pattern := range xssPatterns {
		if pattern.MatchString(input) {
			matchedPatterns = append(matchedPatterns, pattern.String())
		}
	}
	return len(matchedPatterns) > 0, matchedPatterns
}

// ContainsPathTraversal checks for path traversal patterns
func ContainsPathTraversal(input string) (bool, []string) {
	var matchedPatterns []string
	for _, pattern := range pathTraversalPatterns {
		if pattern.MatchString(input) {
			matchedPatterns = append(matchedPatterns, pattern.String())
		}
	}
	return len(matchedPatterns) > 0, matchedPatterns
}

// ContainsCmdInjection checks for command injection patterns
func ContainsCmdInjection(input string) (bool, []string) {
	var matchedPatterns []string
	for _, pattern := range cmdInjectionPatterns {
		if pattern.MatchString(input) {
			matchedPatterns = append(matchedPatterns, pattern.String())
		}
	}
	return len(matchedPatterns) > 0, matchedPatterns
}

// ============================================
// SANITIZATION FUNCTIONS
// ============================================

// SanitizeString sanitizes general string input
func SanitizeString(input string, config SanitizationConfig) string {
	result := input

	// Trim spaces
	if config.TrimSpaces {
		result = strings.TrimSpace(result)
	}

	// HTML escape if not allowed
	if !config.AllowHTML {
		result = html.EscapeString(result)
	}

	// Remove newlines if not allowed
	if !config.AllowNewlines {
		result = strings.ReplaceAll(result, "\n", " ")
		result = strings.ReplaceAll(result, "\r", " ")
	}

	// Convert to lowercase
	if config.ToLowercase {
		result = strings.ToLower(result)
	}

	// Remove non-ASCII
	if config.RemoveNonASCII {
		result = removeNonASCII(result)
	}

	// Truncate to max length
	if config.MaxLength > 0 && len(result) > config.MaxLength {
		result = result[:config.MaxLength]
	}

	return result
}

// SanitizeEmail sanitizes and validates email
func SanitizeEmail(email string) (string, error) {
	email = strings.TrimSpace(email)
	email = strings.ToLower(email)

	// Basic email regex
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	if !emailRegex.MatchString(email) {
		return "", ErrInvalidEmail
	}

	// Check for injection attempts in email
	if hasSQLInjection, _ := ContainsSQLInjection(email); hasSQLInjection {
		return "", ErrSQLInjectionDetected
	}

	// Max length check
	if len(email) > 254 {
		return "", ErrInputTooLong
	}

	return email, nil
}

// SanitizeName sanitizes name input
func SanitizeName(name string) (string, error) {
	name = strings.TrimSpace(name)

	// Remove multiple spaces
	spaceRegex := regexp.MustCompile(`\s+`)
	name = spaceRegex.ReplaceAllString(name, " ")

	// Name validation - allow letters, spaces, hyphens, apostrophes
	nameRegex := regexp.MustCompile(`^[\p{L}\s'\-\.]+$`)
	if !nameRegex.MatchString(name) {
		return "", ErrInvalidName
	}

	// Length check
	if len(name) < 2 {
		return "", ErrInputTooShort
	}
	if len(name) > 100 {
		return "", ErrInputTooLong
	}

	// Check for injection
	if hasSQLInjection, _ := ContainsSQLInjection(name); hasSQLInjection {
		return "", ErrSQLInjectionDetected
	}

	return name, nil
}

// SanitizePhone sanitizes phone number
func SanitizePhone(phone string) (string, error) {
	// Remove all non-digit characters except +
	cleaned := regexp.MustCompile(`[^\d+]`).ReplaceAllString(phone, "")

	// Validate format
	phoneRegex := regexp.MustCompile(`^\+?[1-9]\d{6,14}$`)
	if !phoneRegex.MatchString(cleaned) {
		return "", ErrInvalidPhone
	}

	return cleaned, nil
}

// SanitizeURL sanitizes URL input
func SanitizeURL(url string) (string, error) {
	url = strings.TrimSpace(url)

	// Only allow http/https
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		return "", ErrInvalidURL
	}

	// Check for malicious patterns
	if hasXSS, _ := ContainsXSS(url); hasXSS {
		return "", ErrXSSDetected
	}

	// Max length
	if len(url) > 2048 {
		return "", ErrInputTooLong
	}

	return url, nil
}

// SanitizeFilename sanitizes filename
func SanitizeFilename(filename string) string {
	// Remove path traversal
	filename = strings.ReplaceAll(filename, "..", "")
	filename = strings.ReplaceAll(filename, "/", "")
	filename = strings.ReplaceAll(filename, "\\", "")

	// Remove special characters
	illegalChars := regexp.MustCompile(`[<>:"|?*\x00-\x1f]`)
	filename = illegalChars.ReplaceAllString(filename, "")

	// Truncate
	if len(filename) > 255 {
		filename = filename[:255]
	}

	return filename
}

// SanitizeHTML removes dangerous HTML while keeping safe elements
func SanitizeHTML(input string) string {
	// Remove script tags
	scriptRegex := regexp.MustCompile(`(?i)<script[^>]*>[\s\S]*?</script>`)
	result := scriptRegex.ReplaceAllString(input, "")

	// Remove event handlers
	eventRegex := regexp.MustCompile(`(?i)\s+on\w+\s*=\s*["'][^"']*["']`)
	result = eventRegex.ReplaceAllString(result, "")

	// Remove javascript: protocol
	jsRegex := regexp.MustCompile(`(?i)javascript\s*:`)
	result = jsRegex.ReplaceAllString(result, "")

	// Remove style with expressions
	styleRegex := regexp.MustCompile(`(?i)style\s*=\s*["'][^"']*expression[^"']*["']`)
	result = styleRegex.ReplaceAllString(result, "")

	// Remove iframe, object, embed
	dangerousTags := regexp.MustCompile(`(?i)<\s*(iframe|object|embed|applet)[^>]*>[\s\S]*?</\s*(iframe|object|embed|applet)\s*>`)
	result = dangerousTags.ReplaceAllString(result, "")

	return result
}

// SanitizeJSON sanitizes JSON string input
func SanitizeJSON(input string) string {
	// Escape special JSON characters
	input = strings.ReplaceAll(input, "\\", "\\\\")
	input = strings.ReplaceAll(input, "\"", "\\\"")
	input = strings.ReplaceAll(input, "\n", "\\n")
	input = strings.ReplaceAll(input, "\r", "\\r")
	input = strings.ReplaceAll(input, "\t", "\\t")
	return input
}

// ============================================
// COMPREHENSIVE VALIDATION
// ============================================

// ValidateInput performs comprehensive input validation
func ValidateInput(input string, fieldName string, maxLength int) ValidationResult {
	result := ValidationResult{
		IsValid: true,
		Errors:  []string{},
	}

	// Length check
	if maxLength > 0 && len(input) > maxLength {
		result.IsValid = false
		result.Errors = append(result.Errors, fieldName+" exceeds maximum length")
	}

	// SQL Injection check
	if hasSQLInjection, patterns := ContainsSQLInjection(input); hasSQLInjection {
		result.IsValid = false
		result.Errors = append(result.Errors, "SQL injection attempt detected in "+fieldName)
		result.ThreatType = "SQL_INJECTION"
		result.RiskLevel = "CRITICAL"
		_ = patterns // Log patterns for security audit
	}

	// XSS check
	if hasXSS, patterns := ContainsXSS(input); hasXSS {
		result.IsValid = false
		result.Errors = append(result.Errors, "XSS attempt detected in "+fieldName)
		result.ThreatType = "XSS"
		result.RiskLevel = "HIGH"
		_ = patterns
	}

	// Path traversal check
	if hasPath, _ := ContainsPathTraversal(input); hasPath {
		result.IsValid = false
		result.Errors = append(result.Errors, "Path traversal attempt detected in "+fieldName)
		result.ThreatType = "PATH_TRAVERSAL"
		result.RiskLevel = "HIGH"
	}

	// Command injection check
	if hasCmd, _ := ContainsCmdInjection(input); hasCmd {
		result.Warnings = append(result.Warnings, "Possible command injection pattern in "+fieldName)
		result.ThreatType = "CMD_INJECTION"
		result.RiskLevel = "MEDIUM"
	}

	// Sanitize the data
	config := DefaultSanitizeConfig()
	config.MaxLength = maxLength
	result.SanitizedData = SanitizeString(input, config)

	return result
}

// ValidateUserRegistration validates user registration input
func ValidateUserRegistration(name, email, password string) ValidationResult {
	result := ValidationResult{
		IsValid: true,
		Errors:  []string{},
	}

	// Validate name
	sanitizedName, err := SanitizeName(name)
	if err != nil {
		result.IsValid = false
		result.Errors = append(result.Errors, "Invalid name: "+err.Error())
	}
	_ = sanitizedName

	// Validate email
	sanitizedEmail, err := SanitizeEmail(email)
	if err != nil {
		result.IsValid = false
		result.Errors = append(result.Errors, "Invalid email: "+err.Error())
	}
	_ = sanitizedEmail

	// Validate password with complexity requirements
	passwordResult := ValidatePasswordComplexity(password)
	if !passwordResult.IsValid {
		result.IsValid = false
		result.Errors = append(result.Errors, passwordResult.Errors...)
	}

	return result
}

// ValidateLoginInput validates login input
func ValidateLoginInput(email, password string) ValidationResult {
	result := ValidationResult{
		IsValid: true,
		Errors:  []string{},
	}

	// Validate email format
	_, err := SanitizeEmail(email)
	if err != nil {
		result.IsValid = false
		result.Errors = append(result.Errors, "Invalid email format")
	}

	// Check for injection in password field
	if hasSQLInjection, _ := ContainsSQLInjection(password); hasSQLInjection {
		result.IsValid = false
		result.Errors = append(result.Errors, "Invalid characters in password")
		result.ThreatType = "SQL_INJECTION"
		result.RiskLevel = "CRITICAL"
	}

	// Password length check
	if len(password) < 8 || len(password) > 128 {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password must be between 8 and 128 characters")
	}

	return result
}

// ============================================
// PASSWORD COMPLEXITY VALIDATION
// Minggu 7: Password Complexity Requirements
// ============================================

// PasswordComplexityConfig holds password requirements
type PasswordComplexityConfig struct {
	MinLength        int
	MaxLength        int
	RequireUppercase bool
	RequireLowercase bool
	RequireDigit     bool
	RequireSpecial   bool
	DisallowCommon   bool
}

// DefaultPasswordConfig returns default password requirements
func DefaultPasswordConfig() PasswordComplexityConfig {
	return PasswordComplexityConfig{
		MinLength:        8,
		MaxLength:        128,
		RequireUppercase: true,
		RequireLowercase: true,
		RequireDigit:     true,
		RequireSpecial:   true,
		DisallowCommon:   true,
	}
}

// CommonPasswords list of common passwords to disallow
var CommonPasswords = []string{
	"password", "123456", "12345678", "qwerty", "abc123",
	"password123", "admin", "letmein", "welcome", "monkey",
	"dragon", "master", "login", "passw0rd", "hello",
	"shadow", "sunshine", "princess", "football", "baseball",
}

// ValidatePasswordComplexity validates password against complexity requirements
func ValidatePasswordComplexity(password string) ValidationResult {
	config := DefaultPasswordConfig()
	return ValidatePasswordWithConfig(password, config)
}

// ValidatePasswordWithConfig validates password with custom config
func ValidatePasswordWithConfig(password string, config PasswordComplexityConfig) ValidationResult {
	result := ValidationResult{
		IsValid: true,
		Errors:  []string{},
	}

	// Length check
	if len(password) < config.MinLength {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password must be at least "+string(rune(config.MinLength+'0'))+" characters")
	}
	if len(password) > config.MaxLength {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password must not exceed "+string(rune(config.MaxLength))+" characters")
	}

	// Character requirements
	var hasUpper, hasLower, hasDigit, hasSpecial bool
	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			hasUpper = true
		case unicode.IsLower(char):
			hasLower = true
		case unicode.IsDigit(char):
			hasDigit = true
		case unicode.IsPunct(char) || unicode.IsSymbol(char):
			hasSpecial = true
		}
	}

	if config.RequireUppercase && !hasUpper {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password must contain at least one uppercase letter")
	}
	if config.RequireLowercase && !hasLower {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password must contain at least one lowercase letter")
	}
	if config.RequireDigit && !hasDigit {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password must contain at least one digit")
	}
	if config.RequireSpecial && !hasSpecial {
		result.IsValid = false
		result.Errors = append(result.Errors, "Password must contain at least one special character (!@#$%^&*)")
	}

	// Common password check
	if config.DisallowCommon {
		lowerPassword := strings.ToLower(password)
		for _, common := range CommonPasswords {
			// Only reject if it's an exact match or if the password is short and contains the common pattern
			// For passwords >= 20 chars, allow common words as they are likely part of a passphrase
			if lowerPassword == common || (len(password) < 20 && strings.Contains(lowerPassword, common)) {
				result.IsValid = false
				result.Errors = append(result.Errors, "Password is too common or contains a common pattern")
				break
			}
		}
	}

	return result
}

// CalculatePasswordStrength calculates password strength score (0-100)
func CalculatePasswordStrength(password string) int {
	score := 0

	// Length points (max 25)
	length := len(password)
	if length >= 8 {
		score += 10
	}
	if length >= 12 {
		score += 10
	}
	if length >= 16 {
		score += 5
	}

	// Character variety (max 40)
	var hasUpper, hasLower, hasDigit, hasSpecial bool
	charTypeCount := 0
	for _, char := range password {
		switch {
		case unicode.IsUpper(char):
			if !hasUpper {
				hasUpper = true
				charTypeCount++
			}
		case unicode.IsLower(char):
			if !hasLower {
				hasLower = true
				charTypeCount++
			}
		case unicode.IsDigit(char):
			if !hasDigit {
				hasDigit = true
				charTypeCount++
			}
		case unicode.IsPunct(char) || unicode.IsSymbol(char):
			if !hasSpecial {
				hasSpecial = true
				charTypeCount++
			}
		}
	}

	if hasUpper {
		score += 10
	}
	if hasLower {
		score += 10
	}
	if hasDigit {
		score += 10
	}
	if hasSpecial {
		score += 10
	}

	// Penalty for passwords with only one character type
	if charTypeCount == 1 {
		score -= 20
		if score < 0 {
			score = 0
		}
	}

	// Uniqueness (max 20)
	uniqueChars := make(map[rune]bool)
	for _, char := range password {
		uniqueChars[char] = true
	}
	uniqueRatio := float64(len(uniqueChars)) / float64(length)
	score += int(uniqueRatio * 20)

	// No common patterns (max 15)
	lowerPassword := strings.ToLower(password)
	hasCommon := false
	for _, common := range CommonPasswords {
		if strings.Contains(lowerPassword, common) {
			hasCommon = true
			break
		}
	}
	if !hasCommon {
		score += 15
	}

	// Cap at 100
	if score > 100 {
		score = 100
	}

	return score
}

// ============================================
// HELPER FUNCTIONS
// ============================================

func removeNonASCII(s string) string {
	var result strings.Builder
	for _, char := range s {
		if char <= 127 {
			result.WriteRune(char)
		}
	}
	return result.String()
}

// ============================================
// ERROR DEFINITIONS
// ============================================

type SanitizationError struct {
	Code    string
	Message string
}

func (e SanitizationError) Error() string {
	return e.Message
}

var (
	ErrInvalidEmail         = SanitizationError{Code: "INVALID_EMAIL", Message: "Invalid email format"}
	ErrInvalidName          = SanitizationError{Code: "INVALID_NAME", Message: "Name contains invalid characters"}
	ErrInvalidPhone         = SanitizationError{Code: "INVALID_PHONE", Message: "Invalid phone number format"}
	ErrInvalidURL           = SanitizationError{Code: "INVALID_URL", Message: "Invalid URL format"}
	ErrInputTooLong         = SanitizationError{Code: "INPUT_TOO_LONG", Message: "Input exceeds maximum length"}
	ErrInputTooShort        = SanitizationError{Code: "INPUT_TOO_SHORT", Message: "Input is too short"}
	ErrSQLInjectionDetected = SanitizationError{Code: "SQL_INJECTION", Message: "Potential SQL injection detected"}
	ErrXSSDetected          = SanitizationError{Code: "XSS_DETECTED", Message: "Potential XSS attack detected"}
)
