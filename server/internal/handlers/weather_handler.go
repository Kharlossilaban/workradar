package handlers

import (
	"strconv"
	"strings"

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

// GetCurrentWeather returns current weather for a city or coordinates
// GET /api/weather/current?city={city}
// GET /api/weather/current?lat={lat}&lon={lon}
func (h *WeatherHandler) GetCurrentWeather(c *fiber.Ctx) error {
	city := c.Query("city")
	lat := c.Query("lat")
	lon := c.Query("lon")
	
	// Check if using coordinates (for cities like Batam that aren't in OpenWeatherMap database)
	if lat != "" && lon != "" {
		latitude, err1 := strconv.ParseFloat(lat, 64)
		longitude, err2 := strconv.ParseFloat(lon, 64)
		
		if err1 != nil || err2 != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid latitude or longitude format",
			})
		}
		
		weather, err := h.weatherService.GetWeatherByCoordinates(latitude, longitude)
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
	
	// Otherwise use city name
	if city == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "City parameter or lat/lon coordinates are required",
		})
	}
	
	// Special handling: if city contains "lat=" and "lon=", parse it
	if strings.Contains(city, "lat=") && strings.Contains(city, "lon=") {
		// Parse format: "Batam?lat=1.0456&lon=104.0305"
		parts := strings.Split(city, "?")
		if len(parts) == 2 {
			query := parts[1]
			params := make(map[string]string)
			for _, param := range strings.Split(query, "&") {
				kv := strings.Split(param, "=")
				if len(kv) == 2 {
					params[kv[0]] = kv[1]
				}
			}
			
			if latStr, ok := params["lat"]; ok {
				if lonStr, ok := params["lon"]; ok {
					latitude, _ := strconv.ParseFloat(latStr, 64)
					longitude, _ := strconv.ParseFloat(lonStr, 64)
					
					weather, err := h.weatherService.GetWeatherByCoordinates(latitude, longitude)
					if err != nil {
						return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
							"error": err.Error(),
						})
					}
					
					// Override city name to show "Batam" instead of closest location name
					weather.CityName = parts[0]
					
					return c.Status(fiber.StatusOK).JSON(fiber.Map{
						"status":  "success",
						"weather": weather,
					})
				}
			}
		}
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

// GetHourlyForecast returns hourly weather forecast for a city or coordinates
// GET /api/weather/hourly?city={city}&hours={hours}
// GET /api/weather/hourly?lat={lat}&lon={lon}&hours={hours}
func (h *WeatherHandler) GetHourlyForecast(c *fiber.Ctx) error {
	city := c.Query("city")
	lat := c.Query("lat")
	lon := c.Query("lon")

	// Parse hours parameter (default 12, max 48)
	hours := c.QueryInt("hours", 12)
	if hours < 1 {
		hours = 12
	}
	if hours > 48 {
		hours = 48
	}

	// Check if using coordinates
	if lat != "" && lon != "" {
		latitude, err1 := strconv.ParseFloat(lat, 64)
		longitude, err2 := strconv.ParseFloat(lon, 64)

		if err1 != nil || err2 != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Invalid latitude or longitude format",
			})
		}

		forecast, err := h.weatherService.GetHourlyForecastByCoordinates(latitude, longitude, hours)
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

	// Otherwise use city name
	if city == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "City parameter or lat/lon coordinates are required",
		})
	}

	// Special handling for Batam-style query: "Batam?lat=1.0456&lon=104.0305"
	if strings.Contains(city, "lat=") && strings.Contains(city, "lon=") {
		parts := strings.Split(city, "?")
		if len(parts) == 2 {
			query := parts[1]
			params := make(map[string]string)
			for _, param := range strings.Split(query, "&") {
				kv := strings.Split(param, "=")
				if len(kv) == 2 {
					params[kv[0]] = kv[1]
				}
			}

			if latStr, ok := params["lat"]; ok {
				if lonStr, ok := params["lon"]; ok {
					latitude, _ := strconv.ParseFloat(latStr, 64)
					longitude, _ := strconv.ParseFloat(lonStr, 64)

					forecast, err := h.weatherService.GetHourlyForecastByCoordinates(latitude, longitude, hours)
					if err != nil {
						return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
							"error": err.Error(),
						})
					}

					// Override city name
					forecast.CityName = parts[0]

					return c.Status(fiber.StatusOK).JSON(fiber.Map{
						"status":   "success",
						"forecast": forecast,
					})
				}
			}
		}
	}

	forecast, err := h.weatherService.GetHourlyForecast(city, hours)
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
