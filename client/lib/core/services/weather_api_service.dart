import '../network/api_client.dart';
import '../network/api_exception.dart';
import 'package:dio/dio.dart';

/// Weather data model for current weather
class CurrentWeather {
  final double temperature;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int pressure;
  final int humidity;
  final String description;
  final String icon;
  final double windSpeed;
  final int clouds;
  final String cityName;
  final String country;
  final int sunrise;
  final int sunset;

  CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.pressure,
    required this.humidity,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.clouds,
    required this.cityName,
    required this.country,
    required this.sunrise,
    required this.sunset,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature'] ?? 0).toDouble(),
      feelsLike: (json['feels_like'] ?? 0).toDouble(),
      tempMin: (json['temp_min'] ?? 0).toDouble(),
      tempMax: (json['temp_max'] ?? 0).toDouble(),
      pressure: json['pressure'] ?? 0,
      humidity: json['humidity'] ?? 0,
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      windSpeed: (json['wind_speed'] ?? 0).toDouble(),
      clouds: json['clouds'] ?? 0,
      cityName: json['city_name'] ?? '',
      country: json['country'] ?? '',
      sunrise: json['sunrise'] ?? 0,
      sunset: json['sunset'] ?? 0,
    );
  }

  /// Get weather condition in Indonesian
  String get conditionIndonesian {
    final desc = description.toLowerCase();
    if (desc.contains('clear')) return 'Cerah';
    if (desc.contains('few clouds')) return 'Berawan Tipis';
    if (desc.contains('scattered clouds')) return 'Cerah Berawan';
    if (desc.contains('broken clouds') || desc.contains('overcast')) return 'Berawan';
    if (desc.contains('shower rain') || desc.contains('light rain')) return 'Hujan Ringan';
    if (desc.contains('rain')) return 'Hujan';
    if (desc.contains('thunderstorm')) return 'Hujan Petir';
    if (desc.contains('snow')) return 'Salju';
    if (desc.contains('mist') || desc.contains('fog') || desc.contains('haze')) return 'Berkabut';
    return 'Cerah Berawan';
  }

  /// Check if it's currently daytime based on sunrise/sunset
  bool get isDaytime {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= sunrise && now <= sunset;
  }
}

/// Hourly forecast data model
class HourlyForecast {
  final DateTime dateTime;
  final double temperature;
  final String description;
  final String icon;
  final int humidity;
  final double windSpeed;
  final int clouds;
  final int pop; // Probability of precipitation (%)

  HourlyForecast({
    required this.dateTime,
    required this.temperature,
    required this.description,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.clouds,
    required this.pop,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      dateTime: DateTime.fromMillisecondsSinceEpoch((json['dt'] ?? 0) * 1000),
      temperature: (json['temp'] ?? json['temperature'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      icon: json['icon'] ?? '',
      humidity: json['humidity'] ?? 0,
      windSpeed: (json['wind_speed'] ?? 0).toDouble(),
      clouds: json['clouds'] ?? 0,
      pop: ((json['pop'] ?? 0) * 100).toInt(),
    );
  }

  /// Get weather condition in Indonesian
  String get conditionIndonesian {
    final desc = description.toLowerCase();
    if (desc.contains('clear')) return 'Cerah';
    if (desc.contains('few clouds')) return 'Berawan Tipis';
    if (desc.contains('scattered clouds')) return 'Cerah Berawan';
    if (desc.contains('broken clouds') || desc.contains('overcast')) return 'Berawan';
    if (desc.contains('shower rain') || desc.contains('light rain')) return 'Hujan Ringan';
    if (desc.contains('rain')) return 'Hujan';
    if (desc.contains('thunderstorm')) return 'Hujan Petir';
    if (desc.contains('snow')) return 'Salju';
    if (desc.contains('mist') || desc.contains('fog') || desc.contains('haze')) return 'Berkabut';
    return 'Cerah Berawan';
  }
}

/// Weather forecast response containing hourly data
class WeatherForecast {
  final String cityName;
  final String country;
  final List<HourlyForecast> hourly;

  WeatherForecast({
    required this.cityName,
    required this.country,
    required this.hourly,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final hourlyList = (json['hourly'] ?? json['list'] ?? []) as List;
    return WeatherForecast(
      cityName: json['city_name'] ?? json['city']?['name'] ?? '',
      country: json['country'] ?? json['city']?['country'] ?? '',
      hourly: hourlyList.map((e) => HourlyForecast.fromJson(e)).toList(),
    );
  }
}

/// Service untuk mengambil data cuaca dari API
class WeatherApiService {
  final ApiClient _apiClient = ApiClient();

  /// Get current weather by city name
  Future<CurrentWeather> getCurrentWeather(String city) async {
    try {
      final response = await _apiClient.get(
        '/weather/current',
        queryParameters: {'city': city},
      );

      if (response.statusCode == 200) {
        final data = response.data['weather'] ?? response.data['data'] ?? response.data;
        return CurrentWeather.fromJson(data);
      } else {
        throw ApiException(
          message: response.data['error'] ?? 'Gagal mengambil data cuaca',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get hourly weather forecast by city name
  Future<WeatherForecast> getHourlyForecast(String city, {int hours = 12}) async {
    try {
      final response = await _apiClient.get(
        '/weather/hourly',
        queryParameters: {
          'city': city,
          'hours': hours,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data['forecast'] ?? response.data['data'] ?? response.data;
        return WeatherForecast.fromJson(data);
      } else {
        throw ApiException(
          message: response.data['error'] ?? 'Gagal mengambil perkiraan cuaca',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Get both current weather and forecast in one call
  Future<({CurrentWeather current, WeatherForecast forecast})> getWeatherData(String city) async {
    try {
      // Call both APIs in parallel
      final results = await Future.wait([
        getCurrentWeather(city),
        getHourlyForecast(city),
      ]);
      
      return (
        current: results[0] as CurrentWeather,
        forecast: results[1] as WeatherForecast,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Map OpenWeatherMap icon code to description
  static String getIconDescription(String iconCode) {
    switch (iconCode) {
      case '01d':
      case '01n':
        return 'Cerah';
      case '02d':
      case '02n':
        return 'Cerah Berawan';
      case '03d':
      case '03n':
        return 'Berawan';
      case '04d':
      case '04n':
        return 'Berawan Tebal';
      case '09d':
      case '09n':
        return 'Hujan Ringan';
      case '10d':
      case '10n':
        return 'Hujan';
      case '11d':
      case '11n':
        return 'Hujan Petir';
      case '13d':
      case '13n':
        return 'Salju';
      case '50d':
      case '50n':
        return 'Berkabut';
      default:
        return 'Cerah Berawan';
    }
  }
}
