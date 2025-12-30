/// Environment configuration untuk API endpoints
enum Environment { development, production }

class AppConfig {
  // Current environment
  static const Environment _env = Environment.development;

  /// Base API URL berdasarkan environment
  static String get apiUrl {
    switch (_env) {
      case Environment.development:
        // Local development
        return 'http://192.168.1.7:8080/api'; // Android emulator
      // return 'http://localhost:8080/api'; // iOS simulator
      // return 'http://YOUR_IP:8080/api'; // Real device (ganti dengan IP komputer Anda)

      case Environment.production:
        return 'https://api.workradar.app/api';
    }
  }

  /// Enable certificate pinning (only for production)
  static bool get enableCertificatePinning {
    return _env == Environment.production;
  }

  /// Enable debug logging
  static bool get enableDebugLog {
    return _env == Environment.development;
  }

  /// Token expiry duration (15 minutes, sesuai backend)
  static const Duration accessTokenExpiry = Duration(minutes: 15);

  /// Refresh token expiry (7 days, sesuai backend)
  static const Duration refreshTokenExpiry = Duration(days: 7);

  /// Request timeout
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  /// Rate limit info (untuk UI warning)
  static const int maxRequestsPerMinute = 60; // Regular user
  static const int maxRequestsPerMinuteVIP = 120; // VIP user
}
