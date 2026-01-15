package services

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"time"
)

type WeatherService struct {
	apiKey  string
	baseURL string
	client  *http.Client
}

// Weather data structures
type CurrentWeather struct {
	Temperature float64 `json:"temperature"`
	FeelsLike   float64 `json:"feels_like"`
	TempMin     float64 `json:"temp_min"`
	TempMax     float64 `json:"temp_max"`
	Pressure    int     `json:"pressure"`
	Humidity    int     `json:"humidity"`
	Description string  `json:"description"`
	Icon        string  `json:"icon"`
	WindSpeed   float64 `json:"wind_speed"`
	Clouds      int     `json:"clouds"`
	CityName    string  `json:"city_name"`
	Country     string  `json:"country"`
	Sunrise     int64   `json:"sunrise"`
	Sunset      int64   `json:"sunset"`
}

type ForecastDay struct {
	Date        string  `json:"date"`
	Temperature float64 `json:"temperature"`
	TempMin     float64 `json:"temp_min"`
	TempMax     float64 `json:"temp_max"`
	Description string  `json:"description"`
	Icon        string  `json:"icon"`
	Humidity    int     `json:"humidity"`
	WindSpeed   float64 `json:"wind_speed"`
	Clouds      int     `json:"clouds"`
}

type WeatherForecast struct {
	CityName string        `json:"city_name"`
	Country  string        `json:"country"`
	Days     []ForecastDay `json:"days"`
}

// OpenWeatherMap API response structures
type owmCurrentResponse struct {
	Main struct {
		Temp      float64 `json:"temp"`
		FeelsLike float64 `json:"feels_like"`
		TempMin   float64 `json:"temp_min"`
		TempMax   float64 `json:"temp_max"`
		Pressure  int     `json:"pressure"`
		Humidity  int     `json:"humidity"`
	} `json:"main"`
	Weather []struct {
		Description string `json:"description"`
		Icon        string `json:"icon"`
	} `json:"weather"`
	Wind struct {
		Speed float64 `json:"speed"`
	} `json:"wind"`
	Clouds struct {
		All int `json:"all"`
	} `json:"clouds"`
	Sys struct {
		Country string `json:"country"`
		Sunrise int64  `json:"sunrise"`
		Sunset  int64  `json:"sunset"`
	} `json:"sys"`
	Name string `json:"name"`
}

type owmForecastResponse struct {
	List []struct {
		Dt   int64 `json:"dt"`
		Main struct {
			Temp     float64 `json:"temp"`
			TempMin  float64 `json:"temp_min"`
			TempMax  float64 `json:"temp_max"`
			Humidity int     `json:"humidity"`
		} `json:"main"`
		Weather []struct {
			Description string `json:"description"`
			Icon        string `json:"icon"`
		} `json:"weather"`
		Wind struct {
			Speed float64 `json:"speed"`
		} `json:"wind"`
		Clouds struct {
			All int `json:"all"`
		} `json:"clouds"`
	} `json:"list"`
	City struct {
		Name    string `json:"name"`
		Country string `json:"country"`
	} `json:"city"`
}

func NewWeatherService(apiKey string) *WeatherService {
	return &WeatherService{
		apiKey:  apiKey,
		baseURL: "https://api.openweathermap.org/data/2.5",
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// GetWeatherByCity fetches current weather for a city
func (s *WeatherService) GetWeatherByCity(city string) (*CurrentWeather, error) {
	if s.apiKey == "" {
		return nil, fmt.Errorf("weather API key not configured")
	}

	log.Printf("🌤️ Weather: Fetching weather for city: %s", city)

	// Build URL
	endpoint := fmt.Sprintf("%s/weather", s.baseURL)
	params := url.Values{}
	params.Add("q", city)
	params.Add("appid", s.apiKey)
	params.Add("units", "metric") // Celsius

	fullURL := fmt.Sprintf("%s?%s", endpoint, params.Encode())
	log.Printf("🌤️ Weather: API URL: %s (key hidden)", endpoint+"?q="+city+"&units=metric")

	// Make request
	resp, err := s.client.Get(fullURL)
	if err != nil {
		log.Printf("❌ Weather: HTTP request failed: %v", err)
		return nil, fmt.Errorf("failed to fetch weather: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("❌ Weather: API error %d: %s", resp.StatusCode, string(body))
		
		// Better error message for common issues
		if resp.StatusCode == 404 {
			return nil, fmt.Errorf("city '%s' not found. Try using format: CityName,CountryCode (e.g., Jakarta,ID)", city)
		}
		return nil, fmt.Errorf("weather API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response
	var owmResp owmCurrentResponse
	if err := json.NewDecoder(resp.Body).Decode(&owmResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Map to our structure
	weather := &CurrentWeather{
		Temperature: owmResp.Main.Temp,
		FeelsLike:   owmResp.Main.FeelsLike,
		TempMin:     owmResp.Main.TempMin,
		TempMax:     owmResp.Main.TempMax,
		Pressure:    owmResp.Main.Pressure,
		Humidity:    owmResp.Main.Humidity,
		WindSpeed:   owmResp.Wind.Speed,
		Clouds:      owmResp.Clouds.All,
		CityName:    owmResp.Name,
		Country:     owmResp.Sys.Country,
		Sunrise:     owmResp.Sys.Sunrise,
		Sunset:      owmResp.Sys.Sunset,
	}

	if len(owmResp.Weather) > 0 {
		weather.Description = owmResp.Weather[0].Description
		weather.Icon = owmResp.Weather[0].Icon
	}

	log.Printf("✅ Weather: Successfully fetched weather for %s, %s (%.1f°C)", weather.CityName, weather.Country, weather.Temperature)
	return weather, nil
}

// GetWeatherByCoordinates fetches current weather by latitude and longitude
func (s *WeatherService) GetWeatherByCoordinates(lat, lon float64) (*CurrentWeather, error) {
	if s.apiKey == "" {
		return nil, fmt.Errorf("weather API key not configured")
	}

	log.Printf("🌤️ Weather: Fetching weather for coordinates: lat=%.4f, lon=%.4f", lat, lon)

	// Build URL
	endpoint := fmt.Sprintf("%s/weather", s.baseURL)
	params := url.Values{}
	params.Add("lat", fmt.Sprintf("%.4f", lat))
	params.Add("lon", fmt.Sprintf("%.4f", lon))
	params.Add("appid", s.apiKey)
	params.Add("units", "metric") // Celsius

	fullURL := fmt.Sprintf("%s?%s", endpoint, params.Encode())

	// Make request
	resp, err := s.client.Get(fullURL)
	if err != nil {
		log.Printf("❌ Weather: HTTP request failed: %v", err)
		return nil, fmt.Errorf("failed to fetch weather: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("❌ Weather: API error %d: %s", resp.StatusCode, string(body))
		return nil, fmt.Errorf("weather API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response
	var owmResp owmCurrentResponse
	if err := json.NewDecoder(resp.Body).Decode(&owmResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Map to our structure
	weather := &CurrentWeather{
		Temperature: owmResp.Main.Temp,
		FeelsLike:   owmResp.Main.FeelsLike,
		TempMin:     owmResp.Main.TempMin,
		TempMax:     owmResp.Main.TempMax,
		Pressure:    owmResp.Main.Pressure,
		Humidity:    owmResp.Main.Humidity,
		WindSpeed:   owmResp.Wind.Speed,
		Clouds:      owmResp.Clouds.All,
		CityName:    owmResp.Name,
		Country:     owmResp.Sys.Country,
		Sunrise:     owmResp.Sys.Sunrise,
		Sunset:      owmResp.Sys.Sunset,
	}

	if len(owmResp.Weather) > 0 {
		weather.Description = owmResp.Weather[0].Description
		weather.Icon = owmResp.Weather[0].Icon
	}

	log.Printf("✅ Weather: Successfully fetched weather for %s (%.1f°C) from coordinates", weather.CityName, weather.Temperature)
	return weather, nil
}

// GetForecast fetches 5-day weather forecast for a city
func (s *WeatherService) GetForecast(city string, days int) (*WeatherForecast, error) {
	if s.apiKey == "" {
		return nil, fmt.Errorf("weather API key not configured")
	}

	if days < 1 || days > 5 {
		days = 5 // Default to 5 days
	}

	// Build URL
	endpoint := fmt.Sprintf("%s/forecast", s.baseURL)
	params := url.Values{}
	params.Add("q", city)
	params.Add("appid", s.apiKey)
	params.Add("units", "metric")                // Celsius
	params.Add("cnt", fmt.Sprintf("%d", days*8)) // 8 data points per day (3-hour intervals)

	fullURL := fmt.Sprintf("%s?%s", endpoint, params.Encode())

	// Make request
	resp, err := s.client.Get(fullURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch forecast: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("weather API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response
	var owmResp owmForecastResponse
	if err := json.NewDecoder(resp.Body).Decode(&owmResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Group by day and calculate daily averages
	forecast := &WeatherForecast{
		CityName: owmResp.City.Name,
		Country:  owmResp.City.Country,
		Days:     make([]ForecastDay, 0),
	}

	dayMap := make(map[string]*ForecastDay)
	dayCount := make(map[string]int)

	for _, item := range owmResp.List {
		date := time.Unix(item.Dt, 0).Format("2006-01-02")

		if _, exists := dayMap[date]; !exists {
			dayMap[date] = &ForecastDay{
				Date: date,
			}
			dayCount[date] = 0
		}

		day := dayMap[date]
		day.Temperature += item.Main.Temp
		day.TempMin += item.Main.TempMin
		day.TempMax += item.Main.TempMax
		day.Humidity += item.Main.Humidity
		day.WindSpeed += item.Wind.Speed
		day.Clouds += item.Clouds.All

		if len(item.Weather) > 0 && day.Description == "" {
			day.Description = item.Weather[0].Description
			day.Icon = item.Weather[0].Icon
		}

		dayCount[date]++
	}

	// Calculate averages and add to result
	for date, day := range dayMap {
		count := float64(dayCount[date])
		day.Temperature /= count
		day.TempMin /= count
		day.TempMax /= count
		day.Humidity = int(float64(day.Humidity) / count)
		day.WindSpeed /= count
		day.Clouds = int(float64(day.Clouds) / count)

		forecast.Days = append(forecast.Days, *day)
	}

	return forecast, nil
}

// GetForecastByCoordinates fetches weather forecast by latitude and longitude
func (s *WeatherService) GetForecastByCoordinates(lat, lon float64, days int) (*WeatherForecast, error) {
	if s.apiKey == "" {
		return nil, fmt.Errorf("weather API key not configured")
	}

	if days < 1 || days > 5 {
		days = 5 // Default to 5 days
	}

	log.Printf("🌤️ Weather: Fetching forecast for coordinates: lat=%.4f, lon=%.4f", lat, lon)

	// Build URL
	endpoint := fmt.Sprintf("%s/forecast", s.baseURL)
	params := url.Values{}
	params.Add("lat", fmt.Sprintf("%.4f", lat))
	params.Add("lon", fmt.Sprintf("%.4f", lon))
	params.Add("appid", s.apiKey)
	params.Add("units", "metric")                // Celsius
	params.Add("cnt", fmt.Sprintf("%d", days*8)) // 8 data points per day (3-hour intervals)

	fullURL := fmt.Sprintf("%s?%s", endpoint, params.Encode())

	// Make request
	resp, err := s.client.Get(fullURL)
	if err != nil {
		log.Printf("❌ Weather: Forecast request failed: %v", err)
		return nil, fmt.Errorf("failed to fetch forecast: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("❌ Weather: Forecast API error %d: %s", resp.StatusCode, string(body))
		return nil, fmt.Errorf("weather API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response
	var owmResp owmForecastResponse
	if err := json.NewDecoder(resp.Body).Decode(&owmResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Group by day and calculate daily averages
	forecast := &WeatherForecast{
		CityName: owmResp.City.Name,
		Country:  owmResp.City.Country,
		Days:     make([]ForecastDay, 0),
	}

	dayMap := make(map[string]*ForecastDay)
	dayCount := make(map[string]int)

	for _, item := range owmResp.List {
		date := time.Unix(item.Dt, 0).Format("2006-01-02")

		if _, exists := dayMap[date]; !exists {
			dayMap[date] = &ForecastDay{
				Date: date,
			}
			dayCount[date] = 0
		}

		day := dayMap[date]
		day.Temperature += item.Main.Temp
		day.TempMin += item.Main.TempMin
		day.TempMax += item.Main.TempMax
		day.Humidity += item.Main.Humidity
		day.WindSpeed += item.Wind.Speed
		day.Clouds += item.Clouds.All

		if len(item.Weather) > 0 && day.Description == "" {
			day.Description = item.Weather[0].Description
			day.Icon = item.Weather[0].Icon
		}

		dayCount[date]++
	}

	// Calculate averages and add to result
	for date, day := range dayMap {
		count := float64(dayCount[date])
		day.Temperature /= count
		day.TempMin /= count
		day.TempMax /= count
		day.Humidity = int(float64(day.Humidity) / count)
		day.WindSpeed /= count
		day.Clouds = int(float64(day.Clouds) / count)

		forecast.Days = append(forecast.Days, *day)
	}

	log.Printf("✅ Weather: Successfully fetched forecast for coordinates")
	return forecast, nil
}

// HourlyForecast represents hourly weather forecast data
type HourlyForecast struct {
	DateTime    int64   `json:"dt"`
	Temperature float64 `json:"temperature"`
	FeelsLike   float64 `json:"feels_like"`
	Description string  `json:"description"`
	Icon        string  `json:"icon"`
	Humidity    int     `json:"humidity"`
	WindSpeed   float64 `json:"wind_speed"`
	Clouds      int     `json:"clouds"`
	Pop         float64 `json:"pop"` // Probability of precipitation
}

type HourlyWeatherForecast struct {
	CityName string           `json:"city_name"`
	Country  string           `json:"country"`
	Hourly   []HourlyForecast `json:"hourly"`
}

// GetHourlyForecast fetches hourly weather forecast for a city (up to 48 hours / 16 intervals of 3 hours)
func (s *WeatherService) GetHourlyForecast(city string, hours int) (*HourlyWeatherForecast, error) {
	if s.apiKey == "" {
		return nil, fmt.Errorf("weather API key not configured")
	}

	if hours < 1 || hours > 48 {
		hours = 12 // Default to 12 hours
	}

	// Calculate count (3-hour intervals)
	cnt := (hours + 2) / 3
	if cnt < 1 {
		cnt = 4 // At least 4 intervals (12 hours)
	}
	if cnt > 16 {
		cnt = 16 // Max 16 intervals (48 hours)
	}

	// Build URL
	endpoint := fmt.Sprintf("%s/forecast", s.baseURL)
	params := url.Values{}
	params.Add("q", city)
	params.Add("appid", s.apiKey)
	params.Add("units", "metric")
	params.Add("cnt", fmt.Sprintf("%d", cnt))

	fullURL := fmt.Sprintf("%s?%s", endpoint, params.Encode())

	// Make request
	resp, err := s.client.Get(fullURL)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch hourly forecast: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("weather API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response
	var owmResp owmForecastResponse
	if err := json.NewDecoder(resp.Body).Decode(&owmResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Map to hourly forecast
	forecast := &HourlyWeatherForecast{
		CityName: owmResp.City.Name,
		Country:  owmResp.City.Country,
		Hourly:   make([]HourlyForecast, 0, len(owmResp.List)),
	}

	for _, item := range owmResp.List {
		hourly := HourlyForecast{
			DateTime:    item.Dt,
			Temperature: item.Main.Temp,
			FeelsLike:   item.Main.TempMin, // Using TempMin as feels_like since OWM forecast doesn't have feels_like
			Humidity:    item.Main.Humidity,
			WindSpeed:   item.Wind.Speed,
			Clouds:      item.Clouds.All,
			Pop:         0, // OWM free tier doesn't include precipitation probability in forecast
		}

		if len(item.Weather) > 0 {
			hourly.Description = item.Weather[0].Description
			hourly.Icon = item.Weather[0].Icon
		}

		forecast.Hourly = append(forecast.Hourly, hourly)
	}

	return forecast, nil
}

// GetHourlyForecastByCoordinates fetches hourly weather forecast by coordinates (up to 48 hours / 16 intervals of 3 hours)
func (s *WeatherService) GetHourlyForecastByCoordinates(lat, lon float64, hours int) (*HourlyWeatherForecast, error) {
	if s.apiKey == "" {
		return nil, fmt.Errorf("weather API key not configured")
	}

	if hours < 1 || hours > 48 {
		hours = 12 // Default to 12 hours
	}

	// Calculate count (3-hour intervals)
	cnt := (hours + 2) / 3
	if cnt < 1 {
		cnt = 4 // At least 4 intervals (12 hours)
	}
	if cnt > 16 {
		cnt = 16 // Max 16 intervals (48 hours)
	}

	log.Printf("🌤️ Weather: Fetching hourly forecast for coordinates: lat=%.4f, lon=%.4f", lat, lon)

	// Build URL
	endpoint := fmt.Sprintf("%s/forecast", s.baseURL)
	params := url.Values{}
	params.Add("lat", fmt.Sprintf("%.4f", lat))
	params.Add("lon", fmt.Sprintf("%.4f", lon))
	params.Add("appid", s.apiKey)
	params.Add("units", "metric")
	params.Add("cnt", fmt.Sprintf("%d", cnt))

	fullURL := fmt.Sprintf("%s?%s", endpoint, params.Encode())

	// Make request
	resp, err := s.client.Get(fullURL)
	if err != nil {
		log.Printf("❌ Weather: Hourly forecast request failed: %v", err)
		return nil, fmt.Errorf("failed to fetch hourly forecast: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("❌ Weather: Hourly forecast API error %d: %s", resp.StatusCode, string(body))
		return nil, fmt.Errorf("weather API returned status %d: %s", resp.StatusCode, string(body))
	}

	// Parse response
	var owmResp owmForecastResponse
	if err := json.NewDecoder(resp.Body).Decode(&owmResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Map to hourly forecast
	forecast := &HourlyWeatherForecast{
		CityName: owmResp.City.Name,
		Country:  owmResp.City.Country,
		Hourly:   make([]HourlyForecast, 0, len(owmResp.List)),
	}

	for _, item := range owmResp.List {
		hourly := HourlyForecast{
			DateTime:    item.Dt,
			Temperature: item.Main.Temp,
			FeelsLike:   item.Main.TempMin, // Using TempMin as feels_like since OWM forecast doesn't have feels_like
			Humidity:    item.Main.Humidity,
			WindSpeed:   item.Wind.Speed,
			Clouds:      item.Clouds.All,
			Pop:         0, // OWM free tier doesn't include precipitation probability in forecast
		}

		if len(item.Weather) > 0 {
			hourly.Description = item.Weather[0].Description
			hourly.Icon = item.Weather[0].Icon
		}

		forecast.Hourly = append(forecast.Hourly, hourly)
	}

	log.Printf("✅ Weather: Successfully fetched hourly forecast for coordinates")
	return forecast, nil
}
