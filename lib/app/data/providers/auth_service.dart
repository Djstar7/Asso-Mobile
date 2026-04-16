import 'dart:developer' as developer;
import '../../core/values/constants.dart';
import '../models/user_model.dart';
import 'api_provider.dart';
import 'storage_service.dart';

/// Authentication service with OTP support
class AuthService {
  /// Send OTP to phone number (login/register)
  static Future<ApiResponse> sendOtp({
    required String phone,
    String countryCode = '+237',
  }) async {
    developer.log(
      '========== SEND OTP ==========',
      name: 'AuthService',
      error: 'Phone: $countryCode$phone',
    );

    final response = await ApiProvider.post(AppConstants.sendOtpUrl, body: {
      'phone': phone,
      'country_code': countryCode,
    });

    developer.log(
      'OTP sent response',
      name: 'AuthService',
      error: 'Success: ${response.success}, Message: ${response.message}',
    );

    // Log OTP code in development mode
    if (response.success && response.data != null && response.data!.containsKey('otp_code')) {
      developer.log(
        '⚠️ DEV MODE - OTP CODE: ${response.data!['otp_code']}',
        name: 'AuthService',
      );
    }

    return response;
  }

  /// Verify OTP code and login
  static Future<ApiResponse> verifyOtp({
    required String fullPhone,
    required String otpCode,
  }) async {
    developer.log(
      '========== VERIFY OTP ==========',
      name: 'AuthService',
      error: 'Phone: $fullPhone, OTP: $otpCode',
    );

    final response = await ApiProvider.post(AppConstants.verifyOtpUrl, body: {
      'phone': fullPhone,
      'otp_code': otpCode,
    });

    developer.log(
      'OTP verification response',
      name: 'AuthService',
      error: 'Success: ${response.success}, Message: ${response.message}',
    );

    if (response.success && response.data != null) {
      print('');
      print('========================================');
      print('✅ OTP VERIFICATION SUCCESS');
      developer.log('✓ OTP Verification SUCCESS', name: 'AuthService');

      final token = response.data!['token'] as String?;
      final userData = response.data!['user'] as Map<String, dynamic>?;
      final isNewUser = response.data!['is_new_user'] as bool? ?? false;

      print('📦 Response data: Token=${token != null ? "EXISTS (${token.substring(0, 20)}...)" : "NULL"}, User=${userData != null ? "EXISTS" : "NULL"}');
      developer.log(
        'Response data: Token=${token != null ? "EXISTS (${token.substring(0, 20)}...)" : "NULL"}, User=${userData != null ? "EXISTS" : "NULL"}',
        name: 'AuthService',
      );

      if (token != null && userData != null) {
        print('💾 Saving auth session to storage (isNewUser: $isNewUser)');
        developer.log(
          '→ Saving auth session to storage',
          name: 'AuthService',
          error: 'Is new user: $isNewUser',
        );

        final user = UserModel.fromJson(userData);
        print('👤 User created from JSON: ID=${user.id}, Phone=${user.phone}, ProfileComplete=${user.isProfileComplete}');
        developer.log(
          'User created from JSON: ID=${user.id}, Phone=${user.phone}, ProfileComplete=${user.isProfileComplete}',
          name: 'AuthService',
        );

        StorageService.saveAuthSession(token, user);

        print('✅ Session saved successfully');
        developer.log(
          '✓ Session saved successfully',
          name: 'AuthService',
          error: 'User: ${user.toString()}',
        );

        // Verify it was actually saved
        final savedToken = StorageService.getToken();
        final savedUser = StorageService.getUser();
        print('🔍 Verification: Token saved=${savedToken != null}, User saved=${savedUser != null}');
        developer.log(
          'Verification: Token saved=${savedToken != null}, User saved=${savedUser != null}',
          name: 'AuthService',
        );
        print('========================================');
        print('');
      } else {
        print('❌ Invalid response data - missing token or user');
        print('   Token: ${token != null}, User: ${userData != null}');
        developer.log(
          '✗ Invalid response data - missing token or user',
          name: 'AuthService',
          error: 'Token: ${token != null}, User: ${userData != null}',
        );
        print('========================================');
        print('');
      }
    } else {
      print('❌ OTP verification failed');
      print('   Success: ${response.success}, Message: ${response.message}');
      developer.log(
        '✗ OTP verification failed',
        name: 'AuthService',
        error: 'Success: ${response.success}, Message: ${response.message}',
      );
    }

    return response;
  }

  /// Login with phone and password (no OTP required)
  static Future<ApiResponse> login({
    required String phone,
    required String password,
    String countryCode = '+237',
  }) async {
    developer.log(
      '========== LOGIN ==========',
      name: 'AuthService',
      error: 'Phone: $countryCode$phone',
    );

    final response = await ApiProvider.post(AppConstants.loginUrl, body: {
      'phone': countryCode + phone,
      'password': password,
    });

    developer.log(
      'Login response',
      name: 'AuthService',
      error: 'Success: ${response.success}, Message: ${response.message}',
    );

    if (response.success && response.data != null) {
      final token = response.data!['token'] as String?;
      final userData = response.data!['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        developer.log(
          'Login successful - saving session',
          name: 'AuthService',
        );

        final user = UserModel.fromJson(userData);
        StorageService.saveAuthSession(token, user);

        developer.log(
          'Session saved',
          name: 'AuthService',
          error: 'User: ${user.toString()}',
        );
      } else {
        developer.log(
          'Invalid response data - missing token or user',
          name: 'AuthService',
          error: 'Token: ${token != null}, User: ${userData != null}',
        );
      }
    } else {
      developer.log(
        'Login failed',
        name: 'AuthService',
        error: 'Message: ${response.message}',
      );
    }

    return response;
  }

  /// Get user profile from API
  static Future<ApiResponse> getProfile() async {
    developer.log('========== GET PROFILE ==========', name: 'AuthService');

    final response = await ApiProvider.get(AppConstants.profileUrl);

    developer.log(
      'Profile fetch response',
      name: 'AuthService',
      error: 'Success: ${response.success}',
    );

    if (response.success && response.data != null) {
      final userData = response.data!['user'] as Map<String, dynamic>?;
      if (userData != null) {
        final user = UserModel.fromJson(userData);
        StorageService.saveUser(user);

        developer.log(
          'Profile updated',
          name: 'AuthService',
          error: 'User: ${user.toString()}',
        );
      }
    }

    return response;
  }

  /// Update user profile
  static Future<ApiResponse> updateProfile(Map<String, dynamic> data) async {
    developer.log(
      '========== UPDATE PROFILE ==========',
      name: 'AuthService',
      error: 'Data: $data',
    );

    final response = await ApiProvider.put(AppConstants.profileUrl, body: data);

    developer.log(
      'Profile update response',
      name: 'AuthService',
      error: 'Success: ${response.success}',
    );

    if (response.success && response.data != null) {
      final userData = response.data!['user'] as Map<String, dynamic>?;
      if (userData != null) {
        final user = UserModel.fromJson(userData);
        StorageService.saveUser(user);

        developer.log(
          'Profile saved',
          name: 'AuthService',
          error: 'User: ${user.toString()}',
        );
      }
    }

    return response;
  }

  /// Get user preferences from backend
  static Future<ApiResponse> getPreferences() async {
    developer.log(
      '========== GET PREFERENCES ==========',
      name: 'AuthService',
    );

    final response = await ApiProvider.get(AppConstants.getPreferencesUrl);

    developer.log(
      'Preferences fetch response',
      name: 'AuthService',
      error: 'Success: ${response.success}',
    );

    return response;
  }

  /// Update user preferences
  static Future<ApiResponse> updatePreferences(Map<String, dynamic> preferences) async {
    developer.log(
      '========== UPDATE PREFERENCES ==========',
      name: 'AuthService',
      error: 'Preferences: $preferences',
    );

    final response = await ApiProvider.put(AppConstants.updatePreferencesUrl, body: {
      'preferences': preferences,
    });

    developer.log(
      'Preferences update response',
      name: 'AuthService',
      error: 'Success: ${response.success}',
    );

    if (response.success) {
      StorageService.savePreferences(preferences);

      // Update user preferences in cached user
      final currentUser = StorageService.getUser();
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(preferences: preferences);
        StorageService.saveUser(updatedUser);
      }
    }

    return response;
  }

  /// Request phone number change - sends OTP to new number
  static Future<ApiResponse> requestPhoneChange({
    required String newPhone,
    String countryCode = '+237',
  }) async {
    developer.log(
      '========== REQUEST PHONE CHANGE ==========',
      name: 'AuthService',
      error: 'New phone: $countryCode$newPhone',
    );

    final response = await ApiProvider.post(AppConstants.requestPhoneChangeUrl, body: {
      'new_phone': newPhone,
      'country_code': countryCode,
    });

    developer.log(
      'Phone change request response',
      name: 'AuthService',
      error: 'Success: ${response.success}, Message: ${response.message}',
    );

    // Log OTP code in development mode
    if (response.success && response.data != null && response.data!.containsKey('otp_code')) {
      developer.log(
        '⚠️ DEV MODE - OTP CODE: ${response.data!['otp_code']}',
        name: 'AuthService',
      );
    }

    return response;
  }

  /// Confirm phone number change with OTP
  static Future<ApiResponse> confirmPhoneChange({
    required String newPhone,
    required String otpCode,
    String countryCode = '+237',
  }) async {
    developer.log(
      '========== CONFIRM PHONE CHANGE ==========',
      name: 'AuthService',
      error: 'New phone: $newPhone, OTP: $otpCode',
    );

    final response = await ApiProvider.post(AppConstants.confirmPhoneChangeUrl, body: {
      'new_phone': newPhone,
      'otp_code': otpCode,
      'country_code': countryCode,
    });

    developer.log(
      'Phone change confirmation response',
      name: 'AuthService',
      error: 'Success: ${response.success}, Message: ${response.message}',
    );

    if (response.success && response.data != null) {
      final token = response.data!['token'] as String?;
      final userData = response.data!['user'] as Map<String, dynamic>?;

      if (token != null && userData != null) {
        developer.log(
          'Phone changed successfully - saving new session',
          name: 'AuthService',
        );

        final user = UserModel.fromJson(userData);
        StorageService.saveAuthSession(token, user);

        developer.log(
          'New session saved',
          name: 'AuthService',
          error: 'User: ${user.toString()}',
        );
      }
    }

    return response;
  }

  /// Delete account
  static Future<ApiResponse> deleteAccount() async {
    developer.log('========== DELETE ACCOUNT ==========', name: 'AuthService');

    final response = await ApiProvider.post(AppConstants.deleteAccountUrl);

    developer.log(
      'Delete account response',
      name: 'AuthService',
      error: 'Success: ${response.success}',
    );

    if (response.success) {
      // Clear local session
      StorageService.clearAuth();
      developer.log('Account deleted - local session cleared', name: 'AuthService');
    }

    return response;
  }

  /// Logout
  static Future<ApiResponse> logout() async {
    developer.log('========== LOGOUT ==========', name: 'AuthService');

    // Le backend supprime automatiquement tous les tokens FCM lors du logout
    final response = await ApiProvider.post(AppConstants.logoutUrl);

    developer.log(
      'Logout response',
      name: 'AuthService',
      error: 'Success: ${response.success}',
    );

    // Clear local session regardless of API response
    StorageService.clearAuth();

    developer.log('Local session cleared', name: 'AuthService');

    return response;
  }

  // ==================== Getters ====================

  /// Check if user is logged in
  static bool get isLoggedIn {
    final loggedIn = StorageService.isAuthenticated;
    developer.log('Is logged in: $loggedIn', name: 'AuthService');
    return loggedIn;
  }

  /// Get cached user
  static UserModel? get currentUser {
    final user = StorageService.getUser();
    developer.log(
      'Get current user',
      name: 'AuthService',
      error: user != null ? 'User: ${user.toString()}' : 'No user cached',
    );
    return user;
  }

  /// Get auth token
  static String? get token {
    return StorageService.getToken();
  }
}
