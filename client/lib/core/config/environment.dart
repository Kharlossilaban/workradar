/// Environment configuration untuk API endpoints
enum Environment { development, staging, production }

class AppConfig {
  // ============================================================
  // ENVIRONMENT CONFIGURATION
  // ============================================================
  // Change this to switch between environments:
  // - development: Local testing dengan emulator/real device
  // - staging: Testing server (jika ada)
  // - production: Live production server
  static const Environment _env = Environment.development;

  // ============================================================
  // DEVELOPMENT IP CONFIGURATION
  // ============================================================
  // Ganti IP ini sesuai dengan komputer development Anda!
  // Cara mendapatkan IP:
  // - Windows: ipconfig (cari IPv4 Address)
  // - Mac/Linux: ifconfig atau ip addr
  //
  // Untuk testing di real device, IP harus bisa diakses dari device
  // (pastikan komputer dan device dalam satu jaringan WiFi)
  static const String _developmentIP =
      '192.168.1.7'; // <-- GANTI DENGAN IP ANDA!
  static const String _developmentPort = '8080';

  /// Base API URL berdasarkan environment
  static String get apiUrl {
    switch (_env) {
      case Environment.development:
        // Local development - pilih sesuai target device:
        return 'http://$_developmentIP:$_developmentPort/api';
      // Alternatif untuk emulator saja:
      // return 'http://10.0.2.2:8080/api'; // Android emulator (khusus localhost)
      // return 'http://localhost:8080/api'; // iOS simulator

      case Environment.staging:
        return 'https://staging-api.workradar.app/api';

      case Environment.production:
        return 'https://api.workradar.app/api';
    }
  }

  /// Base URL tanpa /api suffix (untuk payment service, etc)
  static String get baseUrl {
    switch (_env) {
      case Environment.development:
        return 'http://$_developmentIP:$_developmentPort';
      case Environment.staging:
        return 'https://staging-api.workradar.app';
      case Environment.production:
        return 'https://api.workradar.app';
    }
  }

  /// Current environment name
  static String get environmentName {
    return _env.name;
  }

  /// Is development mode
  static bool get isDevelopment => _env == Environment.development;

  /// Is production mode
  static bool get isProduction => _env == Environment.production;

  /// Enable certificate pinning (only for production)
  static bool get enableCertificatePinning {
    return _env == Environment.production;
  }

  /// Enable debug logging
  static bool get enableDebugLog {
    return _env == Environment.development;
  }

  /// Token expiry duration (24 hours - sesuai backend update)
  static const Duration accessTokenExpiry = Duration(hours: 24);

  /// Refresh token expiry (7 days, sesuai backend)
  static const Duration refreshTokenExpiry = Duration(days: 7);

  /// Request timeout
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);

  /// Rate limit info (untuk UI warning)
  static const int maxRequestsPerMinute = 60; // Regular user
  static const int maxRequestsPerMinuteVIP = 120; // VIP user
}
