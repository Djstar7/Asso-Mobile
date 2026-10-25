import 'dart:async';
import 'package:get/get.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/services/deep_link_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/services/firebase_messaging_service.dart';
import '../../../routes/app_pages.dart';

class SplashController extends GetxController {
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    // Le routeur est monté à ce stade : les liens partagés peuvent viser une
    // route sans risquer d'arriver avant la première image.
    if (Get.isRegistered<DeepLinkService>()) {
      Get.find<DeepLinkService>().start();
    }
    _initializeCurrencyAndNavigate();
  }

  /// Initialise la devise et les conversions avant de naviguer
  Future<void> _initializeCurrencyAndNavigate() async {

    try {
      // Vérifier si l'utilisateur a déjà sélectionné un pays
      final hasSelectedCountry = StorageService.hasSelectedCountry;

      if (!hasSelectedCountry) {
      } else {
        final savedCountry = StorageService.getCountry();

        // Vérifier si CurrencyService est déjà initialisé
        if (Get.isRegistered<CurrencyService>()) {

          final currency = CurrencyService.to.userCurrency;
          if (currency != null) {
          }
        } else {
        }
      }
    } catch (e, stackTrace) {
    }


    // Continuer avec la navigation normale
    _startNavigation();
  }

  void _startNavigation() {
    _timer = Timer(const Duration(seconds: 3), () {
      _checkAuthState();
    });
  }

  Future<void> _checkAuthState() async {

    // Check if storage is initialized
    final storageInitialized = StorageService.isInitialized;

    if (!storageInitialized) {
      Get.offAllNamed(Routes.ONBOARDING);
      return;
    }

    // Check if user has selected a country
    final hasSelectedCountry = StorageService.hasSelectedCountry;
    if (!hasSelectedCountry) {
      Get.offAllNamed(Routes.COUNTRY_SELECTION);
      return;
    }

    try {
      // Check if user is in guest mode
      final isGuestMode = StorageService.isGuestMode;

      if (isGuestMode) {

        // S'abonner au topic des annonces en mode invité
        try {
          FirebaseMessagingService.to.subscribeToAnnouncementsTopic().then((_) {
          }).catchError((e) {
          });
        } catch (e) {
        }

        Get.offAllNamed(Routes.HOME);
        return;
      }

      // Check for token
      final token = StorageService.getToken();

      // Check for user
      final user = StorageService.getUser();

      // Check authentication status
      final isAuthenticated = StorageService.isAuthenticated;

      if (isAuthenticated) {

        // Envoyer/mettre à jour le token FCM et s'abonner au topic des annonces
        try {
          FirebaseMessagingService.to.registerDeviceAndSubscribe().then((results) {
          }).catchError((e) {
          });
        } catch (e) {
        }

        if (user != null) {

          // Check if user has preferences set
          final hasPreferences = user.preferences != null &&
                                 user.preferences!.isNotEmpty;


          // Check user role for logging
          final isVendor = user.isVendor;

          // All authenticated users with preferences or complete profile go to HOME
          // (including vendors - they can access vendor dashboard from the drawer)
          if (hasPreferences || user.isProfileComplete) {
            Get.offAllNamed(Routes.HOME);
          } else {
            Get.offAllNamed(Routes.PREFERENCES, arguments: {'onboarding': true});
          }
        } else {
          await StorageService.clearAuthSession();
          Get.offAllNamed(Routes.ONBOARDING);
        }
      } else {

        // Check if onboarding was already shown
        final onboardingDone = StorageService.isOnboardingDone;

        if (onboardingDone) {
          Get.offAllNamed(Routes.WELCOMER);
        } else {
          Get.offAllNamed(Routes.ONBOARDING);
        }
      }
    } catch (e, stackTrace) {
      Get.offAllNamed(Routes.ONBOARDING);
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
