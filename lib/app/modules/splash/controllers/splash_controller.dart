import '../../../data/services/country_sync.dart';
import 'dart:async';
import 'package:get/get.dart';
import '../../../data/providers/guest_access.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/services/deep_link_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/services/firebase_messaging_service.dart';
import '../../../routes/app_pages.dart';

class SplashController extends GetxController {
  Timer? _timer;
  late final Future<void> _linkReady;

  bool get _hasPendingLink =>
      Get.isRegistered<DeepLinkService>() &&
      Get.find<DeepLinkService>().hasPendingLink;

  @override
  void onInit() {
    super.onInit();
    // Le routeur est monté à ce stade : les liens partagés peuvent viser une
    // route sans risquer d'arriver avant la première image.
    _linkReady = Get.isRegistered<DeepLinkService>()
        ? Get.find<DeepLinkService>().start()
        : Future<void>.value();
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
          if (currency != null) {}
        } else {}
      }
    } catch (e, stackTrace) {}

    // Continuer avec la navigation normale
    _startNavigation();
  }

  /// Qui arrive par un lien attend ce lien : le splash est écourté.
  Future<void> _startNavigation() async {
    await _linkReady
        .timeout(const Duration(seconds: 2))
        .catchError((Object _) {});
    if (isClosed) return;
    _timer = Timer(
      _hasPendingLink
          ? const Duration(milliseconds: 300)
          : const Duration(seconds: 3),
      _checkAuthState,
    );
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
          FirebaseMessagingService.to
              .subscribeToAnnouncementsTopic()
              .then((_) {})
              .catchError((e) {});
        } catch (e) {}

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
        // Pays choisi à l'accueil → compte (ne remplace qu'un pays déduit).
        CountrySync.push();

        // Envoyer/mettre à jour le token FCM et s'abonner au topic des annonces
        try {
          FirebaseMessagingService.to
              .registerDeviceAndSubscribe()
              .then((results) {})
              .catchError((e) {});
        } catch (e) {}

        if (user != null) {
          // Check if user has preferences set
          final hasPreferences =
              user.preferences != null && user.preferences!.isNotEmpty;

          // Check user role for logging
          final isVendor = user.isVendor;

          // All authenticated users with preferences or complete profile go to HOME
          // (including vendors - they can access vendor dashboard from the drawer)
          if (hasPreferences || user.isProfileComplete) {
            Get.offAllNamed(Routes.HOME);
          } else {
            Get.offAllNamed(
              Routes.PREFERENCES,
              arguments: {'onboarding': true},
            );
          }
        } else {
          await StorageService.clearAuthSession();
          Get.offAllNamed(Routes.ONBOARDING);
        }
      } else if (_hasPendingLink) {
        await GuestAccess.enter(skipInterests: true);
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
