package utils

import (
	"regexp"
	"strings"
)

// ============================================
// INPUT VALIDATOR
// Minggu 6: Input Length Validation
// ============================================

// FieldConfig represents validation configuration for a field
type FieldConfig struct {
	FieldName   string
	MinLength   int
	MaxLength   int
	Required    bool
	Pattern     *regexp.Regexp
	PatternDesc string
	Sanitize    bool
	AllowEmpty  bool
}

// ValidationError represents a validation error
type ValidationError struct {
	Field   string `json:"field"`
	Code    string `json:"code"`
	Message string `json:"message"`
}

// InputValidator validates multiple fields
type InputValidator struct {
	Errors []ValidationError
}

// NewInputValidator creates a new validator
func NewInputValidator() *InputValidator {
	return &InputValidator{
		Errors: []ValidationError{},
	}
}

// AddError adds an error to the validator
func (v *InputValidator) AddError(field, code, message string) {
	v.Errors = append(v.Errors, ValidationError{
		Field:   field,
		Code:    code,
		Message: message,
	})
}

// IsValid returns true if no errors
func (v *InputValidator) IsValid() bool {
	return len(v.Errors) == 0
}

// GetErrors returns all errors
func (v *InputValidator) GetErrors() []ValidationError {
	return v.Errors
}

// GetErrorMessages returns error messages as strings
func (v *InputValidator) GetErrorMessages() []string {
	messages := make([]string, len(v.Errors))
	for i, err := range v.Errors {
		messages[i] = err.Field + ": " + err.Message
	}
	return messages
}

// ============================================
// FIELD VALIDATORS
// ============================================

// ValidateRequired checks if field is not empty
func (v *InputValidator) ValidateRequired(value, fieldName string) *InputValidator {
	if strings.TrimSpace(value) == "" {
		v.AddError(fieldName, "REQUIRED", fieldName+" is required")
	}
	return v
}

// ValidateMinLength checks minimum length
func (v *InputValidator) ValidateMinLength(value, fieldName string, minLength int) *InputValidator {
	if len(value) < minLength {
		v.AddError(fieldName, "TOO_SHORT", fieldName+" must be at least "+intToString(minLength)+" characters")
	}
	return v
}

// ValidateMaxLength checks maximum length
func (v *InputValidator) ValidateMaxLength(value, fieldName string, maxLength int) *InputValidator {
	if len(value) > maxLength {
		v.AddError(fieldName, "TOO_LONG", fieldName+" must not exceed "+intToString(maxLength)+" characters")
	}
	return v
}

// ValidateLength checks both min and max length
func (v *InputValidator) ValidateLength(value, fieldName string, minLength, maxLength int) *InputValidator {
	v.ValidateMinLength(value, fieldName, minLength)
	v.ValidateMaxLength(value, fieldName, maxLength)
	return v
}

// ValidatePattern checks if value matches pattern
func (v *InputValidator) ValidatePattern(value, fieldName string, pattern *regexp.Regexp, description string) *InputValidator {
	if !pattern.MatchString(value) {
		v.AddError(fieldName, "INVALID_FORMAT", fieldName+" "+description)
	}
	return v
}

// ValidateEmail validates email format
func (v *InputValidator) ValidateEmail(email, fieldName string) *InputValidator {
	email = strings.TrimSpace(email)
	if email == "" {
		v.AddError(fieldName, "REQUIRED", "Email is required")
		return v
	}

	// Max length
	if len(email) > 254 {
		v.AddError(fieldName, "TOO_LONG", "Email must not exceed 254 characters")
		return v
	}

	// Email pattern
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	if !emailRegex.MatchString(email) {
		v.AddError(fieldName, "INVALID_FORMAT", "Invalid email format")
	}

	// Check for injection
	if hasSQLInjection, _ := ContainsSQLInjection(email); hasSQLInjection {
		v.AddError(fieldName, "SECURITY", "Email contains invalid characters")
	}

	return v
}

// ValidateName validates name input
func (v *InputValidator) ValidateName(name, fieldName string) *InputValidator {
	name = strings.TrimSpace(name)
	if name == "" {
		v.AddError(fieldName, "REQUIRED", fieldName+" is required")
		return v
	}

	// Length
	if len(name) < 2 {
		v.AddError(fieldName, "TOO_SHORT", fieldName+" must be at least 2 characters")
	}
	if len(name) > 100 {
		v.AddError(fieldName, "TOO_LONG", fieldName+" must not exceed 100 characters")
	}

	// Pattern - allow letters, spaces, hyphens, apostrophes
	nameRegex := regexp.MustCompile(`^[\p{L}\s'\-\.]+$`)
	if !nameRegex.MatchString(name) {
		v.AddError(fieldName, "INVALID_FORMAT", fieldName+" contains invalid characters")
	}

	// Check for injection
	if hasSQLInjection, _ := ContainsSQLInjection(name); hasSQLInjection {
		v.AddError(fieldName, "SECURITY", fieldName+" contains suspicious patterns")
	}

	return v
}

// ValidatePassword validates password with complexity
func (v *InputValidator) ValidatePassword(password, fieldName string) *InputValidator {
	if password == "" {
		v.AddError(fieldName, "REQUIRED", "Password is required")
		return v
	}

	result := ValidatePasswordComplexity(password)
	if !result.IsValid {
		for _, err := range result.Errors {
			v.AddError(fieldName, "COMPLEXITY", err)
		}
	}

	return v
}

// ValidatePhone validates phone number
func (v *InputValidator) ValidatePhone(phone, fieldName string) *InputValidator {
	if phone == "" {
		return v // Phone is optional
	}

	// Clean phone number
	cleaned := regexp.MustCompile(`[^\d+]`).ReplaceAllString(phone, "")

	// Pattern
	phoneRegex := regexp.MustCompile(`^\+?[1-9]\d{6,14}$`)
	if !phoneRegex.MatchString(cleaned) {
		v.AddError(fieldName, "INVALID_FORMAT", "Invalid phone number format")
	}

	return v
}

// ValidateURL validates URL format
func (v *InputValidator) ValidateURL(url, fieldName string, required bool) *InputValidator {
	url = strings.TrimSpace(url)
	if url == "" {
		if required {
			v.AddError(fieldName, "REQUIRED", fieldName+" is required")
		}
		return v
	}

	// Max length
	if len(url) > 2048 {
		v.AddError(fieldName, "TOO_LONG", "URL must not exceed 2048 characters")
	}

	// Protocol
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		v.AddError(fieldName, "INVALID_FORMAT", "URL must start with http:// or https://")
	}

	// XSS check
	if hasXSS, _ := ContainsXSS(url); hasXSS {
		v.AddError(fieldName, "SECURITY", "URL contains invalid characters")
	}

	return v
}

// ValidateNoSQLInjection checks for SQL injection patterns
func (v *InputValidator) ValidateNoSQLInjection(value, fieldName string) *InputValidator {
	if hasSQLInjection, _ := ContainsSQLInjection(value); hasSQLInjection {
		v.AddError(fieldName, "SECURITY", fieldName+" contains potentially dangerous patterns")
	}
	return v
}

// ValidateNoXSS checks for XSS patterns
func (v *InputValidator) ValidateNoXSS(value, fieldName string) *InputValidator {
	if hasXSS, _ := ContainsXSS(value); hasXSS {
		v.AddError(fieldName, "SECURITY", fieldName+" contains potentially dangerous patterns")
	}
	return v
}

// ValidateUUID validates UUID format
func (v *InputValidator) ValidateUUID(uuid, fieldName string) *InputValidator {
	if uuid == "" {
		v.AddError(fieldName, "REQUIRED", fieldName+" is required")
		return v
	}

	uuidRegex := regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)
	if !uuidRegex.MatchString(uuid) {
		v.AddError(fieldName, "INVALID_FORMAT", "Invalid UUID format")
	}

	return v
}

// ValidateEnum validates value is in allowed list
func (v *InputValidator) ValidateEnum(value, fieldName string, allowedValues []string) *InputValidator {
	for _, allowed := range allowedValues {
		if value == allowed {
			return v
		}
	}
	v.AddError(fieldName, "INVALID_VALUE", fieldName+" must be one of: "+strings.Join(allowedValues, ", "))
	return v
}

// ValidateNumericRange validates numeric string is within range
func (v *InputValidator) ValidateNumericRange(value, fieldName string, min, max int) *InputValidator {
	num := stringToInt(value)
	if num < min || num > max {
		v.AddError(fieldName, "OUT_OF_RANGE", fieldName+" must be between "+intToString(min)+" and "+intToString(max))
	}
	return v
}

// ============================================
// PREDEFINED FIELD CONFIGURATIONS
// ============================================

// Common field configurations
var (
	EmailFieldConfig = FieldConfig{
		FieldName:   "email",
		MinLength:   5,
		MaxLength:   254,
		Required:    true,
		Pattern:     regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`),
		PatternDesc: "must be a valid email address",
		Sanitize:    true,
	}

	NameFieldConfig = FieldConfig{
		FieldName:   "name",
		MinLength:   2,
		MaxLength:   100,
		Required:    true,
		Pattern:     regexp.MustCompile(`^[\p{L}\s'\-\.]+$`),
		PatternDesc: "can only contain letters, spaces, hyphens, and apostrophes",
		Sanitize:    true,
	}

	PasswordFieldConfig = FieldConfig{
		FieldName: "password",
		MinLength: 8,
		MaxLength: 128,
		Required:  true,
		Sanitize:  false, // Don't sanitize passwords
	}

	PhoneFieldConfig = FieldConfig{
		FieldName:   "phone",
		MinLength:   7,
		MaxLength:   15,
		Required:    false,
		Pattern:     regexp.MustCompile(`^\+?[1-9]\d{6,14}$`),
		PatternDesc: "must be a valid phone number",
		Sanitize:    true,
	}

	TitleFieldConfig = FieldConfig{
		FieldName: "title",
		MinLength: 1,
		MaxLength: 200,
		Required:  true,
		Sanitize:  true,
	}

	DescriptionFieldConfig = FieldConfig{
		FieldName:  "description",
		MinLength:  0,
		MaxLength:  5000,
		Required:   false,
		Sanitize:   true,
		AllowEmpty: true,
	}

	UUIDFieldConfig = FieldConfig{
		FieldName:   "id",
		MinLength:   36,
		MaxLength:   36,
		Required:    true,
		Pattern:     regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`),
		PatternDesc: "must be a valid UUID",
	}
)

// ============================================
// HELPER FUNCTIONS
// ============================================

func intToString(n int) string {
	if n == 0 {
		return "0"
	}
	var result []byte
	negative := n < 0
	if negative {
		n = -n
	}
	for n > 0 {
		result = append([]byte{byte(n%10 + '0')}, result...)
		n /= 10
	}
	if negative {
		result = append([]byte{'-'}, result...)
	}
	return string(result)
}

func stringToInt(s string) int {
	result := 0
	negative := false
	for i, char := range s {
		if i == 0 && char == '-' {
			negative = true
			continue
		}
		if char >= '0' && char <= '9' {
			result = result*10 + int(char-'0')
		}
	}
	if negative {
		return -result
	}
	return result
}

// ============================================
// REQUEST BODY VALIDATORS
// ============================================

// ValidateRegisterRequest validates registration request
func ValidateRegisterRequest(name, email, password string) *InputValidator {
	v := NewInputValidator()
	v.ValidateName(name, "name")
	v.ValidateEmail(email, "email")
	v.ValidatePassword(password, "password")
	return v
}

// ValidateLoginRequest validates login request
func ValidateLoginRequest(email, password string) *InputValidator {
	v := NewInputValidator()
	v.ValidateEmail(email, "email")
	v.ValidateRequired(password, "password")
	v.ValidateNoSQLInjection(password, "password")
	return v
}

// ValidateTaskRequest validates task creation request
func ValidateTaskRequest(title, description, status string) *InputValidator {
	v := NewInputValidator()
	v.ValidateRequired(title, "title").ValidateMaxLength(title, "title", 200)
	v.ValidateMaxLength(description, "description", 5000)
	v.ValidateNoSQLInjection(title, "title")
	v.ValidateNoXSS(title, "title")
	v.ValidateNoXSS(description, "description")
	if status != "" {
		v.ValidateEnum(status, "status", []string{"pending", "in_progress", "completed", "cancelled"})
	}
	return v
}

// ValidateProfileUpdateRequest validates profile update
func ValidateProfileUpdateRequest(name, phone string) *InputValidator {
	v := NewInputValidator()
	if name != "" {
		v.ValidateName(name, "name")
	}
	if phone != "" {
		v.ValidatePhone(phone, "phone")
	}
	return v
}

// ValidateChangePasswordRequest validates password change
func ValidateChangePasswordRequest(oldPassword, newPassword, confirmPassword string) *InputValidator {
	v := NewInputValidator()
	v.ValidateRequired(oldPassword, "old_password")
	v.ValidatePassword(newPassword, "new_password")
	if newPassword != confirmPassword {
		v.AddError("confirm_password", "MISMATCH", "Passwords do not match")
	}
	if oldPassword == newPassword {
		v.AddError("new_password", "SAME", "New password must be different from old password")
	}
	return v
}
