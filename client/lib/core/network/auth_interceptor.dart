import 'package:dio/dio.dart';
import 'package:workradar/core/storage/secure_storage.dart';

/// Auth Interceptor untuk auto-inject token dan handle refresh
class AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip token injection untuk public endpoints
    final publicEndpoints = [
      '/auth/register',
      '/auth/login',
      '/auth/forgot-password',
      '/auth/reset-password',
      '/auth/refresh',
    ];

    final isPublicEndpoint = publicEndpoints.any(
      (endpoint) => options.path.contains(endpoint),
    );

    if (!isPublicEndpoint) {
      // Inject access token
      final accessToken = await SecureStorage.getAccessToken();
      if (accessToken != null) {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized (token expired)
    if (err.response?.statusCode == 401) {
      final errorMessage = err.response?.data['error']?.toString() ?? '';

      // Jika token expired, coba refresh
      if (errorMessage.contains('expired') ||
          errorMessage.contains('Invalid or expired token')) {
        try {
          // Get refresh token
          final refreshToken = await SecureStorage.getRefreshToken();
          if (refreshToken != null) {
            // Call refresh endpoint
            final dio = Dio(BaseOptions(baseUrl: err.requestOptions.baseUrl));

            final response = await dio.post(
              '/auth/refresh',
              data: {'refresh_token': refreshToken},
            );

            if (response.statusCode == 200) {
              // Save new access token
              final newAccessToken = response.data['access_token'];
              await SecureStorage.saveAccessToken(newAccessToken);

              // Retry original request dengan token baru
              final options = err.requestOptions;
              options.headers['Authorization'] = 'Bearer $newAccessToken';

              final retryResponse = await dio.fetch(options);
              return handler.resolve(retryResponse);
            }
          }
        } catch (refreshError) {
          // ONLY clear tokens if refresh endpoint specifically says token is invalid
          // Don't clear on network errors or server errors
          if (refreshError is DioException &&
              refreshError.response?.statusCode == 401) {
            // Refresh token juga invalid - benar-benar logout
            await SecureStorage.clearAll();
          }
          // Untuk network error atau server error, biarkan user tetap login
          // Mereka bisa coba lagi nanti saat network normal
        }
      }
    }

    handler.next(err);
  }
}
