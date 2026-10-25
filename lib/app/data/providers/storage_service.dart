import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import '../../core/utils/session_scope.dart';
import 'secure_vault.dart';
import 'offline_store.dart';
import 'private_exports.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/values/constants.dart';
import '../models/user_model.dart';
import 'cache_manager.dart';

/// Service for managing local storage (tokens, user data, preferences)
class StorageService {
  static final GetStorage _storage = GetStorage();
  static const _sessionKey = 'asso_session_v1';
  static const _revokedKey = 'session_revoked_v1';
  static String? _token;
  static UserModel? _user;

  /// Called before any authenticated request or background service starts.
  static Future<void> initSecureStorage() async {
    final revoked = _storage.read<bool>(_revokedKey) == true;
    if (revoked) {
      _token = null;
      _user = null;
      await SecureVault.write(_sessionKey, null);
    }
    final encoded = revoked
        ? null
        : await SecureVault.storage.read(key: _sessionKey);
    if (encoded != null) {
      final data = jsonDecode(encoded) as Map<String, dynamic>;
      _token = data['token'] as String?;
      _user = data['user'] is Map
          ? UserModel.fromJson(Map<String, dynamic>.from(data['user']))
          : null;
    } else {
      final legacyToken = _storage.read<String>(AppConstants.keyToken);
      final legacyUser = _storage.read(AppConstants.keyUser);
      if (!revoked && legacyToken != null && legacyUser is Map) {
        _token = legacyToken;
        _user = UserModel.fromJson(Map<String, dynamic>.from(legacyUser));
        // Commit securely before deleting the legacy copy.
        await _persistSession();
      }
    }
    await _storage.remove(AppConstants.keyToken);
    await _storage.remove(AppConstants.keyUser);
    // GetStorage's backup is asynchronous. Sanitize its recovery copy too.
    if (!kIsWeb) {
      final directory = await getApplicationDocumentsDirectory();
      final backup = File('${directory.path}/GetStorage.bak');
      if (await backup.exists()) {
        final values = <String, dynamic>{
          for (final key in _storage.getKeys<Iterable<dynamic>>())
            key.toString(): _storage.read(key.toString()),
        };
        await backup.writeAsString(jsonEncode(values), flush: true);
      }
    }
    SessionScope.invalidate();
    userRevision.value++;
  }

  static Future<void> _persistSession() async {
    final session = SessionScope.current;
    final authenticated = _token != null && _user != null;
    final encoded = _token == null && _user == null
        ? null
        : jsonEncode({'token': _token, 'user': _user?.toJson()});
    try {
      await SecureVault.write(_sessionKey, encoded);
      if (authenticated && SessionScope.isCurrent(session)) {
        await _storage.remove(_revokedKey);
      }
    } catch (error, stack) {
      if (SessionScope.isCurrent(session)) {
        _token = null;
        _user = null;
        SessionScope.invalidate();
        userRevision.value++;
        await _storage.write(_revokedKey, true);
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  /// Check if storage is initialized
  static bool get isInitialized {
    try {
      _storage.read('test');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== Token Management ====================

  /// Save authentication token
  static Future<void> saveToken(String token) {
    SessionScope.invalidate();
    _token = token.isEmpty ? null : token;
    return _persistSession();
  }

  static String? getToken() => _token;
  static bool get hasToken => _token != null && _token!.isNotEmpty;

  static Future<void> clearToken() {
    _storage.write(_revokedKey, true);
    SessionScope.invalidate();
    _token = null;
    return _persistSession();
  }

  // ==================== User Data Management ====================

  /// Incrémenté à chaque écriture ou effacement de l'utilisateur en cache.
  ///
  /// Le cache n'est pas réactif : les écrans qui affichent l'identité
  /// (photo de profil, nom) l'observent pour se redessiner dès qu'un profil
  /// est enregistré, où que ce soit dans l'application.
  static final RxInt userRevision = 0.obs;

  /// Save user data to storage
  static Future<void> saveUser(UserModel user) {
    if (_user?.id != user.id) SessionScope.invalidate();
    _user = user;
    userRevision.value++;
    return _persistSession();
  }

  static UserModel? getUser() => _user;

  /// Update user data
  static Future<void> updateUser(UserModel user) => saveUser(user);

  /// Remove user data
  static Future<void> clearUser() {
    SessionScope.invalidate();
    _user = null;
    userRevision.value++;
    return _persistSession();
  }

  // ==================== Preferences Management ====================

  /// Save user preferences
  static void savePreferences(Map<String, dynamic> preferences) {
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
      return null;
    }
  }

  /// Retenir que l'écran des centres d'intérêt a déjà été proposé.
  ///
  /// Il s'affiche une seule fois, y compris en mode invité : le reproposer
  /// à chaque ouverture harcèlerait celui qui veut seulement regarder.
  static void setPreferencesPrompted() {
    _storage.write(AppConstants.keyPreferencesPrompted, true);
  }

  /// Vrai si l'écran des centres d'intérêt a déjà été proposé.
  static bool get wasPreferencesPrompted =>
      _storage.read(AppConstants.keyPreferencesPrompted) ?? false;

  /// Clear preferences
  static void clearPreferences() {
    _storage.remove(AppConstants.keyPreferences);
    _storage.remove(AppConstants.keyPreferencesPrompted);
  }

  // ==================== Onboarding Management ====================

  /// Mark onboarding as completed
  static void setOnboardingDone() {
    _storage.write(AppConstants.keyOnboardingDone, true);
  }

  /// Check if onboarding was completed
  static bool get isOnboardingDone {
    final done = _storage.read(AppConstants.keyOnboardingDone) ?? false;
    return done;
  }

  /// Clear onboarding flag
  static void clearOnboardingFlag() {
    _storage.remove(AppConstants.keyOnboardingDone);
  }

  // ==================== Theme Management ====================

  /// Save theme mode
  static void saveThemeMode(String mode) {
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
    return authenticated;
  }

  /// Clear all authentication data (logout)
  static Future<void> clearAuth() {
    final scope = getUser()?.id;
    final retiredSession = SessionScope.current;
    final cleared = clearAuthSession();
    final snapshots = OfflineStore.clearSnapshotsFor(scope);
    final exports = kIsWeb
        ? Future<void>.value()
        : PrivateExports.cleanup(retiredSession: retiredSession);
    clearPreferences();
    clearCurrency(); // Clear currency selection
    clearCountry(); // Clear country selection
    disableGuestMode(); // Also disable guest mode on logout
    clearFcmRegistration();

    // Clear all cache data
    try {
      CacheManager().clearAll();
    } catch (e) {}

    return Future.wait([cleared, snapshots, exports]);
  }

  /// Clear all storage data
  static Future<void> clearAll() async {
    await clearAuth();
    await _storage.erase();
  }

  /// Memory switches synchronously; durable writes remain ordered.
  static Future<void> saveAuthSession(String token, UserModel user) {
    SessionScope.invalidate();
    _token = token;
    _user = user;
    userRevision.value++;
    disableGuestMode();
    return _persistSession();
  }

  static Future<void> clearAuthSession() {
    _storage.write(_revokedKey, true);
    SessionScope.invalidate();
    _token = null;
    _user = null;
    userRevision.value++;
    return _persistSession();
  }

  // ==================== Currency Management ====================

  /// Save user currency
  static void saveCurrency(Map<String, dynamic> currency) {
    _storage.write('user_currency', currency);
  }

  /// Get saved currency
  static Map<String, dynamic>? getCurrency() {
    try {
      final data = _storage.read('user_currency');
      if (data == null) {
        return null;
      }

      if (data is Map<String, dynamic>) {
        return data;
      }
      return Map<String, dynamic>.from(data);
    } catch (e) {
      return null;
    }
  }

  /// Clear currency data
  static void clearCurrency() {
    _storage.remove('user_currency');
  }

  /// Dernier taux connu « 1 [code] = rate XAF », pour afficher les prix convertis
  /// dès le démarrage et hors ligne, sans attendre l'API.
  static void saveExchangeRate(String code, double rate) {
    _storage.write('user_currency_rate', {
      'code': code,
      'rate': rate,
      'fetched_at': DateTime.now().toIso8601String(),
    });
  }

  /// Taux enregistré pour [code], ou null s'il n'y en a pas (ou pour une autre devise).
  static ({double rate, DateTime fetchedAt})? getExchangeRate(String code) {
    try {
      final data = _storage.read('user_currency_rate');
      if (data is! Map || data['code'] != code) return null;
      final rate = double.tryParse(data['rate'].toString());
      final fetchedAt = DateTime.tryParse(data['fetched_at']?.toString() ?? '');
      if (rate == null || rate <= 0 || fetchedAt == null) return null;
      return (rate: rate, fetchedAt: fetchedAt);
    } catch (_) {
      return null;
    }
  }

  // ==================== Country Management ====================

  /// Save user selected country
  static void saveCountry(String country) {
    _storage.write('user_country', country);
  }

  /// Get saved country
  static String? getCountry() {
    try {
      final country = _storage.read('user_country');
      if (country == null) {
        return null;
      }
      return country as String;
    } catch (e) {
      return null;
    }
  }

  /// Clear country data
  static void clearCountry() {
    _storage.remove('user_country');
  }

  /// Check if user has selected a country
  static bool get hasSelectedCountry => getCountry() != null;

  // ==================== Guest Mode Management ====================

  /// Enable guest mode (skip authentication)
  static void enableGuestMode() {
    _storage.write('guest_mode', true);
  }

  /// Disable guest mode
  static void disableGuestMode() {
    _storage.remove('guest_mode');
  }

  /// Check if user is in guest mode
  static bool get isGuestMode {
    final isGuest = _storage.read('guest_mode') ?? false;
    return isGuest;
  }

  // ==================== Push Notifications ====================

  /// Token FCM déjà confirmé par le backend, sous la forme `userId:token`.
  ///
  /// Permet à l'accueil de ne renvoyer le token que s'il n'a jamais été
  /// enregistré pour ce compte, ou s'il a changé depuis.
  static String? get fcmRegistration => _storage.read('fcm_registration');

  static String? get registeredFcmToken {
    final registration = fcmRegistration;
    final prefix = '${getUser()?.id}:';
    return registration != null && registration.startsWith(prefix)
        ? registration.substring(prefix.length)
        : null;
  }

  static void setFcmRegistration(String value) =>
      _storage.write('fcm_registration', value);

  /// Le backend supprime le token de cet appareil à la déconnexion : la marque
  /// doit tomber avec eux, sinon la reconnexion croirait le token connu.
  static void clearFcmRegistration() {
    _storage.remove('fcm_registration');
    _storage.remove('fcm_registration_at');
  }

  /// Token FCM et langue déjà abonnés au topic des annonces
  /// (`token|langue`, voir FirebaseMessagingService.topicMarker).
  ///
  /// Gardé à la déconnexion : l'abonnement suit l'appareil, pas le compte,
  /// et un invité doit continuer à recevoir les annonces.
  static String? get announcementsTopicToken =>
      _storage.read('fcm_topic_token');

  static void setAnnouncementsTopicToken(String token) =>
      _storage.write('fcm_topic_token', token);
  static String get _pushPreferencesKey =>
      'push_preferences_${getUser()?.id ?? 'guest'}';
  static Map<String, dynamic>? get pushPreferences {
    final value = _storage.read(_pushPreferencesKey);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static void savePushPreferences(Map<String, dynamic> value) =>
      _storage.write(_pushPreferencesKey, value);
  static DateTime? get fcmRegistrationAt =>
      DateTime.tryParse(_storage.read<String>('fcm_registration_at') ?? '');
  static void markFcmRegistrationTime() => _storage.write(
    'fcm_registration_at',
    DateTime.now().toUtc().toIso8601String(),
  );
}
