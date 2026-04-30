import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../data/providers/package_service.dart';
import '../../../data/providers/wallet_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/models/wallet_model.dart';
import '../../../core/utils/app_theme_system.dart';
import '../widgets/payment_loading_dialog.dart';
import '../widgets/payment_success_dialog.dart';

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

  // Wallet data
  final wallet = Rx<WalletModel?>(null);
  final isLoadingWallet = false.obs;

  @override
  void onInit() {
    super.onInit();
    print('');
    print('========================================');
    print('🎯 PACKAGE SUBSCRIPTION CONTROLLER: Init');
    print('========================================');
    loadPackages();
    loadCurrentPackage();
    loadWallet();
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

  /// Load wallet balance
  Future<void> loadWallet() async {
    if (_isDisposed) return;

    print('');
    print('💰 Loading wallet balance...');
    isLoadingWallet.value = true;

    try {
      final response = await WalletService.getWallet();

      if (_isDisposed) return;

      if (response.success && response.data != null) {
        // Backend returns: {success: true, data: {freemopay_balance: ..., paypal_balance: ...}}
        // So we need to access response.data['data'] to get the wallet stats
        final walletData = response.data!['data'] ?? response.data!;
        wallet.value = WalletModel.fromJson(walletData);
        print('✅ Wallet loaded');
        print('  └─ FreeMoPay: ${wallet.value!.freemopayBalance} FCFA');
        print('  └─ PayPal: ${wallet.value!.paypalBalance} FCFA');
        print('  └─ Total: ${wallet.value!.currentBalance} FCFA');
      } else {
        print('❌ Failed to load wallet: ${response.message}');
      }
    } catch (e) {
      print('💥 Exception loading wallet: $e');
    } finally {
      isLoadingWallet.value = false;
    }
  }

  /// Select a package
  void selectPackage(Map<String, dynamic> package) {
    print('');
    print('✅ Package selected: ${package['name']}');
    selectedPackage.value = package;
  }

  /// Subscribe to the selected package with chosen wallet
  Future<void> subscribeWithWallet(String walletType) async {
    if (_isDisposed) return;

    if (selectedPackage.value == null) {
      Get.snackbar(
        'Erreur',
        'Veuillez sélectionner un package',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
      return;
    }

    // Check wallet balance
    final price = (selectedPackage.value!['price'] ?? 0).toDouble();
    final walletBalance = walletType == 'freemopay'
        ? wallet.value?.freemopayBalance ?? 0
        : wallet.value?.paypalBalance ?? 0;

    if (walletBalance < price) {
      Get.snackbar(
        'Solde insuffisant',
        'Votre ${walletType == 'freemopay' ? 'wallet FreeMoPay' : 'wallet PayPal'} n\'a pas un solde suffisant. Solde actuel: ${walletBalance.toStringAsFixed(0)} FCFA, Prix: ${price.toStringAsFixed(0)} FCFA',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.warningColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      return;
    }

    print('');
    print('========================================');
    print('💳 Subscribing to package with $walletType...');
    print('  └─ Package: ${selectedPackage.value!['name']}');
    print('  └─ Price: $price FCFA');
    print('  └─ Wallet Balance: $walletBalance FCFA');
    print('========================================');

    // Close bottom sheet first
    Get.back();

    // Show loading dialog
    PaymentLoadingDialog.show(
      message: 'Activation de votre package ${selectedPackage.value!['name']}...',
    );

    try {
      final packageId = selectedPackage.value!['id'] as int;
      final response = await PackageService.subscribeToPackage(
        packageId,
        walletType: walletType,
      );

      if (_isDisposed) return;

      // Hide loading dialog
      PaymentLoadingDialog.hide();

      if (response.success) {
        print('✅ Subscription successful!');

        // Reload wallet and package data in background
        Future.wait([
          loadWallet(),
          loadCurrentPackage(),
        ]);

        // Show success dialog with invoice URL if available
        final invoiceUrl = response.data?['invoice_url'];

        await PaymentSuccessDialog.show(
          packageName: selectedPackage.value!['name'],
          amount: price,
          paymentMethod: walletType,
          invoiceUrl: invoiceUrl,
        );

        // Navigation is handled by the success dialog
      } else {
        print('❌ Subscription failed: ${response.message}');

        Get.snackbar(
          'Erreur',
          response.message ?? 'Impossible de souscrire au package',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('💥 Exception during subscription: $e');

      // Hide loading dialog if still open
      PaymentLoadingDialog.hide();

      Get.snackbar(
        'Erreur',
        'Une erreur est survenue: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Refresh packages
  Future<void> refreshPackages() async {
    await Future.wait([
      loadPackages(),
      loadCurrentPackage(),
      loadWallet(),
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
