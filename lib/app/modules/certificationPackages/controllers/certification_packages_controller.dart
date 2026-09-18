import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../data/providers/package_service.dart';
import '../../../data/providers/wallet_service.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../packageSubscription/widgets/sales_code_field.dart';

class CertificationPackagesController extends GetxController {
  bool _isDisposed = false;
  bool get isSafe => !_isDisposed && isClosed == false;

  final packages = <Map<String, dynamic>>[].obs;
  final selectedPackage = Rx<Map<String, dynamic>?>(null);
  final isLoading = false.obs;
  final isCreatingOrder = false.obs;

  final wallet = Rx<WalletModel?>(null);
  final isLoadingWallet = false.obs;

  // P6 : code commercial facultatif, vérifié avant le paiement.
  final salesCode = SalesCodeInput();

  @override
  void onInit() {
    super.onInit();
    loadPackages();
    loadWallet();
  }

  Future<void> loadPackages() async {
    if (_isDisposed) return;
    isLoading.value = true;
    try {
      final response = await PackageService.getCertificationPackages();
      if (_isDisposed) return;
      if (response.success && response.data != null) {
        final packagesData = response.data!['packages'] as List?;
        if (packagesData != null) {
          packages.value = packagesData.map((e) => e as Map<String, dynamic>).toList();
        }
      } else {
        Get.snackbar('Erreur', response.message ?? 'Impossible de charger les packages',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppThemeSystem.errorColor, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Une erreur est survenue: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadWallet() async {
    if (_isDisposed) return;
    isLoadingWallet.value = true;
    try {
      final response = await WalletService.getWallet();
      if (_isDisposed) return;
      if (response.success && response.data != null) {
        final walletData = response.data!['data'] ?? response.data!;
        wallet.value = WalletModel.fromJson(walletData);
      }
    } catch (_) {
    } finally {
      isLoadingWallet.value = false;
    }
  }

  void selectPackage(Map<String, dynamic> package) {
    selectedPackage.value = package;
  }

  /// KPay direct (USSD) — équivalent de ProductController.createOrder
/// Confirmer et créer l'abonnement — paiement Mobile Money (KPay direct, USSD).
Future<bool> createOrder({
  required int packageId,
  String paymentMode = 'kpay_direct',
  String? kpayProvider,
  String? kpayPhone,
}) async {
  if (_isDisposed) return false;
  isCreatingOrder.value = true;
  try {
    final response = await PackageService.subscribePackageDirect(
      packageId,
      paymentMode: paymentMode,
      provider: kpayProvider,
      phoneNumber: kpayPhone,
      salesCode: salesCode.code,
    );

    if (response.success) {
      final subscriptionId = response.data?['subscription_id'];
      if (paymentMode == 'kpay_direct' && subscriptionId is int) {
        _pollOrderPayment(subscriptionId);
      }
      return true;
    } else if (salesCode.handleServerRejection(response)) {
      return false;
    } else {
      Get.snackbar('Erreur', response.message.isNotEmpty ? response.message : 'Échec de la commande',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  } catch (e) {
    Get.snackbar('Erreur', 'Une erreur est survenue', snackPosition: SnackPosition.BOTTOM);
    return false;
  } finally {
    if (!_isDisposed) isCreatingOrder.value = false;
  }
}

/// Paie la certification avec le solde du Wallet ASSO (activation immédiate).
/// Renvoie le message de succès du serveur, ou null en cas d'échec (snackbar affiché).
Future<String?> payWithWallet({required int packageId}) async {
  if (_isDisposed || isCreatingOrder.value) return null;
  isCreatingOrder.value = true;
  try {
    final response = await PackageService.subscribePackageDirect(
      packageId,
      paymentMode: 'wallet',
      salesCode: salesCode.code,
    );
    if (salesCode.handleServerRejection(response)) return null;
    if (!response.success) {
      Get.snackbar('Paiement impossible',
          response.message.isNotEmpty ? response.message : 'Échec du paiement',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor, colorText: Colors.white);
      return null;
    }
    loadWallet();
    return response.message.isNotEmpty ? response.message : 'Certification activée.';
  } catch (e) {
    Get.snackbar('Erreur', 'Une erreur est survenue', snackPosition: SnackPosition.BOTTOM);
    return null;
  } finally {
    if (!_isDisposed) isCreatingOrder.value = false;
  }
}

/// Crée un abonnement payé par CARTE (Payment Sheet Stripe native).
/// Retourne `{order_id, client_secret, payment_intent_id, publishable_key}` ou null.
Future<Map<String, dynamic>?> createCardOrder({required int packageId}) async {
  if (_isDisposed) return null;
  isCreatingOrder.value = true;
  try {
    final response = await PackageService.subscribePackageDirect(
      packageId,
      paymentMode: 'stripe_direct',
      salesCode: salesCode.code,
    );

    if (salesCode.handleServerRejection(response)) return null;
    if (response.success) {
      final subscriptionId = response.data?['subscription_id'];
      final clientSecret = response.data?['client_secret']?.toString();
      final publishableKey = response.data?['publishable_key']?.toString();
      if (subscriptionId is int &&
          clientSecret != null && clientSecret.isNotEmpty &&
          publishableKey != null && publishableKey.isNotEmpty) {
        return {
          'order_id': subscriptionId,
          'client_secret': clientSecret,
          'payment_intent_id': response.data?['payment_intent_id']?.toString(),
          'publishable_key': publishableKey,
        };
      }
      Get.snackbar('Erreur', 'Données de paiement carte indisponibles', snackPosition: SnackPosition.BOTTOM);
      return null;
    } else {
      Get.snackbar('Erreur', response.message.isNotEmpty ? response.message : 'Échec de la commande',
          snackPosition: SnackPosition.BOTTOM);
      return null;
    }
  } catch (e) {
    Get.snackbar('Erreur', 'Une erreur est survenue', snackPosition: SnackPosition.BOTTOM);
    return null;
  } finally {
    if (!_isDisposed) isCreatingOrder.value = false;
  }
}

/// Démarre le suivi du paiement (utilisé après la Payment Sheet carte).
void pollOrderPayment(int orderId) => _pollOrderPayment(orderId);

void _pollOrderPayment(int subscriptionId) async {
  for (int i = 0; i < 120; i++) {
    await Future.delayed(const Duration(seconds: 5));
    if (_isDisposed) return;
    try {
      final res = await PackageService.getSubscriptionPaymentStatus(subscriptionId);
      final status = res.data?['data']?['status'];
      if (status == 'paid') {
        loadWallet();
        loadPackages();
        Get.snackbar('Paiement confirmé', 'Votre certification a été activée.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green, colorText: Colors.white,
            duration: const Duration(seconds: 4));
        return;
      } else if (status == 'failed') {
        Get.snackbar('Paiement échoué', 'Le paiement n\'a pas abouti.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppThemeSystem.errorColor, colorText: Colors.white,
            duration: const Duration(seconds: 5));
        return;
      }
    } catch (_) {}
  }
}
  Future<void> refreshPackages() async {
    await Future.wait([loadPackages(), loadWallet()]);
  }

  /// Montant (prix en XAF) affiché dans la devise de l'utilisateur.
  String formatCurrency(double amountXaf) => CurrencyService.formatFromPivot(amountXaf);

  @override
  void onClose() {
    _isDisposed = true;
    salesCode.dispose();
    super.onClose();
  }
}