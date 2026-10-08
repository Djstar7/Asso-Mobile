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
import '../widgets/sales_code_field.dart';
import '../../../data/services/stripe_native_service.dart';
import '../../../core/utils/app_design.dart';
import '../../payment/widgets/mobile_money_waiting.dart';

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

  // P6 : code commercial facultatif, vérifié avant le paiement.
  final salesCode = SalesCodeInput();

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
          'package_subscription.error'.tr,
          response.message.isNotEmpty
              ? response.message
              : 'package_subscription.load_error'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('💥 Exception loading packages: $e');
      Get.snackbar(
        'package_subscription.error'.tr,
        'package_subscription.generic_error'.trParams({'error': '$e'}),
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

    // 0) Code commercial saisi : il doit être valide avant de payer.
    if (!await salesCode.ensureReady() || _isDisposed) return;

    // 1) Choix du moyen de paiement (tous affichés, grisés si indisponibles).
    final display = CurrencyService.displayFromPivot(price);
    final method = await PaymentMethodSelector.show(
      amount: display.amount,
      currency: display.currency,
      amountLabel: 'package_subscription.package_price'.tr,
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
          'package_subscription.unavailable'.tr,
          'package_subscription.method_unavailable'.tr,
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
      itemLabel: 'package_subscription.package_item'.trParams({'name': '${package['name'] ?? ''}'}),
      amount: price,
      balance: method.balance ?? 0,
      salesCode: salesCode.code,
    );
    if (!confirmed || _isDisposed) return;

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'package_subscription.activating'.tr);

    try {
      final response = await PackageService.subscribePackageDirect(
        package['id'] as int,
        paymentMode: 'wallet',
        salesCode: salesCode.code,
      );
      if (_isDisposed) return;
      PaymentLoadingDialog.hide();

      if (!response.success) {
        if (salesCode.handleServerRejection(response)) return;
        _showSubscriptionError(response.message);
        return;
      }

      await loadCurrentPackage();
      if (_isDisposed) return;
      await PaymentSuccessDialog.show(
        packageName: package['name'] ?? 'package_subscription.package'.tr,
        amount: price,
        paymentMethod: 'wallet',
      );
    } catch (e) {
      PaymentLoadingDialog.hide();
      _showSubscriptionError('package_subscription.generic_error'.trParams({'error': '$e'}));
    } finally {
      isSubscribing.value = false;
    }
  }

  /// Abonnement payé par Mobile Money (KPay direct, USSD).
  Future<void> _subscribeViaKpay(Map<String, dynamic> package, double price) async {
    // Sélecteur pays → opérateur → numéro (mêmes valeurs que les commandes).
    final selection = await KpayDirectPaymentSheet.show(
      amount: price,
      amountLabel: 'package_subscription.package_price_alt'.tr,
    );
    if (selection == null) return; // annulé

    isSubscribing.value = true;
    PaymentLoadingDialog.show(
      message: 'package_subscription.creating'.trParams({'name': '${package['name']}'}),
    );

    try {
      final response = await PackageService.subscribePackageDirect(
        package['id'] as int,
        paymentMode: 'kpay_direct',
        provider: selection['provider'],
        phoneNumber: selection['phone'],
        salesCode: salesCode.code,
      );

      if (_isDisposed) return;
      PaymentLoadingDialog.hide();

      final subscriptionId = _subscriptionIdFrom(response);
      if (!response.success || subscriptionId == null) {
        if (salesCode.handleServerRejection(response)) return;
        _showSubscriptionError(response.message);
        return;
      }

      // Rien n'est annoncé avant la réponse de l'opérateur.
      final outcome = await MobileMoneyWaiting.run(
        amount: price,
        provider: selection['provider']!,
        phone: selection['phone']!,
        check: () => PackageService.subscriptionPaymentState(subscriptionId),
      );
      if (_isDisposed) return;
      switch (outcome.status) {
        case 'paid':
          await _onSubscriptionPaid(package, price, 'kpay');
        case 'failed':
          break; // motif déjà expliqué
        default:
          Get.snackbar(
            'package_subscription.payment_pending'.tr,
            'package_subscription.validate_ussd'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppThemeSystem.warningColor,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          _pollSubscriptionPayment(subscriptionId, package, price, 'kpay');
      }
    } catch (e) {
      PaymentLoadingDialog.hide();
      _showSubscriptionError('package_subscription.generic_error'.trParams({'error': '$e'}));
    } finally {
      isSubscribing.value = false;
    }
  }

  /// Abonnement payé par CARTE (Payment Sheet Stripe native).
  Future<void> _subscribeViaCard(Map<String, dynamic> package, double price) async {
    if (!StripeNativeService.isSupported) {
      Get.snackbar(
        'package_subscription.unavailable'.tr,
        'wallet.recharge.card_mobile_only'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    isSubscribing.value = true;
    PaymentLoadingDialog.show(message: 'package_subscription.preparing_payment'.tr);

    try {
      final response = await PackageService.subscribePackageDirect(
        package['id'] as int,
        paymentMode: 'stripe_direct',
        salesCode: salesCode.code,
      );

      if (_isDisposed) return;
      PaymentLoadingDialog.hide();

      final subscriptionId = _subscriptionIdFrom(response);
      final clientSecret = response.data?['client_secret']?.toString();
      final publishableKey = response.data?['publishable_key']?.toString();

      if (!response.success || subscriptionId == null) {
        if (salesCode.handleServerRejection(response)) return;
        _showSubscriptionError(response.message);
        return;
      }
      if (clientSecret == null || clientSecret.isEmpty ||
          publishableKey == null || publishableKey.isEmpty) {
        _showSubscriptionError('package_subscription.card_data_unavailable'.tr);
        return;
      }

      final ok = await StripeNativeService().payWithCard(
        publishableKey: publishableKey,
        clientSecret: clientSecret,
      );
      if (_isDisposed) return;

      if (!ok) {
        Get.snackbar(
          'wallet.webview.cancelled'.tr,
          'package_subscription.payment_not_finalized'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.warningColor,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      Get.snackbar(
        'package_subscription.payment_in_progress'.tr,
        'package_subscription.payment_confirming'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.success,
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
          await _onSubscriptionPaid(package, price, methodCode);
          return;
        } else if (status == 'failed') {
          Get.snackbar(
            'package_subscription.payment_failed'.tr,
            'package_subscription.subscription_payment_failed'.tr,
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
      'package_subscription.payment_pending'.tr,
      'package_subscription.confirmation_not_arrived'.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.warningColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  /// Abonnement actif : on recharge le package courant puis on révèle le succès.
  Future<void> _onSubscriptionPaid(
    Map<String, dynamic> package,
    double price,
    String methodCode,
  ) async {
    await loadCurrentPackage();
    if (_isDisposed) return;
    await PaymentSuccessDialog.show(
      packageName: package['name'] ?? 'Package',
      amount: price,
      paymentMethod: methodCode,
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
      'package_subscription.error'.tr,
      message?.isNotEmpty == true ? message! : 'package_subscription.subscribe_error'.tr,
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
    salesCode.dispose();
    super.onClose();

    print('  └─ Controller disposed safely');
    print('========================================');
  }
}
