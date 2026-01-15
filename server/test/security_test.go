package test

import (
	"bytes"
	"encoding/json"
	"net/http/httptest"
	"net/url"
	"testing"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/middleware"
	"github.com/workradar/server/pkg/utils"
)

// ============================================
// SECURITY TESTS
// Minggu 6: SQL Injection & XSS Testing
// ============================================

// TestSQLInjectionPatterns tests SQL injection detection
func TestSQLInjectionPatterns(t *testing.T) {
	testCases := []struct {
		name     string
		input    string
		expected bool // true = should detect injection
	}{
		// Basic SQL injection
		{"Basic OR injection", "' OR '1'='1", true},
		{"Basic OR injection 2", "admin' OR 1=1--", true},
		{"Union select", "' UNION SELECT * FROM users--", true},
		{"Drop table", "'; DROP TABLE users;--", true},
		{"Insert injection", "'; INSERT INTO users VALUES('hacker','hacked');--", true},
		{"Delete injection", "'; DELETE FROM users;--", true},
		{"Update injection", "'; UPDATE users SET password='hacked';--", true},

		// Advanced SQL injection
		{"Stacked queries", "1; SELECT * FROM users", true},
		{"Comment injection", "admin'--", true},
		{"Hash comment", "admin'#", true},
		{"Multi-line comment", "admin'/**/OR/**/1=1", true},
		{"Hex encoding", "0x27204f522027313d3127", true},
		{"CHAR function", "CHAR(65,66,67)", true},
		{"CHR function", "CHR(65)||CHR(66)", true},

		// Time-based blind injection
		{"Sleep injection", "'; SLEEP(5);--", true},
		{"Waitfor injection", "'; WAITFOR DELAY '00:00:05';--", true},
		{"Benchmark injection", "'; BENCHMARK(10000000,SHA1('test'));--", true},

		// Boolean-based blind injection
		{"Boolean blind", "' AND 1=1--", true},
		{"Boolean blind 2", "' AND 'a'='a", true},

		// Safe inputs (should NOT be detected)
		{"Normal text", "Hello World", false},
		{"Normal email", "user@example.com", false},
		{"Normal name", "John O'Brien", false}, // This might be tricky due to apostrophe
		{"Normal number", "12345", false},
		{"Normal URL", "https://example.com/page?id=123", false},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			detected, patterns := utils.ContainsSQLInjection(tc.input)
			if detected != tc.expected {
				t.Errorf("Input: %q\nExpected detection: %v, Got: %v\nPatterns: %v",
					tc.input, tc.expected, detected, patterns)
			}
		})
	}
}

// TestXSSPatterns tests XSS detection
func TestXSSPatterns(t *testing.T) {
	testCases := []struct {
		name     string
		input    string
		expected bool
	}{
		// Basic XSS
		{"Script tag", "<script>alert('xss')</script>", true},
		{"Script with src", "<script src='http://evil.com/xss.js'></script>", true},
		{"Event handler onclick", "<img src=x onerror=alert('xss')>", true},
		{"Event handler onload", "<body onload=alert('xss')>", true},
		{"Event handler onmouseover", "<a onmouseover=alert('xss')>hover</a>", true},

		// JavaScript protocol
		{"JavaScript href", "<a href='javascript:alert(1)'>click</a>", true},
		{"JavaScript src", "<img src='javascript:alert(1)'>", true},
		{"VBScript", "<a href='vbscript:msgbox(1)'>click</a>", true},

		// Advanced XSS
		{"SVG XSS", "<svg onload=alert('xss')>", true},
		{"Data URI", "<a href='data:text/html,<script>alert(1)</script>'>click</a>", true},
		{"Expression CSS", "<div style='expression(alert(1))'>", true},
		{"Iframe", "<iframe src='http://evil.com'>", true},
		{"Object tag", "<object data='http://evil.com'>", true},
		{"Embed tag", "<embed src='http://evil.com'>", true},

		// Case variations
		{"Script uppercase", "<SCRIPT>alert('xss')</SCRIPT>", true},
		{"Script mixed case", "<ScRiPt>alert('xss')</ScRiPt>", true},

		// Safe inputs
		{"Normal text", "Hello World", false},
		{"Normal HTML", "<p>This is a paragraph</p>", false},
		{"Safe link", "<a href='https://example.com'>Link</a>", false},
		{"Normal image", "<img src='image.jpg' alt='Image'>", false},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			detected, patterns := utils.ContainsXSS(tc.input)
			if detected != tc.expected {
				t.Errorf("Input: %q\nExpected detection: %v, Got: %v\nPatterns: %v",
					tc.input, tc.expected, detected, patterns)
			}
		})
	}
}

// TestPathTraversalPatterns tests path traversal detection
func TestPathTraversalPatterns(t *testing.T) {
	testCases := []struct {
		name     string
		input    string
		expected bool
	}{
		{"Basic traversal", "../../../etc/passwd", true},
		{"Windows traversal", "..\\..\\..\\windows\\system32", true},
		{"URL encoded", "%2e%2e%2f%2e%2e%2fetc%2fpasswd", true},
		{"Mixed encoding", "..%2f..%2f..%2fetc%2fpasswd", true},
		{"Etc passwd", "/etc/passwd", true},
		{"Etc shadow", "/etc/shadow", true},
		{"Windows path", "c:\\windows\\system32", true},

		// Safe paths
		{"Normal path", "/api/users/123", false},
		{"Normal file", "images/photo.jpg", false},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			detected, _ := utils.ContainsPathTraversal(tc.input)
			if detected != tc.expected {
				t.Errorf("Input: %q\nExpected detection: %v, Got: %v",
					tc.input, tc.expected, detected)
			}
		})
	}
}

// TestPasswordComplexity tests password validation
func TestPasswordComplexity(t *testing.T) {
	testCases := []struct {
		name     string
		password string
		expected bool
	}{
		// Invalid passwords
		{"Too short", "Ab1!", false},
		{"No uppercase", "abcdefg1!", false},
		{"No lowercase", "ABCDEFG1!", false},
		{"No digit", "Abcdefgh!", false},
		{"No special", "Abcdefg12", false},
		{"Common password", "Password123!", false},
		{"Contains common", "password123ABC!", false},

		// Valid passwords
		{"Valid complex", "MyStr0ng@Pass!", true},
		{"Valid with symbols", "Test#123$Pass", true},
		{"Long valid", "ThisIsAVeryStr0ng&SecurePassword!", true},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := utils.ValidatePasswordComplexity(tc.password)
			if result.IsValid != tc.expected {
				t.Errorf("Password: %q\nExpected valid: %v, Got: %v\nErrors: %v",
					tc.password, tc.expected, result.IsValid, result.Errors)
			}
		})
	}
}

// TestEmailSanitization tests email sanitization
func TestEmailSanitization(t *testing.T) {
	testCases := []struct {
		name        string
		email       string
		expectError bool
	}{
		{"Valid email", "user@example.com", false},
		{"Valid with subdomain", "user@mail.example.com", false},
		{"Valid with plus", "user+tag@example.com", false},
		{"Invalid no @", "userexample.com", true},
		{"Invalid no domain", "user@", true},
		{"Invalid SQL injection", "admin'--@example.com", true},
		{"Too long", string(make([]byte, 300)) + "@example.com", true},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := utils.SanitizeEmail(tc.email)
			hasError := err != nil
			if hasError != tc.expectError {
				t.Errorf("Email: %q\nExpected error: %v, Got error: %v (%v)",
					tc.email, tc.expectError, hasError, err)
			}
		})
	}
}

// TestNameSanitization tests name sanitization
func TestNameSanitization(t *testing.T) {
	testCases := []struct {
		name        string
		input       string
		expectError bool
	}{
		{"Valid name", "John Doe", false},
		{"Valid with hyphen", "Mary-Jane Watson", false},
		{"Valid with apostrophe", "John O'Brien", false},
		{"Too short", "A", true},
		{"Invalid characters", "John<script>Doe", true},
		{"SQL injection", "'; DROP TABLE users;--", true},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := utils.SanitizeName(tc.input)
			hasError := err != nil
			if hasError != tc.expectError {
				t.Errorf("Name: %q\nExpected error: %v, Got error: %v (%v)",
					tc.input, tc.expectError, hasError, err)
			}
		})
	}
}

// TestInputValidator tests the input validator
func TestInputValidator(t *testing.T) {
	t.Run("Register validation", func(t *testing.T) {
		// Invalid registration
		v := utils.ValidateRegisterRequest("", "", "")
		if v.IsValid() {
			t.Error("Expected validation to fail for empty inputs")
		}

		// Valid registration
		v = utils.ValidateRegisterRequest("John Doe", "john@example.com", "MyStr0ng@Pass123!")
		if !v.IsValid() {
			t.Errorf("Expected validation to pass, got errors: %v", v.GetErrorMessages())
		}
	})

	t.Run("Login validation", func(t *testing.T) {
		// SQL injection in email
		v := utils.ValidateLoginRequest("admin' OR '1'='1", "password")
		if v.IsValid() {
			t.Error("Expected validation to fail for SQL injection")
		}

		// Valid login
		v = utils.ValidateLoginRequest("user@example.com", "password123")
		if !v.IsValid() {
			t.Errorf("Expected validation to pass, got errors: %v", v.GetErrorMessages())
		}
	})
}

// TestSanitizationMiddleware tests the sanitization middleware
func TestSanitizationMiddleware(t *testing.T) {
	app := fiber.New()

	// Apply middleware
	app.Use(middleware.InputSanitizationMiddleware())

	// Test endpoint
	app.Post("/api/test", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"success": true})
	})

	tests := []struct {
		name           string
		body           map[string]string
		expectedStatus int
	}{
		{
			name:           "Safe input",
			body:           map[string]string{"name": "John Doe", "email": "john@example.com"},
			expectedStatus: 200,
		},
		{
			name:           "SQL injection in body",
			body:           map[string]string{"email": "admin' OR '1'='1"},
			expectedStatus: 400,
		},
		{
			name:           "XSS in body",
			body:           map[string]string{"name": "<script>alert('xss')</script>"},
			expectedStatus: 400,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			bodyBytes, _ := json.Marshal(tc.body)
			req := httptest.NewRequest("POST", "/api/test", bytes.NewReader(bodyBytes))
			req.Header.Set("Content-Type", "application/json")

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("Error testing request: %v", err)
			}

			if resp.StatusCode != tc.expectedStatus {
				t.Errorf("Expected status %d, got %d", tc.expectedStatus, resp.StatusCode)
			}
		})
	}
}

// TestQueryParameterInjection tests SQL injection via query parameters
func TestQueryParameterInjection(t *testing.T) {
	app := fiber.New()

	app.Use(middleware.InputSanitizationMiddleware())

	app.Get("/api/users", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"success": true})
	})

	tests := []struct {
		name           string
		queryString    string
		expectedStatus int
	}{
		{"Safe query", "?search=john", 200},
		{"SQL injection in query", "?search=" + url.QueryEscape("' OR '1'='1"), 400},
		{"Union injection", "?id=" + url.QueryEscape("1 UNION SELECT * FROM users"), 400},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req := httptest.NewRequest("GET", "/api/users"+tc.queryString, nil)

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("Error testing request: %v", err)
			}

			if resp.StatusCode != tc.expectedStatus {
				t.Errorf("Expected status %d, got %d", tc.expectedStatus, resp.StatusCode)
			}
		})
	}
}

// TestPasswordStrength tests password strength calculation
func TestPasswordStrength(t *testing.T) {
	tests := []struct {
		password string
		minScore int
		maxScore int
	}{
		{"12345678", 0, 30},            // Very weak
		{"Password", 20, 50},           // Weak
		{"Password1", 30, 60},          // Medium
		{"Password1!", 50, 80},         // Good
		{"MyStr0ng@Pass123!", 70, 100}, // Strong
	}

	for _, tc := range tests {
		t.Run(tc.password, func(t *testing.T) {
			score := utils.CalculatePasswordStrength(tc.password)
			if score < tc.minScore || score > tc.maxScore {
				t.Errorf("Password %q: expected score between %d-%d, got %d",
					tc.password, tc.minScore, tc.maxScore, score)
			}
		})
	}
}

// BenchmarkSQLInjectionDetection benchmarks SQL injection detection
func BenchmarkSQLInjectionDetection(b *testing.B) {
	inputs := []string{
		"normal text input",
		"user@example.com",
		"' OR '1'='1",
		"'; DROP TABLE users;--",
		"1 UNION SELECT * FROM users",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, input := range inputs {
			utils.ContainsSQLInjection(input)
		}
	}
}

// BenchmarkXSSDetection benchmarks XSS detection
func BenchmarkXSSDetection(b *testing.B) {
	inputs := []string{
		"normal text input",
		"<p>Safe HTML</p>",
		"<script>alert('xss')</script>",
		"<img src=x onerror=alert('xss')>",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, input := range inputs {
			utils.ContainsXSS(input)
		}
	}
}

// BenchmarkPasswordValidation benchmarks password validation
func BenchmarkPasswordValidation(b *testing.B) {
	passwords := []string{
		"weak",
		"password123",
		"MyStr0ng@Pass!",
	}

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		for _, pwd := range passwords {
			utils.ValidatePasswordComplexity(pwd)
		}
	}
}
