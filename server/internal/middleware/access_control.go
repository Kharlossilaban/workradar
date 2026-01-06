package middleware

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

// AccessControlMiddleware creates a middleware that checks for specific permission
func AccessControlMiddleware(permission services.Permission) fiber.Handler {
	acService := services.GetAccessControlService()

	return func(c *fiber.Ctx) error {
		// Get user ID from context (set by AuthMiddleware)
		userID := c.Locals("userID")
		if userID == nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Authentication required",
				"error":   "unauthorized",
			})
		}

		userIDStr, ok := userID.(string)
		if !ok {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Invalid user ID",
				"error":   "unauthorized",
			})
		}

		// Check permission
		hasAccess, err := acService.CheckAccess(userIDStr, permission)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Failed to check permissions",
				"error":   "internal_error",
			})
		}

		if !hasAccess {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"success": false,
				"message": "Access denied: insufficient permissions",
				"error":   "forbidden",
			})
		}

		return c.Next()
	}
}

// ResourceOwnerMiddleware checks if user owns the resource or has admin permission
func ResourceOwnerMiddleware(resourceIDParam string, permission services.Permission) fiber.Handler {
	acService := services.GetAccessControlService()

	return func(c *fiber.Ctx) error {
		userID := c.Locals("userID")
		if userID == nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Authentication required",
				"error":   "unauthorized",
			})
		}

		userIDStr, ok := userID.(string)
		if !ok {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Invalid user ID",
				"error":   "unauthorized",
			})
		}

		// Get resource owner ID from params
		resourceOwnerID := c.Params(resourceIDParam)
		if resourceOwnerID == "" {
			// If no resource ID param, check from body or query
			resourceOwnerID = c.Query("user_id")
		}

		// If still empty, assume self-access
		if resourceOwnerID == "" {
			resourceOwnerID = userIDStr
		}

		// Check if user can access the resource
		canAccess, err := acService.CanAccessResource(userIDStr, resourceOwnerID, permission)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"success": false,
				"message": "Failed to check resource access",
				"error":   "internal_error",
			})
		}

		if !canAccess {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"success": false,
				"message": "Access denied: you don't have permission to access this resource",
				"error":   "forbidden",
			})
		}

		return c.Next()
	}
}

// AdminOnlyMiddleware restricts access to admin users only
func AdminOnlyMiddleware() fiber.Handler {
	return AccessControlMiddleware(services.PermissionAdminFull)
}

// SecurityManageMiddleware restricts access to users with security management permission
func SecurityManageMiddleware() fiber.Handler {
	return AccessControlMiddleware(services.PermissionSecurityManage)
}

// AuditReadMiddleware restricts access to users who can read audit logs
func AuditReadMiddleware() fiber.Handler {
	return AccessControlMiddleware(services.PermissionAuditRead)
}

// RequirePermissions creates middleware that requires multiple permissions
func RequirePermissions(permissions ...services.Permission) fiber.Handler {
	acService := services.GetAccessControlService()

	return func(c *fiber.Ctx) error {
		userID := c.Locals("userID")
		if userID == nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Authentication required",
				"error":   "unauthorized",
			})
		}

		userIDStr, ok := userID.(string)
		if !ok {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Invalid user ID",
				"error":   "unauthorized",
			})
		}

		// Check all required permissions
		for _, permission := range permissions {
			hasAccess, err := acService.CheckAccess(userIDStr, permission)
			if err != nil {
				return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
					"success": false,
					"message": "Failed to check permissions",
					"error":   "internal_error",
				})
			}

			if !hasAccess {
				return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
					"success":    false,
					"message":    "Access denied: missing required permission",
					"error":      "forbidden",
					"permission": permission,
				})
			}
		}

		return c.Next()
	}
}

// RequireAnyPermission creates middleware that requires at least one of the permissions
func RequireAnyPermission(permissions ...services.Permission) fiber.Handler {
	acService := services.GetAccessControlService()

	return func(c *fiber.Ctx) error {
		userID := c.Locals("userID")
		if userID == nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Authentication required",
				"error":   "unauthorized",
			})
		}

		userIDStr, ok := userID.(string)
		if !ok {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"success": false,
				"message": "Invalid user ID",
				"error":   "unauthorized",
			})
		}

		// Check if user has any of the permissions
		for _, permission := range permissions {
			hasAccess, err := acService.CheckAccess(userIDStr, permission)
			if err != nil {
				continue
			}

			if hasAccess {
				return c.Next()
			}
		}

		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
			"success": false,
			"message": "Access denied: none of the required permissions found",
			"error":   "forbidden",
		})
	}
}
