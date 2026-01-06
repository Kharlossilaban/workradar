package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/repository"
	"github.com/workradar/server/internal/services"
)

// AdminHandler handles admin-only operations
type AdminHandler struct {
	acService *services.AccessControlService
	viewRepo  *repository.SecureViewRepository
}

// NewAdminHandler creates a new admin handler
func NewAdminHandler() *AdminHandler {
	return &AdminHandler{
		acService: services.GetAccessControlService(),
		viewRepo:  repository.NewSecureViewRepository(),
	}
}

// UpgradeUserToVIP godoc
// @Summary Upgrade user to VIP
// @Description Admin endpoint to upgrade a user to VIP status
// @Tags Admin
// @Accept json
// @Produce json
// @Param request body UpgradeVIPRequest true "Upgrade request"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 403 {object} map[string]interface{}
// @Router /api/admin/users/upgrade-vip [post]
func (h *AdminHandler) UpgradeUserToVIP(c *fiber.Ctx) error {
	adminID := c.Locals("userID").(string)

	var req struct {
		UserID       string `json:"user_id"`
		DurationDays int    `json:"duration_days"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Invalid request body",
		})
	}

	if req.UserID == "" || req.DurationDays <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "user_id and duration_days are required",
		})
	}

	// Call stored procedure
	result, err := h.acService.CallUpgradeToVIP(req.UserID, req.DurationDays, adminID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to upgrade user",
			"error":   err.Error(),
		})
	}

	if !result.Success {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": result.Message,
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": result.Message,
	})
}

// LockUserAccount godoc
// @Summary Lock user account
// @Description Admin endpoint to lock a user account
// @Tags Admin
// @Accept json
// @Produce json
// @Param request body LockAccountRequest true "Lock request"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/admin/users/lock [post]
func (h *AdminHandler) LockUserAccount(c *fiber.Ctx) error {
	adminID := c.Locals("userID").(string)

	var req struct {
		UserID          string `json:"user_id"`
		Reason          string `json:"reason"`
		DurationMinutes int    `json:"duration_minutes"`
	}

	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "Invalid request body",
		})
	}

	if req.UserID == "" || req.Reason == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "user_id and reason are required",
		})
	}

	if req.DurationMinutes <= 0 {
		req.DurationMinutes = 30 // Default 30 minutes
	}

	result, err := h.acService.CallLockAccount(req.UserID, req.Reason, req.DurationMinutes, adminID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to lock account",
			"error":   err.Error(),
		})
	}

	if !result.Success {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": result.Message,
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": result.Message,
	})
}

// UnlockUserAccount godoc
// @Summary Unlock user account
// @Description Admin endpoint to unlock a user account
// @Tags Admin
// @Accept json
// @Produce json
// @Param user_id path string true "User ID"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/admin/users/{user_id}/unlock [post]
func (h *AdminHandler) UnlockUserAccount(c *fiber.Ctx) error {
	adminID := c.Locals("userID").(string)
	userID := c.Params("user_id")

	if userID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "user_id is required",
		})
	}

	result, err := h.acService.CallUnlockAccount(userID, adminID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to unlock account",
			"error":   err.Error(),
		})
	}

	if !result.Success {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": result.Message,
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": result.Message,
	})
}

// SoftDeleteUser godoc
// @Summary Soft delete user (GDPR)
// @Description Admin endpoint to anonymize user data (GDPR compliance)
// @Tags Admin
// @Accept json
// @Produce json
// @Param user_id path string true "User ID"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/admin/users/{user_id}/soft-delete [post]
func (h *AdminHandler) SoftDeleteUser(c *fiber.Ctx) error {
	adminID := c.Locals("userID").(string)
	userID := c.Params("user_id")

	if userID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "user_id is required",
		})
	}

	result, err := h.acService.CallSoftDeleteUser(userID, adminID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to soft delete user",
			"error":   err.Error(),
		})
	}

	if !result.Success {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": result.Message,
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": result.Message,
	})
}

// GetUserSecurityStatus godoc
// @Summary Get user security status
// @Description Get detailed security status for a user
// @Tags Admin
// @Produce json
// @Param user_id path string true "User ID"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/admin/users/{user_id}/security-status [get]
func (h *AdminHandler) GetUserSecurityStatus(c *fiber.Ctx) error {
	userID := c.Params("user_id")

	if userID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"success": false,
			"message": "user_id is required",
		})
	}

	status, err := h.acService.GetUserSecurityStatus(userID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to get security status",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    status,
	})
}

// GetPublicProfiles godoc
// @Summary Get public user profiles
// @Description Get paginated list of public user profiles (sanitized)
// @Tags Admin
// @Produce json
// @Param page query int false "Page number"
// @Param limit query int false "Items per page"
// @Success 200 {object} map[string]interface{}
// @Router /api/admin/users/profiles [get]
func (h *AdminHandler) GetPublicProfiles(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)

	profiles, total, err := h.viewRepo.GetPublicProfiles(page, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to get profiles",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    profiles,
		"meta": fiber.Map{
			"page":       page,
			"limit":      limit,
			"total":      total,
			"total_page": (total + int64(limit) - 1) / int64(limit),
		},
	})
}

// GetSecurityStats godoc
// @Summary Get security statistics
// @Description Get aggregated security statistics
// @Tags Admin
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/admin/security/stats [get]
func (h *AdminHandler) GetSecurityStats(c *fiber.Ctx) error {
	stats, err := h.viewRepo.GetSecurityStats()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to get security stats",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    stats,
	})
}

// GetSecurityEventsDashboard godoc
// @Summary Get security events dashboard
// @Description Get security events aggregated by date and type
// @Tags Admin
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/admin/security/events-dashboard [get]
func (h *AdminHandler) GetSecurityEventsDashboard(c *fiber.Ctx) error {
	events, err := h.viewRepo.GetSecurityEventsDashboard()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to get events dashboard",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    events,
	})
}

// GetActiveBlockedIPs godoc
// @Summary Get active blocked IPs
// @Description Get list of currently blocked IP addresses
// @Tags Admin
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/admin/security/blocked-ips [get]
func (h *AdminHandler) GetActiveBlockedIPs(c *fiber.Ctx) error {
	blocked, err := h.viewRepo.GetActiveBlockedIPs()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to get blocked IPs",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    blocked,
	})
}

// GetSubscriptionStatuses godoc
// @Summary Get subscription statuses
// @Description Get paginated list of subscription statuses
// @Tags Admin
// @Produce json
// @Param page query int false "Page number"
// @Param limit query int false "Items per page"
// @Param health query string false "Filter by health status"
// @Success 200 {object} map[string]interface{}
// @Router /api/admin/subscriptions [get]
func (h *AdminHandler) GetSubscriptionStatuses(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	healthFilter := c.Query("health")

	statuses, total, err := h.viewRepo.GetSubscriptionStatuses(page, limit, healthFilter)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to get subscriptions",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    statuses,
		"meta": fiber.Map{
			"page":       page,
			"limit":      limit,
			"total":      total,
			"total_page": (total + int64(limit) - 1) / int64(limit),
		},
	})
}

// GetAuditLogsSummary godoc
// @Summary Get audit logs summary
// @Description Get paginated audit logs with masked data
// @Tags Admin
// @Produce json
// @Param page query int false "Page number"
// @Param limit query int false "Items per page"
// @Param action query string false "Filter by action"
// @Param table_name query string false "Filter by table name"
// @Success 200 {object} map[string]interface{}
// @Router /api/admin/audit-logs [get]
func (h *AdminHandler) GetAuditLogsSummary(c *fiber.Ctx) error {
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 50)

	filters := make(map[string]interface{})
	if action := c.Query("action"); action != "" {
		filters["action"] = action
	}
	if tableName := c.Query("table_name"); tableName != "" {
		filters["table_name"] = tableName
	}

	logs, total, err := h.viewRepo.GetAuditLogsSummary(page, limit, filters)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to get audit logs",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"data":    logs,
		"meta": fiber.Map{
			"page":       page,
			"limit":      limit,
			"total":      total,
			"total_page": (total + int64(limit) - 1) / int64(limit),
		},
	})
}

// TriggerCleanup godoc
// @Summary Trigger data cleanup
// @Description Manually trigger cleanup of expired data
// @Tags Admin
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/admin/maintenance/cleanup [post]
func (h *AdminHandler) TriggerCleanup(c *fiber.Ctx) error {
	result, err := h.acService.CleanupExpiredData(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"success": false,
			"message": "Failed to run cleanup",
			"error":   err.Error(),
		})
	}

	return c.JSON(fiber.Map{
		"success": true,
		"message": "Cleanup completed",
		"data":    result,
	})
}
