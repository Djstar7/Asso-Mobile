import 'package:image_picker/image_picker.dart';
import '../../core/values/constants.dart';
import '../models/user_model.dart';
import 'api_provider.dart';
import 'storage_service.dart';
import '../../core/utils/session_reset.dart';
import '../../core/utils/session_scope.dart';

/// Authentication service with OTP support
class AuthService {
  static Future<ApiResponse> requestPasswordReset(String email) =>
      ApiProvider.post(AppConstants.forgotPasswordUrl, body: {'email': email});

  static Future<ApiResponse> resetPassword({
    required String email,
    required String code,
    required String password,
  }) => ApiProvider.post(
    AppConstants.resetPasswordUrl,
    body: {
      'email': email,
      'otp_code': code,
      'password': password,
      'password_confirmation': password,
    },
  );

  /// Send OTP to phone number (login/register)
  static Future<ApiResponse> sendOtp({
    required String phone,
    String countryCode = '+237',
  }) async {
    final response = await ApiProvider.post(
      AppConstants.sendOtpUrl,
      body: {'phone': phone, 'country_code': countryCode},
    );

    return response;
  }

  /// Verify OTP code and login
  static Future<ApiResponse> verifyOtp({
    required String fullPhone,
    required String otpCode,
  }) async {
    final response = await ApiProvider.post(
      AppConstants.verifyOtpUrl,
      body: {'phone': fullPhone, 'otp_code': otpCode},
    );

    if (response.success && response.data != null) {
      final token = response.data!['token'] as String?;
      final userData = response.data!['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        final user = UserModel.fromJson(userData);

        await StorageService.saveAuthSession(token, user);

        // Le mode invité laisse des controllers permanents et un cache anonymes :
        // les purger ici, une fois le token écrit, pour que l'app recharge tout
        // sous l'identité du compte qui vient de se connecter.
        SessionReset.onLogin();
      }
    }

    return response;
  }

  /// Login with phone and password (no OTP required)
  static Future<ApiResponse> login({
    required String phone,
    required String password,
    String countryCode = '+237',
  }) async {
    final response = await ApiProvider.post(
      AppConstants.loginUrl,
      body: {'phone': countryCode + phone, 'password': password},
    );

    if (response.success && response.data != null) {
      final token = response.data!['token'] as String?;
      final userData = response.data!['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        final user = UserModel.fromJson(userData);
        await StorageService.saveAuthSession(token, user);

        // Le mode invité laisse des controllers permanents et un cache anonymes :
        // les purger ici, une fois le token écrit, pour que l'app recharge tout
        // sous l'identité du compte qui vient de se connecter.
        SessionReset.onLogin();
      }
    }

    return response;
  }

  /// Register with email and password (sends OTP to email)
  static Future<ApiResponse> registerWithEmail({
    required String email,
    required String password,
    required String passwordConfirmation,
    String? firstName,
    String? lastName,
  }) async {
    final response = await ApiProvider.post(
      AppConstants.registerEmailUrl,
      body: {
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
      },
    );

    return response;
  }

  /// Login with email and password (no OTP required)
  static Future<ApiResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await ApiProvider.post(
      AppConstants.loginEmailUrl,
      body: {'email': email, 'password': password},
    );

    if (response.success && response.data != null) {
      final token = response.data!['token'] as String?;
      final userData = response.data!['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        final user = UserModel.fromJson(userData);
        await StorageService.saveAuthSession(token, user);

        // Le mode invité laisse des controllers permanents et un cache anonymes :
        // les purger ici, une fois le token écrit, pour que l'app recharge tout
        // sous l'identité du compte qui vient de se connecter.
        SessionReset.onLogin();
      }
    }

    return response;
  }

  /// Verify OTP sent to email after registration
  static Future<ApiResponse> verifyEmailOtp({
    required String email,
    required String otpCode,
  }) async {
    final response = await ApiProvider.post(
      AppConstants.verifyEmailOtpUrl,
      body: {'email': email, 'otp_code': otpCode},
    );

    if (response.success && response.data != null) {
      final token = response.data!['token'] as String?;
      final userData = response.data!['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        final user = UserModel.fromJson(userData);

        await StorageService.saveAuthSession(token, user);

        // Le mode invité laisse des controllers permanents et un cache anonymes :
        // les purger ici, une fois le token écrit, pour que l'app recharge tout
        // sous l'identité du compte qui vient de se connecter.
        SessionReset.onLogin();
      }
    }

    return response;
  }

  /// Get user profile from API
  static Future<ApiResponse> getProfile() async {
    final response = await ApiProvider.get(AppConstants.profileUrl);

    if (response.success && response.data != null) {
      final userData = response.data!['user'] as Map<String, dynamic>?;
      if (userData != null) {
        final user = UserModel.fromJson(userData);
        await StorageService.saveUser(user);
      }
    }

    return response;
  }

  /// Update user profile
  ///
  /// Avec [avatar], l'envoi passe en multipart. PHP ne lit pas le corps
  /// multipart d'une requête PUT : on poste avec `_method=PUT`, que Laravel
  /// route vers la même action.
  static Future<ApiResponse> updateProfile(
    Map<String, dynamic> data, {
    XFile? avatar,
  }) async {
    final response = avatar == null
        ? await ApiProvider.put(AppConstants.profileUrl, body: data)
        : await ApiProvider.multipart(
            AppConstants.profileUrl,
            fields: {
              for (final entry in data.entries)
                if (entry.value != null) entry.key: entry.value.toString(),
              '_method': 'PUT',
            },
            mediaFiles: {'avatar': avatar},
          );

    if (response.success && response.data != null) {
      final userData = response.data!['user'] as Map<String, dynamic>?;
      if (userData != null) {
        final user = UserModel.fromJson(userData);
        await StorageService.saveUser(user);
      }
    }

    return response;
  }

  /// Get user preferences from backend
  static Future<ApiResponse> getPreferences() async {
    final response = await ApiProvider.get(AppConstants.getPreferencesUrl);

    return response;
  }

  /// Update user preferences
  static Future<ApiResponse> updatePreferences(
    Map<String, dynamic> preferences,
  ) async {
    final response = await ApiProvider.put(
      AppConstants.updatePreferencesUrl,
      body: {'preferences': preferences},
    );

    if (response.success) {
      StorageService.savePreferences(preferences);

      // Update user preferences in cached user
      final currentUser = StorageService.getUser();
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(preferences: preferences);
        await StorageService.saveUser(updatedUser);
      }
    }

    return response;
  }

  /// Request phone number change - sends OTP to new number
  static Future<ApiResponse> requestPhoneChange({
    required String newPhone,
    String countryCode = '+237',
  }) async {
    final response = await ApiProvider.post(
      AppConstants.requestPhoneChangeUrl,
      body: {'new_phone': newPhone, 'country_code': countryCode},
    );

    return response;
  }

  /// Confirm phone number change with OTP
  static Future<ApiResponse> confirmPhoneChange({
    required String newPhone,
    required String otpCode,
    String countryCode = '+237',
  }) async {
    final response = await ApiProvider.post(
      AppConstants.confirmPhoneChangeUrl,
      body: {
        'new_phone': newPhone,
        'otp_code': otpCode,
        'country_code': countryCode,
      },
    );

    if (response.success && response.data != null) {
      final token = response.data!['token'] as String?;
      final userData = response.data!['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        final user = UserModel.fromJson(userData);
        await StorageService.saveAuthSession(token, user);
      }
    }

    return response;
  }

  /// Delete account
  static Future<ApiResponse> deleteAccount() async {
    final session = SessionScope.current;
    final response = await ApiProvider.post(AppConstants.deleteAccountUrl);

    if (response.success && SessionScope.isCurrent(session)) {
      // Clear local session
      await StorageService.clearAuth();
    }

    return response;
  }

  /// Logout
  static Future<ApiResponse> logout() async {
    final session = SessionScope.current;
    // Remove this session's device without disconnecting the other devices.
    final response = await ApiProvider.post(
      AppConstants.logoutUrl,
      body: {'fcm_token': StorageService.registeredFcmToken},
    );

    if (!SessionScope.isCurrent(session)) return response;

    // Clear local session regardless of API response
    await StorageService.clearAuth();

    // Réinitialiser l'état applicatif lié à l'ancien compte (controllers GetX
    // permanents, WebSocket) pour éviter que les données d'un utilisateur
    // ne persistent au logout ou au changement de compte.
    // `clearAuth` vide déjà le cache ; `clearControllers` suffit donc ici.
    SessionReset.clearControllers();

    return response;
  }

  // ==================== Getters ====================

  /// Check if user is logged in
  static bool get isLoggedIn {
    final loggedIn = StorageService.isAuthenticated;
    return loggedIn;
  }

  /// Get cached user
  static UserModel? get currentUser {
    final user = StorageService.getUser();
    return user;
  }

  /// Get auth token
  static String? get token {
    return StorageService.getToken();
  }
}
