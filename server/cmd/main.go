package main

import (
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/workradar/server/internal/config"
	"github.com/workradar/server/internal/database"
	"github.com/workradar/server/internal/handlers"
	"github.com/workradar/server/internal/middleware"
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

	// Initialize Fiber app
	app := fiber.New(fiber.Config{
		AppName: "Workradar API v1.0",
	})

	// Middleware
	app.Use(recover.New())
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins:     config.AppConfig.AllowedOrigins,
		AllowMethods:     "GET,POST,PUT,DELETE,PATCH",
		AllowHeaders:     "Origin, Content-Type, Accept, Authorization",
		AllowCredentials: true,
	}))

	// Initialize repositories
	userRepo := repository.NewUserRepository(database.DB)
	categoryRepo := repository.NewCategoryRepository(database.DB)
	taskRepo := repository.NewTaskRepository(database.DB)
	passwordResetRepo := repository.NewPasswordResetRepository(database.DB)
	subscriptionRepo := repository.NewSubscriptionRepository(database.DB)

	// Initialize services
	authService := services.NewAuthService(userRepo, categoryRepo, passwordResetRepo)
	taskService := services.NewTaskService(taskRepo, categoryRepo)
	categoryService := services.NewCategoryService(categoryRepo, taskRepo)
	profileService := services.NewProfileService(userRepo, taskRepo, categoryRepo)
	calendarService := services.NewCalendarService(taskRepo)
	subscriptionService := services.NewSubscriptionService(userRepo, subscriptionRepo, database.DB)
	workloadService := services.NewWorkloadService(taskRepo)

	// Initialize handlers
	authHandler := handlers.NewAuthHandler(authService)
	taskHandler := handlers.NewTaskHandler(taskService)
	categoryHandler := handlers.NewCategoryHandler(categoryService)
	profileHandler := handlers.NewProfileHandler(profileService)
	calendarHandler := handlers.NewCalendarHandler(calendarService)
	subscriptionHandler := handlers.NewSubscriptionHandler(subscriptionService)
	workloadHandler := handlers.NewWorkloadHandler(workloadService)

	// API Routes
	api := app.Group("/api")

	// Health check
	api.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{
			"status":  "OK",
			"message": "Workradar API is running",
		})
	})

	// Auth routes (public)
	auth := api.Group("/auth")
	auth.Post("/register", authHandler.Register)
	auth.Post("/login", authHandler.Login)
	auth.Post("/forgot-password", authHandler.ForgotPassword)
	auth.Post("/reset-password", authHandler.ResetPassword)

	// Protected routes - Profile
	profile := api.Group("/profile", middleware.AuthMiddleware())
	profile.Get("/", profileHandler.GetFullProfile)
	profile.Get("/stats", profileHandler.GetStats)
	profile.Put("/", authHandler.UpdateProfile)
	profile.Post("/change-password", authHandler.ChangePassword)

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

	// Protected routes - Workload
	workload := api.Group("/workload", middleware.AuthMiddleware())
	workload.Get("/", workloadHandler.GetWorkload)

	// Start server
	port := config.AppConfig.Port
	log.Printf("🚀 Server starting on port %s", port)
	log.Fatal(app.Listen(":" + port))
}
