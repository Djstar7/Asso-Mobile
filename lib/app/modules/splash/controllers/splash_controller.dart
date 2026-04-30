import 'dart:async';
import 'dart:developer' as developer;
import 'package:get/get.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/services/firebase_messaging_service.dart';
import '../../../routes/app_pages.dart';

class SplashController extends GetxController {
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    print('');
    print('========================================');
    print('🎬 SPLASH CONTROLLER: onInit CALLED');
    print('========================================');
    developer.log('========== SPLASH STARTED ==========', name: 'SplashController');
    _initializeCurrencyAndNavigate();
  }

  /// Initialise la devise et les conversions avant de naviguer
  Future<void> _initializeCurrencyAndNavigate() async {
    print('');
    print('========================================');
    print('💱 INITIALIZING CURRENCY SYSTEM');
    print('========================================');
    developer.log('========== INITIALIZING CURRENCY ==========', name: 'SplashController');

    try {
      // Vérifier si l'utilisateur a déjà sélectionné un pays
      final hasSelectedCountry = StorageService.hasSelectedCountry;
      print('🌍 User has selected country: $hasSelectedCountry');

      if (!hasSelectedCountry) {
        print('⚠️ No country selected - will navigate to country selection');
        developer.log('No country selected yet', name: 'SplashController');
      } else {
        final savedCountry = StorageService.getCountry();
        print('✅ Saved country: $savedCountry');

        // Vérifier si CurrencyService est déjà initialisé
        if (Get.isRegistered<CurrencyService>()) {
          print('💱 CurrencyService already registered, loading saved currency...');
          developer.log('CurrencyService already registered', name: 'SplashController');

          final currency = CurrencyService.to.userCurrency;
          if (currency != null) {
            print('✅ Currency loaded: ${currency.code} (${currency.symbol})');
            print('🌍 Country: ${CurrencyService.to.detectedCountry}');
            print('💵 Exchange rate to XOF: ${CurrencyService.to.exchangeRateToXOF}');
            developer.log(
              'Currency loaded: ${currency.code} - ${currency.name}',
              name: 'SplashController',
              error: 'Rate to XOF: ${CurrencyService.to.exchangeRateToXOF}',
            );
          }
        } else {
          print('⚠️ CurrencyService not registered yet');
          developer.log('CurrencyService not registered', name: 'SplashController');
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error initializing currency: $e');
      developer.log(
        'Error initializing currency',
        name: 'SplashController',
        error: e,
        stackTrace: stackTrace,
      );
    }

    print('========================================');
    print('');

    // Continuer avec la navigation normale
    _startNavigation();
  }

  void _startNavigation() {
    print('⏰ Starting 3-second timer...');
    developer.log('Starting navigation timer', name: 'SplashController');
    _timer = Timer(const Duration(seconds: 3), () {
      print('⏰ Timer finished! Checking auth state...');
      _checkAuthState();
    });
  }

  void _checkAuthState() {
    print('');
    print('========================================');
    print('🚀 SPLASH: CHECKING AUTH STATE');
    print('========================================');
    developer.log('========== CHECKING AUTH STATE ==========', name: 'SplashController');

    // Check if storage is initialized
    final storageInitialized = StorageService.isInitialized;
    print('💾 Storage initialized: $storageInitialized');

    if (!storageInitialized) {
      print('❌ CRITICAL: Storage not initialized!');
      Get.offAllNamed(Routes.ONBOARDING);
      return;
    }

    // Check if user has selected a country
    final hasSelectedCountry = StorageService.hasSelectedCountry;
    if (!hasSelectedCountry) {
      print('🌍 No country selected - navigating to country selection');
      developer.log('Navigating to COUNTRY_SELECTION', name: 'SplashController');
      Get.offAllNamed(Routes.COUNTRY_SELECTION);
      return;
    }

    try {
      // Check if user is in guest mode
      final isGuestMode = StorageService.isGuestMode;
      print('👻 Guest mode: $isGuestMode');
      developer.log('Guest mode: $isGuestMode', name: 'SplashController');

      if (isGuestMode) {
        print('✅ USER IS IN GUEST MODE - Going to HOME');
        developer.log('✓ USER IS IN GUEST MODE - Going to HOME', name: 'SplashController');

        // S'abonner au topic des annonces en mode invité
        developer.log('📱 Subscribing to announcements topic for guest...', name: 'SplashController');
        try {
          FirebaseMessagingService.to.subscribeToAnnouncementsTopic().then((_) {
            developer.log('✅ Subscribed to announcements topic', name: 'SplashController');
          }).catchError((e) {
            developer.log('Error subscribing to announcements topic', name: 'SplashController', error: e);
          });
        } catch (e) {
          developer.log('Error in guest subscription', name: 'SplashController', error: e);
        }

        print('➡️ Navigating to HOME (guest mode)');
        Get.offAllNamed(Routes.HOME);
        print('========================================');
        print('');
        return;
      }

      // Check for token
      final token = StorageService.getToken();
      print('🔑 Token from storage: ${token != null ? "EXISTS (${token.substring(0, 20)}...)" : "NULL"}');
      developer.log('Token from storage: ${token != null ? "EXISTS (${token.substring(0, 20)}...)" : "NULL"}', name: 'SplashController');

      // Check for user
      final user = StorageService.getUser();
      print('👤 User from storage: ${user != null ? "EXISTS (ID: ${user.id}, Phone: ${user.phone})" : "NULL"}');
      developer.log('User from storage: ${user != null ? "EXISTS (ID: ${user.id}, Phone: ${user.phone})" : "NULL"}', name: 'SplashController');

      // Check authentication status
      final isAuthenticated = StorageService.isAuthenticated;
      print('✓ Is authenticated: $isAuthenticated');
      developer.log('Is authenticated: $isAuthenticated', name: 'SplashController');

      if (isAuthenticated) {
        print('✅ USER IS AUTHENTICATED');
        developer.log('✓ USER IS AUTHENTICATED', name: 'SplashController');

        // Envoyer/mettre à jour le token FCM et s'abonner au topic des annonces
        developer.log('📱 Registering device and subscribing to topics for authenticated user...', name: 'SplashController');
        try {
          FirebaseMessagingService.to.registerDeviceAndSubscribe().then((results) {
            developer.log(
              'FCM registration result',
              name: 'SplashController',
              error: 'Token sent: ${results['token_sent']}, Topic subscribed: ${results['topic_subscribed']}',
            );
          }).catchError((e) {
            developer.log(
              'Error registering device/subscribing to topics',
              name: 'SplashController',
              error: e,
            );
          });
        } catch (e) {
          developer.log(
            'Error registering device in splash',
            name: 'SplashController',
            error: e,
          );
        }

        if (user != null) {
          print('📋 User details: ID=${user.id}, Phone=${user.phone}, ProfileComplete=${user.isProfileComplete}');
          print('🎯 User preferences: ${user.preferences}');
          developer.log(
            'User details: ID=${user.id}, Phone=${user.phone}, ProfileComplete=${user.isProfileComplete}',
            name: 'SplashController',
          );

          // Check if user has preferences set
          final hasPreferences = user.preferences != null &&
                                 user.preferences!.isNotEmpty;

          print('✓ Has preferences: $hasPreferences');

          // Check user role for logging
          final isVendor = user.isVendor;
          print('🏪 Is vendor: $isVendor');

          // All authenticated users with preferences or complete profile go to HOME
          // (including vendors - they can access vendor dashboard from the drawer)
          if (hasPreferences || user.isProfileComplete) {
            print('➡️ Navigating to HOME (preferences set or profile complete)');
            developer.log('→ Navigating to HOME', name: 'SplashController');
            Get.offAllNamed(Routes.HOME);
          } else {
            print('➡️ Navigating to PREFERENCES (no preferences set)');
            developer.log('→ Navigating to PREFERENCES (no preferences)', name: 'SplashController');
            Get.offAllNamed(Routes.PREFERENCES);
          }
        } else {
          print('❌ ERROR: Authenticated but user is NULL - clearing auth');
          developer.log('✗ ERROR: Authenticated but user is NULL - clearing auth', name: 'SplashController');
          StorageService.clearAuthSession();
          Get.offAllNamed(Routes.ONBOARDING);
        }
      } else {
        print('❌ USER NOT AUTHENTICATED');
        developer.log('✗ USER NOT AUTHENTICATED', name: 'SplashController');

        // Check if onboarding was already shown
        final onboardingDone = StorageService.isOnboardingDone;
        print('📖 Onboarding done: $onboardingDone');
        developer.log('Onboarding done: $onboardingDone', name: 'SplashController');

        if (onboardingDone) {
          print('➡️ Navigating to WELCOMER (onboarding already done)');
          developer.log('→ Navigating to WELCOMER (onboarding already done)', name: 'SplashController');
          Get.offAllNamed(Routes.WELCOMER);
        } else {
          print('➡️ Navigating to ONBOARDING (first time)');
          developer.log('→ Navigating to ONBOARDING (first time)', name: 'SplashController');
          Get.offAllNamed(Routes.ONBOARDING);
        }
      }
      print('========================================');
      print('');
    } catch (e, stackTrace) {
      print('❌ ERROR checking auth state: $e');
      print('Stack trace: $stackTrace');
      developer.log(
        '✗ ERROR checking auth state - navigating to onboarding',
        name: 'SplashController',
        error: e,
        stackTrace: stackTrace,
      );
      Get.offAllNamed(Routes.ONBOARDING);
      print('========================================');
      print('');
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
