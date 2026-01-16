import 'package:google_sign_in/google_sign_in.dart';
import 'package:workradar/core/storage/secure_storage.dart';

/// Google Authentication Service
/// Handles Google Sign-In flow for login and registration
class GoogleAuthService {
  static final GoogleAuthService _instance = GoogleAuthService._internal();
  factory GoogleAuthService() => _instance;
  GoogleAuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  /// Current signed-in Google user
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Check if user is signed in with Google
  Future<bool> isSignedIn() async {
    return _googleSignIn.isSignedIn();
  }

  /// Sign in with Google
  /// Returns GoogleSignInAccount on success, null if cancelled
  /// Throws GoogleAuthException on error
  /// [isRegister] - true if called from registration flow, false for login
  Future<GoogleSignInAccount?> signIn({bool isRegister = false}) async {
    try {
      // Trigger Google Sign-In flow (shows native account picker)
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      return account;
    } on Exception catch (e) {
      // Determine error message based on context
      final action = isRegister ? 'Pendaftaran' : 'Login';

      // Get specific error message
      String errorMessage = '$action dengan Google gagal. Silakan coba lagi.';

      // Check for specific error types
      if (e.toString().contains('network_error') ||
          e.toString().contains('NetworkError')) {
        errorMessage = 'Tidak ada koneksi internet. Periksa jaringan Anda.';
      } else if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('ERROR_CANCELED')) {
        // User cancelled - return null instead of throwing
        return null;
      } else if (e.toString().contains('sign_in_failed') ||
          e.toString().contains('ERROR_SIGN_IN_FAILED')) {
        errorMessage =
            '$action dengan Google gagal. Pastikan Anda memilih akun Google yang valid.';
      }

      throw GoogleAuthException(message: errorMessage, originalError: e);
    } catch (e) {
      // Handle non-Exception errors
      final action = isRegister ? 'Pendaftaran' : 'Login';
      throw GoogleAuthException(
        message:
            '$action dengan Google gagal. Silakan coba lagi.\n\nDetail: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Sign out from Google
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      // Ignore sign out errors
    }
  }

  /// Disconnect Google account (revokes access)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    }
  }

  /// Authenticate with backend using Google credentials
  /// This handles both login and registration (backend decides)
  Future<GoogleAuthResult> authenticateWithBackend() async {
    final account = _googleSignIn.currentUser;
    if (account == null) {
      throw GoogleAuthException(
        message: 'Tidak ada akun Google yang terpilih.',
      );
    }

    // Get authentication tokens from Google
    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;

    if (idToken == null) {
      throw GoogleAuthException(
        message: 'Gagal mendapatkan token dari Google.',
      );
    }

    // For now, we simulate backend authentication
    // TODO: Replace with actual API call when backend is ready
    return _mockBackendAuth(account, idToken);
  }

  /// Mock backend authentication (to be replaced with real API call)
  Future<GoogleAuthResult> _mockBackendAuth(
    GoogleSignInAccount account,
    String idToken,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Simulate successful authentication
    // In real implementation, this would call:
    // final response = await _apiClient.post('/auth/google', data: {'id_token': idToken});

    // Create mock auth response
    final mockToken = 'mock_jwt_token_${DateTime.now().millisecondsSinceEpoch}';
    final mockRefreshToken =
        'mock_refresh_token_${DateTime.now().millisecondsSinceEpoch}';

    // Save mock auth data
    await SecureStorage.saveAccessToken(mockToken);
    await SecureStorage.saveRefreshToken(mockRefreshToken);
    await SecureStorage.saveUserData(
      userId: account.id,
      email: account.email,
      userType: 'regular',
    );

    // Determine if new user (for demo: always treat as existing for simplicity)
    // In real implementation, backend would tell us this
    final bool isNewUser = false;

    return GoogleAuthResult(
      success: true,
      isNewUser: isNewUser,
      user: GoogleUserInfo(
        id: account.id,
        email: account.email,
        displayName: account.displayName ?? '',
        photoUrl: account.photoUrl,
      ),
    );
  }
}

/// Result of Google authentication with backend
class GoogleAuthResult {
  final bool success;
  final bool isNewUser;
  final GoogleUserInfo? user;
  final String? error;

  GoogleAuthResult({
    required this.success,
    this.isNewUser = false,
    this.user,
    this.error,
  });
}

/// Google user information
class GoogleUserInfo {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;

  GoogleUserInfo({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });
}

/// Exception for Google Auth errors
class GoogleAuthException implements Exception {
  final String message;
  final dynamic originalError;

  GoogleAuthException({required this.message, this.originalError});

  @override
  String toString() => message;
}
