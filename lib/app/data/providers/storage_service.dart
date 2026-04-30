import 'dart:developer' as developer;
import 'package:get_storage/get_storage.dart';
import '../../core/values/constants.dart';
import '../models/user_model.dart';
import 'cache_manager.dart';

/// Service for managing local storage (tokens, user data, preferences)
class StorageService {
  static final GetStorage _storage = GetStorage();

  /// Check if storage is initialized
  static bool get isInitialized {
    try {
      _storage.read('test');
      return true;
    } catch (e) {
      developer.log(
        'StorageService NOT initialized',
        name: 'StorageService',
        error: e,
      );
      return false;
    }
  }

  // ==================== Token Management ====================

  /// Save authentication token
  static void saveToken(String token) {
    developer.log(
      'Saving auth token',
      name: 'StorageService',
      error: 'Token length: ${token.length}',
    );
    _storage.write(AppConstants.keyToken, token);
  }

  /// Get stored token
  static String? getToken() {
    final token = _storage.read<String>(AppConstants.keyToken);
    developer.log(
      'Retrieved token',
      name: 'StorageService',
      error: token != null ? 'Token exists (${token.length} chars)' : 'No token found',
    );
    return token;
  }

  /// Check if user has valid token
  static bool get hasToken {
    final token = getToken();
    final hasValidToken = token != null && token.isNotEmpty;
    developer.log(
      'Token check: $hasValidToken',
      name: 'StorageService',
    );
    return hasValidToken;
  }

  /// Remove token
  static void clearToken() {
    developer.log('Clearing auth token', name: 'StorageService');
    _storage.remove(AppConstants.keyToken);
  }

  // ==================== User Data Management ====================

  /// Save user data to storage
  static void saveUser(UserModel user) {
    developer.log(
      'Saving user data',
      name: 'StorageService',
      error: 'User: ${user.toString()}',
    );
    _storage.write(AppConstants.keyUser, user.toJson());
  }

  /// Get cached user data
  static UserModel? getUser() {
    try {
      final data = _storage.read(AppConstants.keyUser);
      if (data == null) {
        developer.log('No cached user found', name: 'StorageService');
        return null;
      }

      Map<String, dynamic> userData;
      if (data is Map<String, dynamic>) {
        userData = data;
      } else {
        userData = Map<String, dynamic>.from(data);
      }

      final user = UserModel.fromJson(userData);
      developer.log(
        'Retrieved cached user',
        name: 'StorageService',
        error: 'User: ${user.toString()}',
      );
      return user;
    } catch (e, stackTrace) {
      developer.log(
        'Error getting cached user',
        name: 'StorageService',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Update user data
  static void updateUser(UserModel user) {
    saveUser(user);
  }

  /// Remove user data
  static void clearUser() {
    developer.log('Clearing user data', name: 'StorageService');
    _storage.remove(AppConstants.keyUser);
  }

  // ==================== Preferences Management ====================

  /// Save user preferences
  static void savePreferences(Map<String, dynamic> preferences) {
    developer.log(
      'Saving preferences',
      name: 'StorageService',
      error: 'Preferences: $preferences',
    );
    _storage.write(AppConstants.keyPreferences, preferences);
  }

  /// Get user preferences
  static Map<String, dynamic>? getPreferences() {
    try {
      final data = _storage.read(AppConstants.keyPreferences);
      if (data == null) return null;

      if (data is Map<String, dynamic>) {
        return data;
      }
      return Map<String, dynamic>.from(data);
    } catch (e) {
      developer.log(
        'Error getting preferences',
        name: 'StorageService',
        error: e,
      );
      return null;
    }
  }

  /// Clear preferences
  static void clearPreferences() {
    developer.log('Clearing preferences', name: 'StorageService');
    _storage.remove(AppConstants.keyPreferences);
  }

  // ==================== Onboarding Management ====================

  /// Mark onboarding as completed
  static void setOnboardingDone() {
    developer.log('Marking onboarding as done', name: 'StorageService');
    _storage.write(AppConstants.keyOnboardingDone, true);
  }

  /// Check if onboarding was completed
  static bool get isOnboardingDone {
    final done = _storage.read(AppConstants.keyOnboardingDone) ?? false;
    developer.log('Onboarding done: $done', name: 'StorageService');
    return done;
  }

  /// Clear onboarding flag
  static void clearOnboardingFlag() {
    _storage.remove(AppConstants.keyOnboardingDone);
  }

  // ==================== Theme Management ====================

  /// Save theme mode
  static void saveThemeMode(String mode) {
    developer.log('Saving theme mode: $mode', name: 'StorageService');
    _storage.write(AppConstants.keyThemeMode, mode);
  }

  /// Get theme mode
  static String? getThemeMode() {
    return _storage.read<String>(AppConstants.keyThemeMode);
  }

  // ==================== Session Management ====================

  /// Check if user is authenticated
  static bool get isAuthenticated {
    final authenticated = hasToken && getUser() != null;
    developer.log(
      'Authentication check: $authenticated',
      name: 'StorageService',
    );
    return authenticated;
  }

  /// Clear all authentication data (logout)
  static void clearAuth() {
    developer.log(
      '========== LOGOUT: Clearing all auth data ==========',
      name: 'StorageService',
    );
    clearToken();
    clearUser();
    clearPreferences();
    clearCurrency(); // Clear currency selection
    clearCountry(); // Clear country selection
    disableGuestMode(); // Also disable guest mode on logout

    // Clear all cache data
    try {
      CacheManager().clearAll();
      developer.log('Cache cleared successfully', name: 'StorageService');
    } catch (e) {
      developer.log(
        'Error clearing cache',
        name: 'StorageService',
        error: e,
      );
    }

    developer.log(
      'All user data cleared: token, user, preferences, currency, country, cache',
      name: 'StorageService',
    );
  }

  /// Clear all storage data
  static void clearAll() {
    developer.log(
      '========== CLEARING ALL STORAGE ==========',
      name: 'StorageService',
    );
    _storage.erase();
  }

  /// Save complete auth session (token + user)
  static void saveAuthSession(String token, UserModel user) {
    developer.log(
      '========== SAVING AUTH SESSION ==========',
      name: 'StorageService',
      error: 'Token length: ${token.length}, User: ${user.toString()}',
    );
    saveToken(token);
    saveUser(user);
    disableGuestMode(); // Disable guest mode when user logs in
  }

  /// Clear auth session (token + user)
  static void clearAuthSession() {
    developer.log(
      '========== CLEARING AUTH SESSION ==========',
      name: 'StorageService',
    );
    _storage.remove(AppConstants.keyToken);
    _storage.remove(AppConstants.keyUser);
  }

  // ==================== Currency Management ====================

  /// Save user currency
  static void saveCurrency(Map<String, dynamic> currency) {
    developer.log(
      'Saving currency data',
      name: 'StorageService',
      error: 'Currency: $currency',
    );
    _storage.write('user_currency', currency);
  }

  /// Get saved currency
  static Map<String, dynamic>? getCurrency() {
    try {
      final data = _storage.read('user_currency');
      if (data == null) {
        developer.log('No cached currency found', name: 'StorageService');
        return null;
      }

      if (data is Map<String, dynamic>) {
        return data;
      }
      return Map<String, dynamic>.from(data);
    } catch (e) {
      developer.log(
        'Error getting cached currency',
        name: 'StorageService',
        error: e,
      );
      return null;
    }
  }

  /// Clear currency data
  static void clearCurrency() {
    developer.log('Clearing currency data', name: 'StorageService');
    _storage.remove('user_currency');
  }

  // ==================== Country Management ====================

  /// Save user selected country
  static void saveCountry(String country) {
    developer.log(
      'Saving selected country',
      name: 'StorageService',
      error: 'Country: $country',
    );
    _storage.write('user_country', country);
  }

  /// Get saved country
  static String? getCountry() {
    try {
      final country = _storage.read('user_country');
      if (country == null) {
        developer.log('No saved country found', name: 'StorageService');
        return null;
      }
      return country as String;
    } catch (e) {
      developer.log(
        'Error getting saved country',
        name: 'StorageService',
        error: e,
      );
      return null;
    }
  }

  /// Clear country data
  static void clearCountry() {
    developer.log('Clearing country data', name: 'StorageService');
    _storage.remove('user_country');
  }

  /// Check if user has selected a country
  static bool get hasSelectedCountry => getCountry() != null;

  // ==================== Guest Mode Management ====================

  /// Enable guest mode (skip authentication)
  static void enableGuestMode() {
    developer.log('Enabling guest mode', name: 'StorageService');
    _storage.write('guest_mode', true);
  }

  /// Disable guest mode
  static void disableGuestMode() {
    developer.log('Disabling guest mode', name: 'StorageService');
    _storage.remove('guest_mode');
  }

  /// Check if user is in guest mode
  static bool get isGuestMode {
    final isGuest = _storage.read('guest_mode') ?? false;
    developer.log('Guest mode: $isGuest', name: 'StorageService');
    return isGuest;
  }
}
