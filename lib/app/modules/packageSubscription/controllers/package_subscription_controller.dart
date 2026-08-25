import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/providers/package_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
import '../../wallet/views/payment_webview.dart';
import '../widgets/payment_loading_dialog.dart';
import '../widgets/payment_success_dialog.dart';
import '../../../data/services/stripe_native_service.dart';

class PackageSubscriptionController extends GetxController {
  // State management
  bool _isDisposed = false;
  bool get isSafe => !_isDisposed && isClosed == false;

  // Observable variables
  final packages = <Map<String, dynamic>>[].obs;
  final selectedPackage = Rx<Map<String, dynamic>?>(null);
  final isLoading = false.obs;
  final currentVendorPackage = Rx<Map<String, dynamic>?>(null);
  final hasPackage = false.obs;

  // Empêche le lancement de plusieurs abonnements simultanés.
  final isSubscribing = false.obs;

  @override
  void onInit() {
    super.onInit();
    print('');
    print('========================================');
    print('🎯 PACKAGE SUBSCRIPTION CONTROLLER: Init');
    print('========================================');
    loadPackages();
    loadCurrentPackage();
  }

  /// Load all available packages
  Future<void> loadPackages() async {
    if (_isDisposed) return;

    print('');
    print('📦 Loading packages...');
    isLoading.value = true;

    try {
      final response = await PackageService.getPackages();

      if (_isDisposed) return;

      if (response.success && response.data != null) {
        final packagesData = response.data!['packages'] as List?;

        if (packagesData != null) {
          packages.value = packagesData
              .map((e) => e as Map<String, dynamic>)
              .toList();
          print('✅ Loaded ${packages.length} packages');
        }
      } else {
        print('❌ Failed to load packages: ${response.message}');
        Get.snackbar(
          'Erreur',
          response.message ?? 'Impossible de charger les packages',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('💥 Exception loading packages: $e');
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Load current vendor package
  Future<void> loadCurrentPackage() async {
    if (_isDisposed) return;

    print('');
    print('📊 Loading current package...');

    try {
      final response = await PackageService.getCurrentPackage();

      if (_isDisposed) return;

      if (response.success && response.data != null) {
        hasPackage.value = response.data!['has_package'] ?? false;

        if (hasPackage.value) {
          currentVendorPackage.value = response.data!['vendor_package'];
          print('✅ Current package loaded');
          print('  └─ Storage used: ${currentVendorPackage.value!['storage_used_mb']} MB');
          print('  └─ Storage total: ${currentVendorPackage.value!['storage_total_mb']} MB');
        } else {
          print('ℹ️ No active package');
        }
      }
    } catch (e) {
      print('💥 Exception loading current package: $e');
      // Don't show error to user, just log it
    }
  }

  /// Select a package
  void selectPackage(Map<String, dynamic> package) {
    print('');
    print('✅ Package selected: ${package['name']}');
    selectedPackage.value = package;
  }

  /// Lance l'abonnement au package [package] via le sélecteur de paiement
  /// acheteur (KPay Mobile Money / PayPal / Stripe), EXACTEMENT comme une
  /// commande. Aucun solde wallet : ce sont des rails de paiement directs.
  Future<void> subscribeToSelectedPackage(Map<String, dynamic> package) async {
    if (_isDisposed || isSubscribing.value) return;

    selectPackage(package);
    final price = (package['price'] ?? 0).toDouble();

    // 1) Choix du moyen de paiement (tous affichés, grisés si trop faible,
    //    jamais masqués selon le pays, sans solde wallet).
    final method = await PaymentMethodSelector.show(
      amount: price,
      currency: 'XAF',
      amountLabel: 'Prix du package',
    );
    if (method == null) return; // annulé

    // 2) Sous-parcours selon le rail choisi.
    switch (method.code) {
      case 'kpay':
        await _subscribeViaKpay(package, price);
        break;
      case 'paypal':
        await _subscribeViaRedirect(package, price, 'paypal_direct', 'paypal');
        break;
      case 'stripe':
        await _subscribeViaCard(package, price);
        break;
      default:
        Get.snackbar(
          'Indisponible',
          "Ce moyen de paiement n'est pas disponible pour les abonnements.",
          snackPosition: SnackPosition.BOTTOM,
        );
    }
  }

  /// Abonnement payé par Mobile Money (KPay direct, USSD).
  Future<void> _subscribeViaKpay(Map<String, dynamic> package, double price) async {
    // Sélecteur pays → opérateur → numéro (mêmes valeurs que les commandes).
    final selection = await KpayDirectPaymentSheet.show(
      amount: price,
      amountLabel: 'Prix du package',
    );
    if (selection == null) return; // annulé

    isSubscribing.value = true;
    PaymentLoadingDialog.show(
      message: 'Création de votre abonnement ${package['name']}...',
    );

    try {
      final response = await PackageService.subscribePackageDirect(
        package['id'] as int,
        paymentMode: 'kpay_direct',
        provider: selection['provider'],
        phoneNumber: selection['phone'],
      );

      if (_isDisposed) return;
      PaymentLoadingDialog.hide();

      final subscriptionId = _subscriptionIdFrom(response);
      if (!response.success || subscriptionId == null) {
        _showSubscriptionError(response.message);
        return;
      }

      Get.snackbar(
        'Paiement en attente',
        'Validez le paiement sur votre téléphone (USSD). L\'abonnement sera activé ensuite.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.warningColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      _pollSubscriptionPayment(subscriptionId, package, price, 'kpay');
    } catch (e) {
      PaymentLoadingDialog.hide();
      _showSubscriptionError('Une erreur est survenue: $e');
    } finally {
      isSubscribing.value = false;
    }
  }

  /// Abonnement payé par CARTE (Payment Sheet Stripe native).
  Future<void> _subscribeViaCard(Map<String, dynamic> package, double price) async {
    if (!StripeNativeService.isSupported) {
      Get.snackbar(
        'Indisponible',
        "Le paiement par carte est disponible sur l'application mobile.",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'Préparation du paiement...');

    try {
      final response = await PackageService.subscribePackageDirect(
        package['id'] as int,
        paymentMode: 'stripe_direct',
      );

      if (_isDisposed) return;
      PaymentLoadingDialog.hide();

      final subscriptionId = _subscriptionIdFrom(response);
      final clientSecret = response.data?['client_secret']?.toString();
      final publishableKey = response.data?['publishable_key']?.toString();

      if (!response.success || subscriptionId == null) {
        _showSubscriptionError(response.message);
        return;
      }
      if (clientSecret == null || clientSecret.isEmpty ||
          publishableKey == null || publishableKey.isEmpty) {
        _showSubscriptionError('Données de paiement carte indisponibles. Réessayez.');
        return;
      }

      final ok = await StripeNativeService().payWithCard(
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );
      if (_isDisposed) return;

      if (!ok) {
        Get.snackbar(
          'Paiement annulé',
          "Le paiement n'a pas été finalisé.",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.warningColor,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      Get.snackbar(
        'Paiement en cours',
        'Votre paiement est en cours de confirmation. Vous serez notifié.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

      _pollSubscriptionPayment(subscriptionId, package, price, 'stripe');
    } catch (e) {
      PaymentLoadingDialog.hide();
      _showSubscriptionError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      isSubscribing.value = false;
    }
  }

  /// Abonnement payé par redirection (PayPal / carte Stripe) via WebView.
  Future<void> _subscribeViaRedirect(
    Map<String, dynamic> package,
    double price,
    String paymentMode,
    String methodCode,
  ) async {
    isSubscribing.value = true;
    PaymentLoadingDialog.show(
      message: 'Préparation du paiement...',
    );

    try {
      final response = await PackageService.subscribePackageDirect(
        package['id'] as int,
        paymentMode: paymentMode,
      );

      if (_isDisposed) return;
      PaymentLoadingDialog.hide();

      final subscriptionId = _subscriptionIdFrom(response);
      final approvalUrl = response.data?['approval_url']?.toString();

      if (!response.success || subscriptionId == null) {
        _showSubscriptionError(response.message);
        return;
      }
      if (approvalUrl == null || approvalUrl.isEmpty) {
        _showSubscriptionError('Lien de paiement indisponible. Réessayez.');
        return;
      }

      // La WebView intégrée n'est disponible que sur mobile (Android/iOS). Sur les
      // autres plateformes on ouvre le checkout dans le navigateur système : la
      // confirmation se fait de toute façon côté serveur (polling).
      if (GetPlatform.isAndroid || GetPlatform.isIOS) {
        await Get.to<Map<String, dynamic>>(
          () => PaymentWebView(
            paymentUrl: approvalUrl,
            paymentMethod: methodCode,
            paymentId: subscriptionId,
          ),
        );
      } else {
        await launchUrl(Uri.parse(approvalUrl), mode: LaunchMode.externalApplication);
      }

      // Au retour du WebView, on suit la confirmation serveur.
      Get.snackbar(
        'Paiement en cours',
        'Votre paiement est en cours de confirmation. Vous serez notifié.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );

      _pollSubscriptionPayment(subscriptionId, package, price, methodCode);
    } catch (e) {
      PaymentLoadingDialog.hide();
      _showSubscriptionError('Une erreur est survenue: $e');
    } finally {
      isSubscribing.value = false;
    }
  }

  /// Suit le paiement d'un abonnement (polling 5 s). Le succès (dialog) n'est
  /// affiché QU'AU statut « paid » (vendor_package renseigné) — jamais à la
  /// simple création. « failed » stoppe le suivi avec un message d'erreur.
  void _pollSubscriptionPayment(
    int subscriptionId,
    Map<String, dynamic> package,
    double price,
    String methodCode,
  ) async {
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (_isDisposed) return;

      try {
        final res = await PackageService.getSubscriptionPaymentStatus(subscriptionId);
        final status = res.data?['data']?['status'];

        if (status == 'paid') {
          // Abonnement actif : on recharge le package courant puis on révèle le succès.
          await loadCurrentPackage();
          if (_isDisposed) return;
          await PaymentSuccessDialog.show(
            packageName: package['name'] ?? 'Package',
            amount: price,
            paymentMethod: methodCode,
          );
          return;
        } else if (status == 'failed') {
          Get.snackbar(
            'Paiement échoué',
            'Le paiement de l\'abonnement n\'a pas abouti.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppThemeSystem.errorColor,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          return;
        }
      } catch (_) {}
    }

    // Délai dépassé sans confirmation : rester prudent.
    if (_isDisposed) return;
    Get.snackbar(
      'Paiement en attente',
      "La confirmation n'est pas encore arrivée. Vérifiez votre dashboard.",
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.warningColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  /// Extrait le subscription_id de la réponse d'abonnement (int robuste).
  int? _subscriptionIdFrom(dynamic response) {
    final raw = response.data?['subscription_id'];
    if (raw is int) return raw;
    return int.tryParse('$raw');
  }

  void _showSubscriptionError(String? message) {
    Get.snackbar(
      'Erreur',
      message?.isNotEmpty == true ? message! : 'Impossible de souscrire au package',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.errorColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  /// Refresh packages
  Future<void> refreshPackages() async {
    await Future.wait([
      loadPackages(),
      loadCurrentPackage(),
    ]);
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format currency (using CurrencyService)
  String formatCurrency(double priceInXOF) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: true);
  }

  /// Get currency symbol
  String get currencySymbol {
    if (!Get.isRegistered<CurrencyService>()) {
      return 'FCFA';
    }
    return CurrencyService.to.currencySymbol;
  }

  @override
  void onClose() {
    print('');
    print('========================================');
    print('🎯 PACKAGE SUBSCRIPTION CONTROLLER: Closing');
    print('========================================');

    _isDisposed = true;
    super.onClose();

    print('  └─ Controller disposed safely');
    print('========================================');
  }
}
