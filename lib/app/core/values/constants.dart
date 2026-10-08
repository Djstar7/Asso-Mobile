/// Application constants
class AppConstants {
  // App Info
  static const String appName = 'Asso';
  static const String appVersion = '1.0.0';

  // ==========================================================================
  // API Configuration
  // --------------------------------------------------------------------------
  // Par défaut l'application vise la PRODUCTION : un build distribué ne doit
  // jamais pointer vers une machine de développement, injoignable pour
  // l'utilisateur final.
  //
  // Pour travailler en local, surcharger au build sans toucher au code :
  //   flutter run --dart-define=API_BASE_URL=http://localhost:8001/api
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.156:8001/api
  //
  // Assurez-vous que le serveur local écoute sur toutes les interfaces :
  //   php artisan serve --host=0.0.0.0 --port=8001
  // ==========================================================================

  /// Surcharge optionnelle passée au build (prioritaire sur tout le reste).
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Domaine de production, partagé par l'API, le partage de liens et Reverb.
  static const String productionDomain = 'asso-dashboard.sbs';

  static String get baseUrl {
    // Surcharge explicite au build (développement local / préproduction)
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;

    // Défaut : production
    return 'https://$productionDomain/api';
  }

  static const Duration apiTimeout = Duration(seconds: 30);

  // ==========================================================================
  // Partage & liens universels
  // --------------------------------------------------------------------------
  // Un produit partagé prend la forme https://<shareDomain>/produit/{id}.
  // Sur un appareil où l'application est installée, le système la lui remet
  // directement (DeepLinkService) ; ailleurs, le serveur redirige vers la
  // fiche du magasin d'applications.
  //
  // Le domaine est surchargeable au build, comme l'URL d'API :
  //   flutter build apk --dart-define=SHARE_DOMAIN=asso.cm
  // ==========================================================================

  static const String _envShareDomain = String.fromEnvironment('SHARE_DOMAIN');

  static String get shareDomain =>
      _envShareDomain.isNotEmpty ? _envShareDomain : productionDomain;

  /// Lien public d'un produit, celui que l'on partage.
  static String productUrl(Object id) => 'https://$shareDomain/produit/$id';

  // Storage Keys
  static const String keyUser = 'user';
  static const String keyToken = 'token';
  static const String keyThemeMode = 'theme_mode';
  static const String keyPreferences = 'preferences';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyPreferencesPrompted = 'preferences_prompted';

  // Pagination
  static const int defaultPageSize = 20;

  // UI/UX Timing
  static const Duration shimmerMinimumDuration = Duration(milliseconds: 800);
  static const Duration shimmerFadeTransitionDuration = Duration(
    milliseconds: 400,
  );

  // Image Paths
  static const String logoPath = 'assets/images/logo.png';

  // API Endpoints
  // Phone-based authentication
  static const String sendOtpUrl = '/v1/auth/send-otp';
  static const String verifyOtpUrl = '/v1/auth/verify-otp';
  static const String loginUrl = '/v1/auth/login';

  // Email-based authentication
  static const String registerEmailUrl = '/v1/auth/register-email';
  static const String loginEmailUrl = '/v1/auth/login-email';
  static const String verifyEmailOtpUrl = '/v1/auth/verify-email-otp';
  static const String forgotPasswordUrl = '/v1/auth/password/forgot';
  static const String resetPasswordUrl = '/v1/auth/password/reset';

  // Profile & Auth management
  static const String profileUrl = '/v1/auth/profile';
  static const String getPreferencesUrl = '/v1/auth/preferences';
  static const String updatePreferencesUrl = '/v1/auth/preferences';
  static const String requestPhoneChangeUrl = '/v1/auth/request-phone-change';
  static const String confirmPhoneChangeUrl = '/v1/auth/confirm-phone-change';
  static const String deleteAccountUrl = '/v1/auth/delete-account';
  static const String logoutUrl = '/v1/auth/logout';
  static const String invoicesUrl = '/v1/invoices';
  static const String aboutUrl = '/v1/app/about';
  static const String versionUrl = '/v1/app/version';
  static const String productsUrl = '/v1/products';
  static const String importCountriesUrl = '/v1/import-countries';
  static const String categoriesUrl = '/v1/categories';
  static const String bannersUrl = '/v1/banners';
  static const String favoritesUrl = '/v1/favorites';
  static const String ordersUrl = '/v1/orders';
  static const String paymentInitiateUrl = '/v1/payments/initiate';
  static const String paymentStatusUrl = '/v1/payments/status';
  static const String vendorApplyUrl = '/v1/vendor/apply';
  static const String vendorDashboardUrl = '/v1/vendor/dashboard';
  static const String deliveryApplyUrl = '/v1/delivery/apply';
  static const String deliveryDashboardUrl = '/v1/delivery/dashboard';
  static const String settingsUrl = '/settings';

  // Vendor order management
  static const String vendorOrdersUrl = '/v1/vendor/orders';
  static const String deliveryPersonsUrl = '/v1/vendor/orders/delivery-persons';

  // Stripe Connect (compte de virement IBAN vendeur)
  static const String stripeConnectSubmitUrl = '/v1/stripe/connect/submit';
  static const String stripeConnectStatusUrl = '/v1/stripe/connect/status';

  // Delivery management
  static const String deliveryPendingUrl = '/v1/delivery/pending';
  static const String deliveryActiveUrl = '/v1/delivery/active';

  // Deliverer sync
  static const String delivererVerifySyncCodeUrl =
      '/v1/deliverer/verify-sync-code';
  static const String delivererSyncProfileUrl = '/v1/deliverer/sync-profile';
  static const String delivererUnsyncProfileUrl =
      '/v1/deliverer/unsync-profile';

  // Delivery partners (for vendor map)
  static const String deliveryPartnersUrl = '/v1/delivery/partners';

  // Wallet
  static const String walletUrl = '/v1/wallet';
  static const String walletTransactionsUrl = '/v1/wallet/transactions';
  static const String walletRechargeUrl = '/v1/wallet/recharge';
  static const String walletCanPayUrl = '/v1/wallet/can-pay';
  static const String walletPayUrl = '/v1/wallet/pay';
  static const String walletWithdrawalBalancesUrl =
      '/v1/wallet/withdrawal-balances';
  static const String walletWithdrawKpayUrl = '/v1/wallet/withdraw/kpay';
  static const String walletWithdrawPaypalUrl = '/v1/wallet/withdraw/paypal';
  static const String walletWithdrawStripeUrl = '/v1/wallet/withdraw/stripe';
  // Devis d'un virement IBAN : montant converti vers la devise du compte bancaire.
  static const String walletStripeQuoteUrl = '/v1/wallet/withdraw/stripe/quote';
  static const String walletWithdrawalsUrl = '/v1/wallet/withdrawals';
  static const String walletWithdrawalStatusUrl =
      '/v1/wallet/withdrawal-status';
  static const String walletPaymentStatusUrl = '/v1/wallet/payment-status';
  // Coordonnées de retrait Mobile Money enregistrées (GET / PUT / DELETE)
  static const String walletPayoutAccountUrl = '/v1/wallet/payout-account';
  static const String walletPayPalCreateNativeOrderUrl =
      '/v1/wallet/paypal/create-native-order';
  static const String walletPayPalCaptureNativeOrderUrl =
      '/v1/wallet/paypal/capture-native-order';

  // Product creation
  static const String createProductUrl = '/v1/products';

  // Order confirmation
  static const String confirmDeliveryUrl =
      '/v1/orders'; // + /{id}/confirm-delivery

  // Conversations
  static const String conversationsUrl = '/v1/conversations';
  static const String startConversationUrl = '/v1/conversations/start';

  // Package subscription
  static const String packagesUrl = '/v1/packages';
  static const String subscribePackageUrl = '/v1/packages/subscribe';
  static const String currentPackageUrl = '/v1/vendor/package/current';
  // P6 : vérification d'un code commercial avant souscription
  //   GET $salesCodeUrl/{code} → { data:{ code, agent_display_name } } | 404
  static const String salesCodeUrl = '/v1/sales-codes';
  // Statut de paiement d'un abonnement vendeur (polling) :
  //   GET $packageSubscriptionUrl/{subscription_id}/payment-status
  static const String packageSubscriptionUrl = '/v1/packages/subscription';

  // Compte support ASSO (messagerie d'assistance)
  static const String appSupportUrl = '/v1/app/support';

  // Vendor products management
  static const String vendorProductsUrl = '/v1/vendor/products';

  // Vendor shop management
  static const String vendorShopUrl = '/v1/vendor/shop';
  static const String vendorShopsUrl = '/v1/vendor/shops';
  static const String publicShopUrl = '/v1/shops'; // + /{id}

  // Device Tokens & Notifications (FCM)
  static const String deviceTokensUrl = '/v1/device-tokens';
  static const String notificationsTestUrl = '/v1/notifications/test';
}
