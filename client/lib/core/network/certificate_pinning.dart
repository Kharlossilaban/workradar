import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:workradar/core/config/environment.dart';
import 'package:workradar/core/network/auth_interceptor.dart';

/// ============================================
/// CERTIFICATE PINNING
/// Minggu 8: Data Encryption & Secure Communication
/// ============================================
///
/// Certificate Pinning mencegah Man-in-the-Middle (MITM) attacks
/// dengan memverifikasi bahwa server certificate sesuai dengan
/// certificate yang di-pin di aplikasi.

/// Certificate pinning configuration
class CertificatePinningConfig {
  /// SHA-256 hashes of trusted certificate public keys
  /// Format: "sha256/BASE64_ENCODED_HASH"
  ///
  /// Cara mendapatkan hash:
  /// 1. Download certificate: openssl s_client -connect api.workradar.com:443 &lt;/dev/null 2>/dev/null | openssl x509 -outform DER > cert.der
  /// 2. Get public key: openssl x509 -inform DER -in cert.der -pubkey -noout > pubkey.pem
  /// 3. Get hash: openssl pkey -pubin -in pubkey.pem -outform DER | openssl dgst -sha256 -binary | base64
  static const List<String> pinnedCertificateHashes = [
    // Production certificate hash (update with your actual certificate hash)
    // 'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',

    // Backup certificate hash (for certificate rotation)
    // 'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=',
  ];

  /// Path to bundled certificate file (alternative to hash pinning)
  static const String bundledCertificatePath = 'assets/certs/server.pem';

  /// Enable/disable certificate pinning
  static bool get isEnabled {
    // Disable in debug mode for easier development
    if (kDebugMode) {
      return false;
    }
    return AppConfig.isProduction;
  }

  /// Domains to apply pinning
  static const List<String> pinnedDomains = [
    'api.workradar.com',
    '*.workradar.com',
  ];
}

/// Secure API Client with Certificate Pinning
class SecureApiClient {
  static SecureApiClient? _instance;
  late final Dio _dio;

  Dio get dio => _dio;

  SecureApiClient._internal() {
    _dio = _createDio();
  }

  factory SecureApiClient() {
    _instance ??= SecureApiClient._internal();
    return _instance!;
  }

  /// Create Dio instance with security configurations
  Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          // Add security headers
          'X-Requested-With': 'XMLHttpRequest',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Configure certificate pinning for non-web platforms
    if (!kIsWeb) {
      _configureCertificatePinning(dio);
    }

    // Add interceptors
    dio.interceptors.addAll([AuthInterceptor(), SecurityInterceptor()]);

    // Debug logging
    if (AppConfig.enableDebugLog) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (log) => debugPrint('[SecureAPI] $log'),
        ),
      );
    }

    return dio;
  }

  /// Configure certificate pinning
  void _configureCertificatePinning(Dio dio) {
    if (!CertificatePinningConfig.isEnabled) {
      debugPrint('⚠️ Certificate pinning disabled');
      return;
    }

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();

        // Set up certificate validation
        client.badCertificateCallback = (cert, host, port) {
          // In production, always return false for bad certificates
          if (AppConfig.isProduction) {
            debugPrint('❌ Bad certificate rejected for $host:$port');
            return false;
          }
          // In development, allow self-signed certificates
          debugPrint('⚠️ Allowing bad certificate for $host:$port (dev mode)');
          return true;
        };

        return client;
      },
      validateCertificate: (certificate, host, port) {
        if (certificate == null) {
          debugPrint('❌ No certificate provided');
          return false;
        }

        // Check if this is a pinned domain
        bool isPinnedDomain = CertificatePinningConfig.pinnedDomains.any(
          (domain) => _matchesDomain(host, domain),
        );

        if (!isPinnedDomain) {
          // Not a pinned domain, allow default validation
          return true;
        }

        // Validate against pinned certificates
        return _validateCertificate(certificate, host);
      },
    );

    debugPrint('🔒 Certificate pinning enabled');
  }

  /// Check if host matches domain pattern
  bool _matchesDomain(String host, String pattern) {
    if (pattern.startsWith('*.')) {
      final baseDomain = pattern.substring(2);
      return host.endsWith(baseDomain);
    }
    return host == pattern;
  }

  /// Validate certificate against pinned hashes
  bool _validateCertificate(X509Certificate certificate, String host) {
    final hashes = CertificatePinningConfig.pinnedCertificateHashes;

    if (hashes.isEmpty) {
      debugPrint('⚠️ No pinned certificates configured, allowing connection');
      return true;
    }

    // Get certificate's public key hash
    final certHash = _getCertificateHash(certificate);

    // Check if certificate hash matches any pinned hash
    for (final pinnedHash in hashes) {
      final hashValue = pinnedHash.replaceFirst('sha256/', '');
      if (certHash == hashValue) {
        debugPrint('✅ Certificate verified for $host');
        return true;
      }
    }

    debugPrint('❌ Certificate validation failed for $host');
    debugPrint('   Certificate hash: sha256/$certHash');
    debugPrint('   Expected hashes: $hashes');
    return false;
  }

  /// Get SHA-256 hash of certificate's public key
  String _getCertificateHash(X509Certificate certificate) {
    // In production, implement proper public key extraction and hashing
    // This is a simplified version
    final der = certificate.der;
    final hash = _sha256(der);
    return base64Encode(hash);
  }

  /// Simple SHA-256 implementation (use crypto package in production)
  Uint8List _sha256(Uint8List data) {
    // This should use a proper crypto library in production
    // For now, return the DER as-is (simplified)
    return data.sublist(0, 32);
  }
}

/// Security Interceptor for additional security measures
class SecurityInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add timestamp to prevent replay attacks
    options.headers['X-Request-Timestamp'] = DateTime.now()
        .toUtc()
        .toIso8601String();

    // Add nonce for additional security
    options.headers['X-Request-Nonce'] = _generateNonce();

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Validate response headers
    _validateSecurityHeaders(response);

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log security-related errors
    if (err.type == DioExceptionType.badCertificate) {
      debugPrint('🚨 SECURITY: Certificate validation failed!');
      debugPrint('   URL: ${err.requestOptions.uri}');
      // You might want to report this to your security monitoring system
    }

    super.onError(err, handler);
  }

  String _generateNonce() {
    final random = DateTime.now().microsecondsSinceEpoch;
    return random.toRadixString(36);
  }

  void _validateSecurityHeaders(Response response) {
    final headers = response.headers;

    // Check for security headers
    final requiredHeaders = [
      'x-content-type-options',
      'x-frame-options',
      'strict-transport-security',
    ];

    for (final header in requiredHeaders) {
      if (headers.value(header) == null) {
        debugPrint('⚠️ Missing security header: $header');
      }
    }
  }
}

/// Certificate Pinning Manager
class CertificatePinningManager {
  static CertificatePinningManager? _instance;
  final Map<String, List<String>> _pinnedCerts = {};

  CertificatePinningManager._internal();

  factory CertificatePinningManager() {
    _instance ??= CertificatePinningManager._internal();
    return _instance!;
  }

  /// Add pinned certificate hash for a domain
  void pinCertificate(String domain, String hash) {
    _pinnedCerts[domain] ??= [];
    _pinnedCerts[domain]!.add(hash);
  }

  /// Remove pinned certificate
  void unpinCertificate(String domain, String hash) {
    _pinnedCerts[domain]?.remove(hash);
  }

  /// Get pinned certificates for domain
  List<String> getPinnedCertificates(String domain) {
    return _pinnedCerts[domain] ?? [];
  }

  /// Clear all pinned certificates
  void clearAllPins() {
    _pinnedCerts.clear();
  }

  /// Update pinned certificates from server
  /// This allows dynamic certificate updates without app update
  Future<void> updateFromServer() async {
    // Implement secure certificate update mechanism
    // This should verify the integrity of the update
  }
}

/// Extension to check if app is in production
extension AppConfigExt on AppConfig {
  static bool get isProduction {
    // Check environment or build configuration
    return const bool.fromEnvironment('dart.vm.product', defaultValue: false);
  }
}
