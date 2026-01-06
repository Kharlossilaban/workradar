package handlers

import (
	"fmt"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/database"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/services"
)

// MonitoringHandler handles monitoring and security dashboard endpoints
type MonitoringHandler struct {
	auditService    *services.SecurityAuditService
	vulnScanner     *services.VulnerabilityScannerService
	auditLogService *services.AuditService
}

// NewMonitoringHandler creates a new monitoring handler
func NewMonitoringHandler() *MonitoringHandler {
	return &MonitoringHandler{
		auditService:    services.GetSecurityAuditService(),
		vulnScanner:     services.GetVulnerabilityScannerService(),
		auditLogService: services.GetAuditService(),
	}
}

// HealthCheck godoc
// @Summary Health check endpoint
// @Description Returns server health status
// @Tags Monitoring
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/health [get]
func (h *MonitoringHandler) HealthCheck(c *fiber.Ctx) error {
	// Basic health check
	health := fiber.Map{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
		"version":   "1.0.0",
	}

	// Database health
	dbStats := database.GetDBStatsStruct()
	if dbStats != nil {
		health["database"] = fiber.Map{
			"status":           "connected",
			"open_connections": dbStats.OpenConnections,
			"in_use":           dbStats.InUse,
			"idle":             dbStats.Idle,
		}
	} else {
		health["database"] = fiber.Map{
			"status": "unknown",
		}
	}

	return c.JSON(health)
}

// DetailedHealthCheck godoc
// @Summary Detailed health check endpoint
// @Description Returns detailed server health status including all services
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Success 200 {object} map[string]interface{}
// @Router /api/health/detailed [get]
func (h *MonitoringHandler) DetailedHealthCheck(c *fiber.Ctx) error {
	health := fiber.Map{
		"status":    "healthy",
		"timestamp": time.Now().Format(time.RFC3339),
		"version":   "1.0.0",
		"uptime":    time.Since(startTime).String(),
	}

	// Database health
	dbStats := database.GetDBStatsStruct()
	if dbStats != nil {
		poolUsage := 0
		if dbStats.MaxOpenConnections > 0 {
			poolUsage = dbStats.OpenConnections * 100 / dbStats.MaxOpenConnections
		}

		health["database"] = fiber.Map{
			"status":              "connected",
			"open_connections":    dbStats.OpenConnections,
			"max_connections":     dbStats.MaxOpenConnections,
			"in_use":              dbStats.InUse,
			"idle":                dbStats.Idle,
			"wait_count":          dbStats.WaitCount,
			"wait_duration":       dbStats.WaitDuration.String(),
			"max_idle_closed":     dbStats.MaxIdleClosed,
			"max_lifetime_closed": dbStats.MaxLifetimeClosed,
			"pool_usage_percent":  poolUsage,
		}

		if poolUsage > 80 {
			health["database"].(fiber.Map)["warning"] = "Connection pool usage is high"
		}
	}

	// Encryption service health
	encService := services.GetEncryptionService()
	health["encryption"] = fiber.Map{
		"enabled": encService.IsEnabled,
	}

	// Security audit status
	lastAudit := h.auditService.GetLastReport()
	if lastAudit != nil {
		health["last_security_audit"] = fiber.Map{
			"id":           lastAudit.ID,
			"completed_at": lastAudit.CompletedAt.Format(time.RFC3339),
			"score":        lastAudit.OverallScore,
			"status":       lastAudit.OverallStatus,
			"findings":     len(lastAudit.Findings),
		}
	}

	// Vulnerability scan status
	lastScan := h.vulnScanner.GetLastScan()
	if lastScan != nil {
		health["last_vulnerability_scan"] = fiber.Map{
			"id":              lastScan.ID,
			"completed_at":    lastScan.CompletedAt.Format(time.RFC3339),
			"risk_score":      lastScan.RiskScore,
			"risk_level":      lastScan.RiskLevel,
			"vulnerabilities": len(lastScan.Vulnerabilities),
		}
	}

	return c.JSON(health)
}

// RunSecurityAudit godoc
// @Summary Run security audit
// @Description Triggers a full security audit
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Success 200 {object} services.AuditReport
// @Failure 409 {object} map[string]interface{}
// @Router /api/monitoring/audit/run [post]
func (h *MonitoringHandler) RunSecurityAudit(c *fiber.Ctx) error {
	if h.auditService.IsRunning() {
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{
			"success": false,
			"message": "Security audit is already in progress",
		})
	}

	report, err := h.auditService.RunFullAudit()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	// Log the audit run
	userID := c.Locals("userID")
	if userID != nil {
		userIDStr := userID.(string)
		details := fmt.Sprintf("Security audit completed. Score: %d%%, Status: %s, Findings: %d",
			report.OverallScore, report.OverallStatus, len(report.Findings))
		h.auditLogService.LogSecurityEvent(
			models.SecurityEventType("SECURITY_AUDIT_RUN"),
			models.SeverityInfo,
			&userIDStr,
			c.IP(),
			details,
			c.Get("User-Agent"),
		)
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    report,
	})
}

// GetLastAuditReport godoc
// @Summary Get last security audit report
// @Description Returns the most recent security audit report
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Success 200 {object} services.AuditReport
// @Router /api/monitoring/audit/report [get]
func (h *MonitoringHandler) GetLastAuditReport(c *fiber.Ctx) error {
	report := h.auditService.GetLastReport()
	if report == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"message": "No audit report available. Run an audit first.",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    report,
	})
}

// RunVulnerabilityScan godoc
// @Summary Run vulnerability scan
// @Description Triggers a vulnerability scan
// @Tags Monitoring
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param request body VulnScanRequest true "Scan type"
// @Success 200 {object} services.VulnerabilityScanResult
// @Failure 409 {object} map[string]interface{}
// @Router /api/monitoring/vulnerability/scan [post]
func (h *MonitoringHandler) RunVulnerabilityScan(c *fiber.Ctx) error {
	if h.vulnScanner.IsScanning() {
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{
			"success": false,
			"message": "Vulnerability scan is already in progress",
		})
	}

	var req struct {
		ScanType string `json:"scan_type"` // QUICK or FULL
	}
	if err := c.BodyParser(&req); err != nil {
		req.ScanType = "QUICK"
	}

	var result *services.VulnerabilityScanResult
	var err error

	if req.ScanType == "FULL" {
		result, err = h.vulnScanner.RunFullScan()
	} else {
		result, err = h.vulnScanner.RunQuickScan()
	}

	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	// Log the scan
	userID := c.Locals("userID")
	if userID != nil {
		userIDStr := userID.(string)
		details := fmt.Sprintf("Vulnerability scan completed. Type: %s, Risk Score: %.1f, Vulnerabilities: %d",
			result.ScanType, result.RiskScore, len(result.Vulnerabilities))
		h.auditLogService.LogSecurityEvent(
			models.SecurityEventType("VULNERABILITY_SCAN_RUN"),
			models.SeverityInfo,
			&userIDStr,
			c.IP(),
			details,
			c.Get("User-Agent"),
		)
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    result,
	})
}

// GetLastVulnerabilityScan godoc
// @Summary Get last vulnerability scan result
// @Description Returns the most recent vulnerability scan result
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Success 200 {object} services.VulnerabilityScanResult
// @Router /api/monitoring/vulnerability/report [get]
func (h *MonitoringHandler) GetLastVulnerabilityScan(c *fiber.Ctx) error {
	result := h.vulnScanner.GetLastScan()
	if result == nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{
			"success": false,
			"message": "No vulnerability scan available. Run a scan first.",
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    result,
	})
}

// GetSecurityDashboard godoc
// @Summary Get security dashboard
// @Description Returns comprehensive security dashboard data
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Success 200 {object} map[string]interface{}
// @Router /api/monitoring/dashboard [get]
func (h *MonitoringHandler) GetSecurityDashboard(c *fiber.Ctx) error {
	dashboard := fiber.Map{
		"timestamp": time.Now().Format(time.RFC3339),
	}

	// Last audit report
	auditReport := h.auditService.GetLastReport()
	if auditReport != nil {
		dashboard["audit"] = fiber.Map{
			"last_run":   auditReport.CompletedAt.Format(time.RFC3339),
			"score":      auditReport.OverallScore,
			"status":     auditReport.OverallStatus,
			"findings":   len(auditReport.Findings),
			"summary":    auditReport.Summary,
			"is_running": h.auditService.IsRunning(),
		}
	} else {
		dashboard["audit"] = fiber.Map{
			"last_run":   nil,
			"is_running": h.auditService.IsRunning(),
		}
	}

	// Last vulnerability scan
	vulnScan := h.vulnScanner.GetLastScan()
	if vulnScan != nil {
		dashboard["vulnerability"] = fiber.Map{
			"last_run":            vulnScan.CompletedAt.Format(time.RFC3339),
			"risk_score":          vulnScan.RiskScore,
			"risk_level":          vulnScan.RiskLevel,
			"vulnerabilities":     len(vulnScan.Vulnerabilities),
			"summary":             vulnScan.Summary,
			"recommended_actions": vulnScan.RecommendedActions,
			"is_scanning":         h.vulnScanner.IsScanning(),
		}
	} else {
		dashboard["vulnerability"] = fiber.Map{
			"last_run":    nil,
			"is_scanning": h.vulnScanner.IsScanning(),
		}
	}

	// Database stats
	dbStats := database.GetDBStatsStruct()
	if dbStats != nil {
		poolUsage := 0
		if dbStats.MaxOpenConnections > 0 {
			poolUsage = dbStats.OpenConnections * 100 / dbStats.MaxOpenConnections
		}
		dashboard["database"] = fiber.Map{
			"pool_usage_percent": poolUsage,
			"open_connections":   dbStats.OpenConnections,
			"in_use":             dbStats.InUse,
			"wait_count":         dbStats.WaitCount,
		}
	}

	// Encryption status
	encService := services.GetEncryptionService()
	dashboard["encryption"] = fiber.Map{
		"enabled": encService.IsEnabled,
	}

	// Calculate overall security score
	overallScore := 100
	if auditReport != nil {
		overallScore = (overallScore + auditReport.OverallScore) / 2
	}
	if vulnScan != nil {
		overallScore = (overallScore + (100 - vulnScan.RiskScore)) / 2
	}
	if !encService.IsEnabled {
		overallScore -= 30
	}
	if overallScore < 0 {
		overallScore = 0
	}

	dashboard["overall_security_score"] = overallScore
	dashboard["overall_status"] = determineOverallStatus(overallScore)

	return c.JSON(fiber.Map{
		"success": true,
		"data":    dashboard,
	})
}

// GetMetrics godoc
// @Summary Get system metrics
// @Description Returns system metrics for monitoring
// @Tags Monitoring
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/metrics [get]
func (h *MonitoringHandler) GetMetrics(c *fiber.Ctx) error {
	metrics := fiber.Map{
		"timestamp":      time.Now().Format(time.RFC3339),
		"uptime_seconds": time.Since(startTime).Seconds(),
	}

	// Database metrics
	dbStats := database.GetDBStatsStruct()
	if dbStats != nil {
		metrics["db_connections_open"] = dbStats.OpenConnections
		metrics["db_connections_in_use"] = dbStats.InUse
		metrics["db_connections_idle"] = dbStats.Idle
		metrics["db_wait_count"] = dbStats.WaitCount
		metrics["db_wait_duration_ms"] = dbStats.WaitDuration.Milliseconds()
	}

	// Security metrics
	auditReport := h.auditService.GetLastReport()
	if auditReport != nil {
		metrics["security_audit_score"] = auditReport.OverallScore
		metrics["security_audit_findings"] = len(auditReport.Findings)
	}

	vulnScan := h.vulnScanner.GetLastScan()
	if vulnScan != nil {
		metrics["vulnerability_risk_score"] = vulnScan.RiskScore
		metrics["vulnerability_count"] = len(vulnScan.Vulnerabilities)
	}

	return c.JSON(metrics)
}

// ReadinessCheck godoc
// @Summary Readiness check endpoint
// @Description Returns whether the service is ready to accept traffic
// @Tags Monitoring
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Failure 503 {object} map[string]interface{}
// @Router /api/ready [get]
func (h *MonitoringHandler) ReadinessCheck(c *fiber.Ctx) error {
	// Check database connection
	dbStats := database.GetDBStatsStruct()
	if dbStats == nil {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
			"ready":   false,
			"message": "Database connection not available",
		})
	}

	return c.JSON(fiber.Map{
		"ready":     true,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// LivenessCheck godoc
// @Summary Liveness check endpoint
// @Description Returns whether the service is alive
// @Tags Monitoring
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/live [get]
func (h *MonitoringHandler) LivenessCheck(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"alive":     true,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// Helper variables
var startTime = time.Now()

// determineOverallStatus determines overall security status
func determineOverallStatus(score int) string {
	if score >= 80 {
		return "HEALTHY"
	} else if score >= 60 {
		return "WARNING"
	} else if score >= 40 {
		return "AT_RISK"
	}
	return "CRITICAL"
}

// VulnScanRequest represents vulnerability scan request
type VulnScanRequest struct {
	ScanType string `json:"scan_type"` // QUICK or FULL
}

// GetLastVulnerabilityReport returns the last vulnerability report (alias)
func (h *MonitoringHandler) GetLastVulnerabilityReport(c *fiber.Ctx) error {
	return h.GetLastVulnerabilityScan(c)
}

// GetAuditHistory godoc
// @Summary Get audit history
// @Description Returns list of past security audits
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Success 200 {object} map[string]interface{}
// @Router /api/monitoring/audit/history [get]
func (h *MonitoringHandler) GetAuditHistory(c *fiber.Ctx) error {
	history := h.auditService.GetAuditHistory()
	return c.JSON(fiber.Map{
		"success": true,
		"data":    history,
		"count":   len(history),
	})
}

// DetectVulnerabilities godoc
// @Summary Detect vulnerabilities in input
// @Description Checks for SQL injection and XSS vulnerabilities in provided input
// @Tags Monitoring
// @Accept json
// @Produce json
// @Security BearerAuth
// @Success 200 {object} map[string]interface{}
// @Router /api/monitoring/vulnerability/detect [post]
func (h *MonitoringHandler) DetectVulnerabilities(c *fiber.Ctx) error {
	var req struct {
		Input string `json:"input"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Invalid request body",
		})
	}

	results := fiber.Map{
		"input":     req.Input,
		"timestamp": time.Now().Format(time.RFC3339),
	}

	// Check for SQL injection
	sqlDetected, sqlPatterns := h.vulnScanner.DetectSQLInjection(req.Input)
	results["sql_injection"] = fiber.Map{
		"detected":         sqlDetected,
		"matched_patterns": sqlPatterns,
	}

	// Check for XSS
	xssDetected, xssPatterns := h.vulnScanner.DetectXSS(req.Input)
	results["xss"] = fiber.Map{
		"detected":         xssDetected,
		"matched_patterns": xssPatterns,
	}

	// Sanitized version
	results["sanitized"] = services.SanitizeInput(req.Input)

	return c.JSON(fiber.Map{
		"success": true,
		"data":    results,
	})
}

// GetSchedulerStatus godoc
// @Summary Get scheduler status
// @Description Returns status of security scheduled tasks
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Success 200 {object} map[string]interface{}
// @Router /api/monitoring/scheduler/status [get]
func (h *MonitoringHandler) GetSchedulerStatus(c *fiber.Ctx) error {
	scheduler := services.GetSecuritySchedulerService()
	status := scheduler.GetSchedulerStatus()

	return c.JSON(fiber.Map{
		"success": true,
		"data":    status,
	})
}

// RunScheduledTask godoc
// @Summary Run scheduled task immediately
// @Description Triggers a specific scheduled task to run immediately
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Param type path string true "Task type"
// @Success 200 {object} map[string]interface{}
// @Router /api/monitoring/scheduler/task/{type}/run [post]
func (h *MonitoringHandler) RunScheduledTask(c *fiber.Ctx) error {
	taskType := c.Params("type")
	if taskType == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Task type is required",
		})
	}

	scheduler := services.GetSecuritySchedulerService()
	err := scheduler.RunTaskNow(services.SecurityScheduledTaskType(taskType))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Task triggered successfully",
		"task":    taskType,
	})
}

// EnableScheduledTask godoc
// @Summary Enable scheduled task
// @Description Enables a specific scheduled task
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Param type path string true "Task type"
// @Success 200 {object} map[string]interface{}
// @Router /api/monitoring/scheduler/task/{type}/enable [post]
func (h *MonitoringHandler) EnableScheduledTask(c *fiber.Ctx) error {
	taskType := c.Params("type")
	if taskType == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Task type is required",
		})
	}

	scheduler := services.GetSecuritySchedulerService()
	err := scheduler.EnableTask(services.SecurityScheduledTaskType(taskType))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Task enabled successfully",
		"task":    taskType,
	})
}

// DisableScheduledTask godoc
// @Summary Disable scheduled task
// @Description Disables a specific scheduled task
// @Tags Monitoring
// @Produce json
// @Security BearerAuth
// @Param type path string true "Task type"
// @Success 200 {object} map[string]interface{}
// @Router /api/monitoring/scheduler/task/{type}/disable [post]
func (h *MonitoringHandler) DisableScheduledTask(c *fiber.Ctx) error {
	taskType := c.Params("type")
	if taskType == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Task type is required",
		})
	}

	scheduler := services.GetSecuritySchedulerService()
	err := scheduler.DisableTask(services.SecurityScheduledTaskType(taskType))
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Task disabled successfully",
		"task":    taskType,
	})
}
