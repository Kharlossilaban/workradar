import 'package:dio/dio.dart';

/// Custom API Exception untuk error handling
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  @override
  String toString() => message;

  /// Create ApiException from DioException
  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Koneksi lambat. Silakan coba lagi.',
          statusCode: null,
        );

      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;

        // Extract error message dari backend
        String message = 'Terjadi kesalahan';
        if (data is Map && data.containsKey('error')) {
          message = data['error'].toString();
        } else if (data is String) {
          message = data;
        }

        // Map specific status codes to user-friendly messages
        switch (statusCode) {
          case 400:
            message = message; // Use backend message
            break;
          case 401:
            message = 'Sesi habis. Silakan login kembali.';
            break;
          case 403:
            message = 'Akses ditolak.';
            break;
          case 404:
            message = 'Data tidak ditemukan.';
            break;
          case 429:
            message = 'Terlalu banyak request. Tunggu sebentar.';
            break;
          case 500:
          case 502:
          case 503:
            message = 'Server sedang bermasalah. Coba lagi nanti.';
            break;
        }

        return ApiException(
          message: message,
          statusCode: statusCode,
          data: data,
        );

      case DioExceptionType.cancel:
        return ApiException(message: 'Request dibatalkan');

      case DioExceptionType.unknown:
        if (error.message?.contains('SocketException') ?? false) {
          return ApiException(message: 'Tidak ada koneksi internet');
        }
        return ApiException(message: 'Terjadi kesalahan. Coba lagi.');

      default:
        return ApiException(message: 'Terjadi kesalahan. Coba lagi.');
    }
  }
}
