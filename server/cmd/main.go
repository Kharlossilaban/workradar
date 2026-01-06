package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/workradar/server/internal/config"
	"github.com/workradar/server/internal/database"
	"github.com/workradar/server/internal/handlers"
	"github.com/workradar/server/internal/middleware"
	"github.com/workradar/server/internal/models"
	"github.com/workradar/server/internal/repository"
	"github.com/workradar/server/internal/services"
)

func main() {
	// Load configuration
	if err := config.Load(); err != nil {
		log.Fatal("Failed to load configuration:", err)
	}

	// Connect to database
	if err := database.Connect(); err != nil {
		log.Fatal("Failed to connect to database:", err)
	}
	defer database.Close()

	// Run Database Migrations
	log.Println("🔄 Running database migrations...")
	if err := database.DB.AutoMigrate(
		&models.User{},
		&models.Task{},
		&models.Category{},
		&models.Subscription{},
		&models.PasswordReset{},
		&models.Transaction{},
		&models.BotMessage{},
		&models.Holiday{},     // Holiday model
		&models.Leave{},       // Leave model
		&models.ChatMessage{}, // ChatMessage model
		// Security models (Keamanan Basis Data)
		&models.AuditLog{},
		&models.SecurityEvent{},
		&models.LoginAttempt{},
		&models.BlockedIP{},
		&models.PasswordHistory{},
	); err != nil {
		log.Fatal("Failed to run migrations:", err)
	}
	log.Println("✅ Database migrations completed")

	// Initialize repositories (early initialization for security middleware)
	userRepo := repository.NewUserRepository(database.DB)
	categoryRepo := repository.NewCategoryRepository(database.DB)
	taskRepo := repository.NewTaskRepository(database.DB)
	passwordResetRepo := repository.NewPasswordResetRepository(database.DB)
	subscriptionRepo := repository.NewSubscriptionRepository(database.DB)
	transactionRepo := repository.NewTransactionRepository(database.DB)
	botMessageRepo := repository.NewBotMessageRepository(database.DB)
	holidayRepo := repository.NewHolidayRepository(database.DB)
	leaveRepo := repository.NewLeaveRepository(database.DB)
	chatRepo := repository.NewChatRepository(database.DB)
	auditRepo := repository.NewAuditRepository(database.DB) // Security: Audit Repository

	// Initialize security services first (needed for middleware)
	auditService := services.NewAuditService(auditRepo)
	threatConfig := middleware.DefaultThreatDetectionConfig()

	// Initialize Fiber app
	app := fiber.New(fiber.Config{
		AppName: "Workradar API v1.0",
	})

	// Middleware
	app.Use(recover.New())
	app.Use(logger.New())

	// Security middlewares
	app.Use(middleware.SecurityHeadersMiddleware())
	app.Use(middleware.RequestIDMiddleware())
	app.Use(middleware.RateLimitMiddleware())

	// Threat Detection middleware (Keamanan Basis Data - Minggu 2)
	app.Use(middleware.ThreatDetectionMiddleware(auditService, threatConfig))

	// CORS
	app.Use(cors.New(cors.Config{
		AllowOrigins:     config.AppConfig.AllowedOrigins,
		AllowMethods:     "GET,POST,PUT,DELETE,PATCH",
		AllowHeaders:     "Origin, Content-Type, Accept, Authorization, X-Request-ID",
		ExposeHeaders:    "X-Request-ID",
		AllowCredentials: true,
	}))

	// Initialize services
	authService := services.NewAuthService(userRepo, categoryRepo, passwordResetRepo)
	taskService := services.NewTaskService(taskRepo, categoryRepo)
	categoryService := services.NewCategoryService(categoryRepo, taskRepo)
	profileService := services.NewProfileService(userRepo, taskRepo, categoryRepo)
	calendarService := services.NewCalendarService(taskRepo)
	subscriptionService := services.NewSubscriptionService(userRepo, subscriptionRepo, database.DB)
	workloadService := services.NewWorkloadService(taskRepo)
	botMessageService := services.NewBotMessageService(botMessageRepo)
	paymentService := services.NewPaymentService(transactionRepo, userRepo, subscriptionService, botMessageService)
	holidayService := services.NewHolidayService(holidayRepo)
	leaveService := services.NewLeaveService(leaveRepo)
	aiService := services.NewAIService(chatRepo, taskRepo, userRepo, config.AppConfig.GeminiAPIKey)
	oauthService := services.NewOAuthService(
		config.AppConfig.GoogleClientID,
		config.AppConfig.GoogleClientSecret,
		config.AppConfig.GoogleRedirectURL,
	)
	weatherService := services.NewWeatherService(config.AppConfig.WeatherAPIKey)

	// Initialize notification service (Firebase FCM)
	notificationService, err := services.NewNotificationService(
		userRepo,
		config.AppConfig.FirebaseProjectID,
		config.AppConfig.FirebaseCredentialsFile,
	)
	if err != nil {
		log.Fatalf("Failed to initialize NotificationService: %v", err)
	}

	// Initialize scheduler service for background notifications
	schedulerService := services.NewSchedulerService(
		database.DB,
		userRepo,
		taskRepo,
		notificationService,
		weatherService,
	)
	schedulerService.Start()
	defer schedulerService.Stop()

	// Initialize security scheduler service (Keamanan Basis Data - Phase 4: Monitoring)
	securitySchedulerService := services.NewSecuritySchedulerService(database.DB)
	securitySchedulerService.Start()
	defer securitySchedulerService.Stop()

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(authService)
	taskHandler := handlers.NewTaskHandler(taskService)
	categoryHandler := handlers.NewCategoryHandler(categoryService)
	profileHandler := handlers.NewProfileHandler(profileService)
	calendarHandler := handlers.NewCalendarHandler(calendarService)
	subscriptionHandler := handlers.NewSubscriptionHandler(subscriptionService)
	workloadHandler := handlers.NewWorkloadHandler(workloadService)
	paymentHandler := handlers.NewPaymentHandler(paymentService)
	botMessageHandler := handlers.NewBotMessageHandler(botMessageService)
	holidayHandler := handlers.NewHolidayHandler(holidayService)
	leaveHandler := handlers.NewLeaveHandler(leaveService)
	chatHandler := handlers.NewChatHandler(aiService)
	oauthHandler := handlers.NewOAuthHandler(oauthService, authService)
	weatherHandler := handlers.NewWeatherHandler(weatherService)
	notificationHandler := handlers.NewNotificationHandler(notificationService)
	securityHandler := handlers.NewSecurityHandler(auditService) // Security: Handler

	// MFA Service & Handler (Minggu 3: Multi-Factor Authentication)
	mfaService := services.NewMFAService(userRepo)
	mfaHandler := handlers.NewMFAHandler(mfaService)

	// Monitoring Handler (Keamanan Basis Data - Phase 4: Monitoring & Maintenance)
	monitoringHandler := handlers.NewMonitoringHandler()

	// API Routes
	api := app.Group("/api")

	// Health check
	api.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "OK",
			"message": "Workradar API is running",
		})
	})

	// Enhanced health check endpoints (Keamanan Basis Data - Phase 4)
	api.Get("/health/detailed", middleware.AuthMiddleware(), monitoringHandler.DetailedHealthCheck)
	api.Get("/ready", monitoringHandler.ReadinessCheck)
	api.Get("/live", monitoringHandler.LivenessCheck)
	api.Get("/metrics", middleware.AuthMiddleware(), monitoringHandler.GetMetrics)

	// Auth routes (public)
	auth := api.Group("/auth")
	// Apply brute force protection to login endpoint (Keamanan Basis Data - Minggu 2 & 3)
	auth.Post("/register", authHandler.Register)
	auth.Post("/login",
		middleware.BruteForceProtectionMiddleware(auditService, threatConfig),
		middleware.AccountLockoutMiddleware(auditService, threatConfig),
		authHandler.Login,
	)
	auth.Post("/forgot-password", authHandler.ForgotPassword)
	auth.Post("/reset-password", authHandler.ResetPassword)
	auth.Post("/refresh", authHandler.RefreshToken)

	// Google OAuth routes
	auth.Get("/google", oauthHandler.GoogleLogin)
	auth.Get("/google/callback", oauthHandler.GoogleCallback)
	auth.Post("/logout", authHandler.Logout)

	// MFA routes (Minggu 3: Multi-Factor Authentication)
	mfa := auth.Group("/mfa")
	mfa.Post("/verify-login", mfaHandler.VerifyMFALogin) // Public - verify MFA during login
	// Protected MFA routes (require authentication)
	mfaProtected := mfa.Group("", middleware.AuthMiddleware())
	mfaProtected.Get("/status", mfaHandler.GetMFAStatus)
	mfaProtected.Post("/enable", mfaHandler.EnableMFA)
	mfaProtected.Post("/verify", mfaHandler.VerifyMFA)
	mfaProtected.Post("/disable", mfaHandler.DisableMFA)

	// Protected routes - Profile
	profile := api.Group("/profile", middleware.AuthMiddleware())
	profile.Get("/", profileHandler.GetFullProfile)
	profile.Get("/stats", profileHandler.GetStats)
	profile.Put("/", authHandler.UpdateProfile)
	profile.Post("/change-password", authHandler.ChangePassword)
	profile.Get("/work-hours", profileHandler.GetWorkHours)
	profile.Put("/work-hours", profileHandler.UpdateWorkHours)

	// Protected routes - Tasks
	tasks := api.Group("/tasks", middleware.AuthMiddleware())
	tasks.Post("/", taskHandler.CreateTask)
	tasks.Get("/", taskHandler.GetTasks)
	tasks.Get("/:id", taskHandler.GetTaskByID)
	tasks.Put("/:id", taskHandler.UpdateTask)
	tasks.Delete("/:id", taskHandler.DeleteTask)
	tasks.Patch("/:id/toggle", taskHandler.ToggleComplete)

	// Protected routes - Categories
	categories := api.Group("/categories", middleware.AuthMiddleware())
	categories.Get("/", categoryHandler.GetCategories)
	categories.Post("/", categoryHandler.CreateCategory)
	categories.Put("/:id", categoryHandler.UpdateCategory)
	categories.Delete("/:id", categoryHandler.DeleteCategory)

	// Protected routes - Calendar
	calendar := api.Group("/calendar", middleware.AuthMiddleware())
	calendar.Get("/today", calendarHandler.GetTodayTasks)
	calendar.Get("/week", calendarHandler.GetWeekTasks)
	calendar.Get("/month", calendarHandler.GetMonthTasks)
	calendar.Get("/range", calendarHandler.GetTasksByDateRange)

	// Protected routes - Subscription
	subscription := api.Group("/subscription", middleware.AuthMiddleware())
	subscription.Post("/upgrade", subscriptionHandler.UpgradeToVIP)
	subscription.Get("/status", subscriptionHandler.GetVIPStatus)
	subscription.Get("/history", subscriptionHandler.GetHistory)

	// Payment routes
	payments := api.Group("/payments", middleware.AuthMiddleware())
	payments.Post("/create", paymentHandler.GetSnapToken)            // Create payment and get snap token
	payments.Get("/history", paymentHandler.GetPaymentHistory)       // Get user payment history
	payments.Get("/:order_id", paymentHandler.GetPaymentStatus)      // Get payment status
	payments.Post("/:order_id/cancel", paymentHandler.CancelPayment) // Cancel pending payment

	// Public webhook route for Midtrans
	api.Post("/webhooks/midtrans", paymentHandler.HandleNotification)

	// Protected routes - Workload
	workload := api.Group("/workload", middleware.AuthMiddleware())
	workload.Get("/", workloadHandler.GetWorkload)

	// Protected routes - Bot Messages
	messages := api.Group("/messages", middleware.AuthMiddleware())
	messages.Get("/", botMessageHandler.GetMessages)
	messages.Get("/unread", botMessageHandler.GetUnreadMessages)
	messages.Get("/unread/count", botMessageHandler.GetUnreadCount)
	messages.Patch("/:id/read", botMessageHandler.MarkAsRead)
	messages.Patch("/read-all", botMessageHandler.MarkAllAsRead)
	messages.Delete("/:id", botMessageHandler.DeleteMessage)

	// Protected routes - Holidays
	holidays := api.Group("/holidays", middleware.AuthMiddleware())
	holidays.Get("/", holidayHandler.GetHolidays)
	holidays.Post("/personal", holidayHandler.CreatePersonalHoliday)
	holidays.Delete("/personal/:id", holidayHandler.DeletePersonalHoliday)

	// Protected routes - Leaves
	leaves := api.Group("/leaves", middleware.AuthMiddleware())
	leaves.Get("/", leaveHandler.GetLeaves)
	leaves.Get("/upcoming/count", leaveHandler.GetUpcomingCount)
	leaves.Post("/", leaveHandler.CreateLeave)
	leaves.Put("/:id", leaveHandler.UpdateLeave)
	leaves.Delete("/:id", leaveHandler.DeleteLeave)

	// Protected routes - AI Chatbot
	aiChat := api.Group("/ai", middleware.AuthMiddleware())
	aiChat.Post("/chat", chatHandler.Chat)
	aiChat.Get("/history", chatHandler.GetHistory)
	aiChat.Delete("/history", chatHandler.ClearHistory)

	// Protected routes - Weather (VIP only)
	weather := api.Group("/weather", middleware.AuthMiddleware(), middleware.VIPMiddleware())
	weather.Get("/current", weatherHandler.GetCurrentWeather)
	weather.Get("/forecast", weatherHandler.GetForecast)

	// Protected routes - Notifications
	notifications := api.Group("/notifications", middleware.AuthMiddleware())
	notifications.Post("/register-device", notificationHandler.RegisterDevice)
	notifications.Delete("/register-device", notificationHandler.UnregisterDevice)
	notifications.Post("/test", notificationHandler.SendTestNotification) // For testing

	// Protected routes - Security (Keamanan Basis Data - Minggu 2 & 3)
	security := api.Group("/security", middleware.AuthMiddleware())
	security.Get("/audit-logs", securityHandler.GetAuditLogs)
	security.Get("/events", securityHandler.GetSecurityEvents)
	security.Post("/events/:id/resolve", securityHandler.ResolveSecurityEvent)
	security.Get("/blocked-ips", securityHandler.GetBlockedIPs)
	security.Delete("/blocked-ips/:ip", securityHandler.UnblockIP)
	security.Post("/validate-password", securityHandler.ValidatePassword)
	security.Get("/dashboard", securityHandler.GetSecurityDashboard)

	// Protected routes - Monitoring (Keamanan Basis Data - Phase 4: Monitoring & Maintenance)
	monitoring := api.Group("/monitoring", middleware.AuthMiddleware())
	monitoring.Post("/audit/run", monitoringHandler.RunSecurityAudit)
	monitoring.Get("/audit/report", monitoringHandler.GetLastAuditReport)
	monitoring.Get("/audit/history", monitoringHandler.GetAuditHistory)
	monitoring.Post("/vulnerability/scan", monitoringHandler.RunVulnerabilityScan)
	monitoring.Get("/vulnerability/report", monitoringHandler.GetLastVulnerabilityReport)
	monitoring.Post("/vulnerability/detect", monitoringHandler.DetectVulnerabilities)
	monitoring.Get("/dashboard", monitoringHandler.GetSecurityDashboard)
	monitoring.Get("/scheduler/status", monitoringHandler.GetSchedulerStatus)
	monitoring.Post("/scheduler/task/:type/run", monitoringHandler.RunScheduledTask)
	monitoring.Post("/scheduler/task/:type/enable", monitoringHandler.EnableScheduledTask)
	monitoring.Post("/scheduler/task/:type/disable", monitoringHandler.DisableScheduledTask)

	// Start server with TLS support (Keamanan Basis Data - Minggu 4)
	port := config.AppConfig.Port
	tlsEnabled := os.Getenv("TLS_ENABLED") == "true"
	certFile := os.Getenv("TLS_CERT_FILE")
	keyFile := os.Getenv("TLS_KEY_FILE")

	if tlsEnabled && certFile != "" && keyFile != "" {
		// Check if certificate files exist
		if _, err := os.Stat(certFile); os.IsNotExist(err) {
			log.Printf("⚠️ TLS certificate file not found: %s", certFile)
			log.Printf("🚀 Starting HTTP server on port %s (TLS disabled)", port)
			log.Fatal(app.Listen(":" + port))
		}
		if _, err := os.Stat(keyFile); os.IsNotExist(err) {
			log.Printf("⚠️ TLS key file not found: %s", keyFile)
			log.Printf("🚀 Starting HTTP server on port %s (TLS disabled)", port)
			log.Fatal(app.Listen(":" + port))
		}

		log.Printf("🔒 Starting HTTPS server on port %s with TLS", port)
		log.Fatal(app.ListenTLS(":"+port, certFile, keyFile))
	} else {
		if tlsEnabled {
			log.Println("⚠️ TLS_ENABLED=true but TLS_CERT_FILE or TLS_KEY_FILE not set")
		}
		log.Printf("🚀 Starting HTTP server on port %s", port)
		log.Println("⚠️ For production, set TLS_ENABLED=true with TLS_CERT_FILE and TLS_KEY_FILE")
		log.Fatal(app.Listen(":" + port))
	}
}
