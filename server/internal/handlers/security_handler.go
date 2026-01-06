package handlers

import (
	"strconv"

	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/services"
)

// SecurityHandler handles security-related endpoints
type SecurityHandler struct {
	auditService *services.AuditService
}

// NewSecurityHandler creates a new security handler
func NewSecurityHandler(auditService *services.AuditService) *SecurityHandler {
	return &SecurityHandler{
		auditService: auditService,
	}
}

// GetAuditLogs retrieves audit logs for the current user or all (admin only)
// GET /api/security/audit-logs
func (h *SecurityHandler) GetAuditLogs(c *fiber.Ctx) error {
	userID := c.Locals("user_id").(string)

	// Parse pagination
	limit, _ := strconv.Atoi(c.Query("limit", "50"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	logs, err := h.auditService.GetAuditLogsByUser(userID, limit, offset)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to retrieve audit logs",
		})
	}

	return c.JSON(fiber.Map{
		"logs":   logs,
		"limit":  limit,
		"offset": offset,
	})
}

// GetSecurityEvents retrieves security events (admin only)
// GET /api/security/events
func (h *SecurityHandler) GetSecurityEvents(c *fiber.Ctx) error {
	// Parse query params
	severity := c.Query("severity", "")
	unresolvedOnly := c.Query("unresolved", "false") == "true"
	limit, _ := strconv.Atoi(c.Query("limit", "50"))
	offset, _ := strconv.Atoi(c.Query("offset", "0"))

	if limit > 100 {
		limit = 100
	}

	var events []models.SecurityEvent
	var err error

	if unresolvedOnly {
		events, err = h.auditService.GetUnresolvedSecurityEvents(limit, offset)
	} else if severity != "" {
		events, err = h.auditService.GetSecurityEventsBySeverity(
			models.SecurityEventSeverity(severity), limit, offset)
	} else {
		events, err = h.auditService.GetUnresolvedSecurityEvents(limit, offset)
	}

	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to retrieve security events",
		})
	}

	return c.JSON(fiber.Map{
		"events": events,
		"limit":  limit,
		"offset": offset,
	})
}

// ResolveSecurityEvent marks a security event as resolved
// POST /api/security/events/:id/resolve
func (h *SecurityHandler) ResolveSecurityEvent(c *fiber.Ctx) error {
	eventID := c.Params("id")
	userID := c.Locals("user_id").(string)

	if err := h.auditService.ResolveSecurityEvent(eventID, userID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to resolve security event",
		})
	}

	return c.JSON(fiber.Map{
		"message": "Security event resolved successfully",
	})
}

// GetBlockedIPs retrieves list of blocked IPs (admin only)
// GET /api/security/blocked-ips
func (h *SecurityHandler) GetBlockedIPs(c *fiber.Ctx) error {
	blocked, err := h.auditService.GetBlockedIPs()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to retrieve blocked IPs",
		})
	}

	return c.JSON(fiber.Map{
		"blocked_ips": blocked,
		"count":       len(blocked),
	})
}

// UnblockIP removes an IP from the blocklist
// DELETE /api/security/blocked-ips/:ip
func (h *SecurityHandler) UnblockIP(c *fiber.Ctx) error {
	ip := c.Params("ip")

	if err := h.auditService.UnblockIP(ip); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": "Failed to unblock IP",
		})
	}

	return c.JSON(fiber.Map{
		"message": "IP unblocked successfully",
	})
}

// ValidatePassword validates password against policy
// POST /api/security/validate-password
func (h *SecurityHandler) ValidatePassword(c *fiber.Ctx) error {
	var req struct {
		Password string `json:"password"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Invalid request body",
		})
	}

	if req.Password == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Password is required",
		})
	}

	// Validate against default policy
	result := services.ValidatePassword(req.Password, services.DefaultPasswordPolicy())
	feedback := services.GeneratePasswordStrengthFeedback(result)

	return c.JSON(feedback)
}

// GetSecurityDashboard returns security overview (admin only)
// GET /api/security/dashboard
func (h *SecurityHandler) GetSecurityDashboard(c *fiber.Ctx) error {
	// Get unresolved critical events
	criticalEvents, _ := h.auditService.GetSecurityEventsBySeverity(models.SeverityCritical, 10, 0)
	highEvents, _ := h.auditService.GetSecurityEventsBySeverity(models.SeverityHigh, 10, 0)
	blockedIPs, _ := h.auditService.GetBlockedIPs()

	return c.JSON(fiber.Map{
		"critical_events":      len(criticalEvents),
		"high_severity_events": len(highEvents),
		"blocked_ips":          len(blockedIPs),
		"recent_critical":      criticalEvents,
		"recent_high":          highEvents,
	})
}
