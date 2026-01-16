import 'package:google_sign_in/google_sign_in.dart';
import 'package:workradar/core/storage/secure_storage.dart';
import 'package:workradar/core/network/api_client.dart';

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
    final action = isRegister ? 'Pendaftaran' : 'Login';
    print('[GoogleAuth] 🔵 Starting Google Sign-In (action: $action)');

    try {
      // Sign out first to ensure clean state and force account picker
      print('[GoogleAuth] 🔄 Signing out previous session (if any)...');
      await _googleSignIn.signOut();

      // Trigger Google Sign-In flow (shows native account picker)
      print('[GoogleAuth] 🚀 Triggering Google Sign-In picker...');
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        print('[GoogleAuth] ⚠️ User cancelled sign-in (account is null)');
        return null; // User cancelled
      }

      print('[GoogleAuth] ✅ Account selected: ${account.email}');
      print('[GoogleAuth] 📝 Display Name: ${account.displayName}');
      print('[GoogleAuth] 🆔 Account ID: ${account.id}');

      return account;
    } on Exception catch (e) {
      print('[GoogleAuth] ❌ Exception caught: ${e.runtimeType}');
      print('[GoogleAuth] 📄 Exception details: ${e.toString()}');

      // Get specific error message
      String errorMessage = '$action dengan Google gagal. Silakan coba lagi.';

      // Check for specific error types
      if (e.toString().contains('network_error') ||
          e.toString().contains('NetworkError')) {
        errorMessage = 'Tidak ada koneksi internet. Periksa jaringan Anda.';
        print('[GoogleAuth] 🌐 Detected network error');
      } else if (e.toString().contains('sign_in_canceled') ||
          e.toString().contains('ERROR_CANCELED') ||
          e.toString().contains('CANCEL')) {
        // User cancelled - return null instead of throwing
        print('[GoogleAuth] ⚠️ User cancelled sign-in (error contains CANCEL)');
        return null;
      } else if (e.toString().contains('sign_in_failed') ||
          e.toString().contains('ERROR_SIGN_IN_FAILED') ||
          e.toString().contains('SIGN_IN_FAILED')) {
        errorMessage =
            '$action dengan Google gagal. Pastikan Anda memilih akun Google yang valid.';
        print('[GoogleAuth] 🔴 Sign-in failed error detected');
      } else {
        // Unknown error - provide full details
        print('[GoogleAuth] ⁉️ Unknown error type');
      }

      throw GoogleAuthException(message: errorMessage, originalError: e);
    } catch (e) {
      // Handle non-Exception errors
      print('[GoogleAuth] 💥 Non-Exception error caught: ${e.runtimeType}');
      print('[GoogleAuth] 📄 Error details: ${e.toString()}');

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

    print('[GoogleAuth] 🔐 Getting Google auth token...');

    // Get authentication tokens from Google
    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;

    if (idToken == null) {
      throw GoogleAuthException(
        message: 'Gagal mendapatkan token dari Google.',
      );
    }

    print('[GoogleAuth] 🎫 ID Token obtained (length: ${idToken.length})');
    print('[GoogleAuth] 🌐 Calling backend API /auth/google/mobile...');

    try {
      // Call real backend API
      final apiClient = ApiClient();
      final response = await apiClient.post(
        '/auth/google/mobile',
        data: {'id_token': idToken},
      );

      print('[GoogleAuth] 📡 Backend response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;

        // Extract tokens and user info
        final String token = data['token'] ?? '';
        final String refreshToken = data['refresh_token'] ?? '';
        final bool isNewUser = data['is_new_user'] ?? false;
        final Map<String, dynamic>? userData = data['user'];

        print('[GoogleAuth] ✅ Backend authentication successful');
        print('[GoogleAuth] 👤 User: ${userData?['email']}');
        print('[GoogleAuth] 🆕 Is new user: $isNewUser');

        // Save tokens to secure storage
        print('[GoogleAuth] 💾 Saving tokens to secure storage...');
        await SecureStorage.saveAccessToken(token);
        await SecureStorage.saveRefreshToken(refreshToken);

        if (userData != null) {
          await SecureStorage.saveUserData(
            userId: userData['id'] ?? '',
            email: userData['email'] ?? '',
            userType: userData['user_type'] ?? 'regular',
          );

          // Save username if available
          if (userData['username'] != null) {
            await SecureStorage.saveUsername(userData['username']);
          }
        }

        // Verify tokens were saved
        final savedAccessToken = await SecureStorage.getAccessToken();
        final savedRefreshToken = await SecureStorage.getRefreshToken();
        final isLoggedIn = await SecureStorage.isLoggedIn();

        print('[GoogleAuth] 🔍 Post-save verification:');
        print(
          '[GoogleAuth]   - Access token exists: ${savedAccessToken != null}',
        );
        print(
          '[GoogleAuth]   - Refresh token exists: ${savedRefreshToken != null}',
        );
        print('[GoogleAuth]   - isLoggedIn: $isLoggedIn');

        return GoogleAuthResult(
          success: true,
          isNewUser: isNewUser,
          user: GoogleUserInfo(
            id: userData?['id'] ?? account.id,
            email: userData?['email'] ?? account.email,
            displayName: userData?['username'] ?? account.displayName ?? '',
            photoUrl: userData?['profile_picture'] ?? account.photoUrl,
          ),
        );
      } else {
        // Backend returned error
        final errorMsg =
            response.data['error'] ?? 'Autentikasi dengan backend gagal';
        print('[GoogleAuth] ❌ Backend error: $errorMsg');
        throw GoogleAuthException(message: errorMsg);
      }
    } catch (e) {
      print('[GoogleAuth] 💥 Backend API call failed: ${e.toString()}');

      if (e is GoogleAuthException) {
        rethrow;
      }

      throw GoogleAuthException(
        message:
            'Gagal terhubung ke server. Silakan coba lagi.\n\nDetail: ${e.toString()}',
        originalError: e,
      );
    }
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
