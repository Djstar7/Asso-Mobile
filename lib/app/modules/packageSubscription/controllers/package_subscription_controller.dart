import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../data/providers/package_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../payment/widgets/wallet_payment_confirm_dialog.dart';
import '../../../data/models/payment_method_option.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';
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

  /// Lance l'abonnement au package [package] : Wallet ASSO (solde, activation
  /// immédiate), Mobile Money (KPay) ou carte bancaire (Stripe).
  Future<void> subscribeToSelectedPackage(Map<String, dynamic> package) async {
    if (_isDisposed || isSubscribing.value) return;

    selectPackage(package);
    final price = (package['price'] ?? 0).toDouble();

    // 1) Choix du moyen de paiement (tous affichés, grisés si indisponibles).
    final display = CurrencyService.displayFromPivot(price);
    final method = await PaymentMethodSelector.show(
      amount: display.amount,
      currency: display.currency,
      amountLabel: 'Prix du forfait',
      allowedCodes: const {'kpay', 'stripe'},
      includeWallet: true,
    );
    if (method == null) return; // annulé

    // 2) Sous-parcours selon le rail choisi.
    switch (method.code) {
      case 'wallet':
        await _subscribeViaWallet(package, price, method);
        break;
      case 'kpay':
        await _subscribeViaKpay(package, price);
        break;
      case 'stripe':
        await _subscribeViaCard(package, price);
        break;
      default:
        Get.snackbar(
          'Indisponible',
          "Ce moyen de paiement n'est pas disponible pour les forfaits.",
          snackPosition: SnackPosition.BOTTOM,
        );
    }
  }

  /// Abonnement payé avec le solde du Wallet ASSO : débit et activation immédiats.
  Future<void> _subscribeViaWallet(
    Map<String, dynamic> package,
    double price,
    PaymentMethodOption method,
  ) async {
    final confirmed = await WalletPaymentConfirmDialog.show(
      itemLabel: 'Forfait ${package['name'] ?? ''}',
      amount: price,
      balance: method.balance ?? 0,
    );
    if (!confirmed || _isDisposed) return;

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'Activation de votre forfait...');

    try {
      final response = await PackageService.subscribePackageDirect(
        package['id'] as int,
        paymentMode: 'wallet',
      );
      if (_isDisposed) return;
      PaymentLoadingDialog.hide();

      if (!response.success) {
        _showSubscriptionError(response.message);
        return;
      }

      await loadCurrentPackage();
      if (_isDisposed) return;
      await PaymentSuccessDialog.show(
        packageName: package['name'] ?? 'Forfait',
        amount: price,
        paymentMethod: 'wallet',
      );
    } catch (e) {
      PaymentLoadingDialog.hide();
      _showSubscriptionError('Une erreur est survenue: $e');
    } finally {
      isSubscribing.value = false;
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

  /// Montant (prix en XAF) affiché dans la devise de l'utilisateur.
  String formatCurrency(double priceInXOF) => CurrencyService.formatFromPivot(priceInXOF);

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
