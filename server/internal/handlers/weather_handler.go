package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/workradar/server/internal/services"
)

type WeatherHandler struct {
	weatherService *services.WeatherService
}

func NewWeatherHandler(weatherService *services.WeatherService) *WeatherHandler {
	return &WeatherHandler{
		weatherService: weatherService,
	}
}

// GetCurrentWeather returns current weather for a city
// GET /api/weather/current?city={city}
func (h *WeatherHandler) GetCurrentWeather(c *fiber.Ctx) error {
	city := c.Query("city")
	if city == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "City parameter is required",
		})
	}

	weather, err := h.weatherService.GetWeatherByCity(city)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"status":  "success",
		"weather": weather,
	})
}

// GetForecast returns weather forecast for a city
// GET /api/weather/forecast?city={city}&days={days}
func (h *WeatherHandler) GetForecast(c *fiber.Ctx) error {
	city := c.Query("city")
	if city == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "City parameter is required",
		})
	}

	// Parse days parameter (default 5)
	days := c.QueryInt("days", 5)
	if days < 1 || days > 5 {
		days = 5
	}

	forecast, err := h.weatherService.GetForecast(city, days)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
			"error": err.Error(),
		})
	}

	return c.Status(fiber.StatusOK).JSON(fiber.Map{
		"status":   "success",
		"forecast": forecast,
	})
}
