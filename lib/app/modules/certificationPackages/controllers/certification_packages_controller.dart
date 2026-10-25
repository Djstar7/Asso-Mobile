import 'package:asso/app/modules/payment/widgets/payment_preparation.dart';
import 'package:asso/app/core/utils/app_feedback.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../data/providers/package_service.dart';
import '../../../data/providers/wallet_service.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../packageSubscription/widgets/package_details_sheet.dart';
import '../../packageSubscription/widgets/sales_code_field.dart';
import '../../vendorDashboard/controllers/vendor_dashboard_controller.dart';
import '../../../core/utils/app_design.dart';

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
  RxBool get canUseSalesCode => salesCode.available;

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
        salesCode.applyEligibility(response.data);
        final packagesData = response.data!['packages'] as List?;
        if (packagesData != null) {
          packages.value = packagesData
              .map((e) => e as Map<String, dynamic>)
              .toList();
          // Formule recommandée (sinon la première) présélectionnée : son bouton
          // « Obtenir la certification » est visible dès l'arrivée.
          final keep = packages.firstWhereOrNull(
            (p) => p['id'] == selectedPackage.value?['id'],
          );
          selectedPackage.value =
              keep ??
              packages.firstWhereOrNull((p) => p['is_popular'] == true) ??
              packages.firstOrNull;
        }
      } else {
        AppFeedback.show(
          'certification.error'.tr,
          response.message.isNotEmpty
              ? response.message
              : 'certification.load_error'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      AppFeedback.show(
        'certification.error'.tr,
        'certification.generic_error_detail'.trParams({'error': '$e'}),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
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
  /// Renvoie l'id de l'abonnement créé (paiement à valider), ou null en cas d'échec.
  Future<int?> createOrder({
    required int packageId,
    String paymentMode = 'kpay_direct',
    String? kpayProvider,
    String? kpayPhone,
  }) async {
    if (_isDisposed) return null;
    isCreatingOrder.value = true;
    try {
      final response = await PaymentPreparation.run(
        method: paymentMode,
        action: () => PackageService.subscribePackageDirect(
          packageId,
          paymentMode: paymentMode,
          provider: kpayProvider,
          phoneNumber: kpayPhone,
          salesCode: salesCode.code,
          acceptOwnCode: salesCode.acceptOwnCode,
        ),
      );

      if (response.success) {
        final subscriptionId = response.data?['subscription_id'];
        return subscriptionId is int
            ? subscriptionId
            : int.tryParse('$subscriptionId');
      } else if (salesCode.handleServerRejection(response)) {
        return null;
      } else {
        AppFeedback.show(
          'certification.error'.tr,
          response.message.isNotEmpty
              ? response.message
              : 'certification.order_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return null;
      }
    } catch (e) {
      AppFeedback.show(
        'certification.error'.tr,
        'certification.generic_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
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
      final response = await PaymentPreparation.run(
        method: 'wallet',
        action: () => PackageService.subscribePackageDirect(
          packageId,
          paymentMode: 'wallet',
          salesCode: salesCode.code,
          acceptOwnCode: salesCode.acceptOwnCode,
        ),
      );
      if (salesCode.handleServerRejection(response)) return null;
      if (!response.success) {
        AppFeedback.show(
          'certification.payment_impossible'.tr,
          response.message.isNotEmpty
              ? response.message
              : 'wallet.errors.payment_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor,
          colorText: Colors.white,
        );
        return null;
      }
      loadWallet();
      return response.message.isNotEmpty
          ? response.message
          : 'certification.activated'.tr;
    } catch (e) {
      AppFeedback.show(
        'certification.error'.tr,
        'certification.generic_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      if (!_isDisposed) isCreatingOrder.value = false;
    }
  }

  /// Crée un abonnement payé par CARTE (Payment Sheet Stripe native).
  /// Retourne `{order_id, client_secret, payment_intent_id, publishable_key}` ou null.
  Future<Map<String, dynamic>?> createCardOrder({
    required int packageId,
  }) async {
    if (_isDisposed) return null;
    isCreatingOrder.value = true;
    try {
      final response = await PaymentPreparation.run(
        method: 'stripe_direct',
        action: () => PackageService.subscribePackageDirect(
          packageId,
          paymentMode: 'stripe_direct',
          salesCode: salesCode.code,
          acceptOwnCode: salesCode.acceptOwnCode,
        ),
      );

      if (salesCode.handleServerRejection(response)) return null;
      if (response.success) {
        final subscriptionId = response.data?['subscription_id'];
        final clientSecret = response.data?['client_secret']?.toString();
        final publishableKey = response.data?['publishable_key']?.toString();
        if (subscriptionId is int &&
            clientSecret != null &&
            clientSecret.isNotEmpty &&
            publishableKey != null &&
            publishableKey.isNotEmpty) {
          return {
            'order_id': subscriptionId,
            'client_secret': clientSecret,
            'payment_intent_id': response.data?['payment_intent_id']
                ?.toString(),
            'publishable_key': publishableKey,
          };
        }
        AppFeedback.show(
          'certification.error'.tr,
          'wallet.recharge.card_data_unavailable'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return null;
      } else {
        AppFeedback.show(
          'certification.error'.tr,
          response.message.isNotEmpty
              ? response.message
              : 'certification.order_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return null;
      }
    } catch (e) {
      AppFeedback.show(
        'certification.error'.tr,
        'certification.generic_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return null;
    } finally {
      if (!_isDisposed) isCreatingOrder.value = false;
    }
  }

  /// Paiement confirmé : la certification est active.
  void onPaymentConfirmed() {
    loadWallet();
    loadPackages();
    AppFeedback.show(
      'certification.payment_confirmed'.tr,
      'certification.activated_message'.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppDesign.success,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  /// Démarre le suivi du paiement (utilisé après la Payment Sheet carte).
  void pollOrderPayment(int orderId) => _pollOrderPayment(orderId);

  void _pollOrderPayment(int subscriptionId) async {
    for (int i = 0; i < 120; i++) {
      await Future.delayed(const Duration(seconds: 5));
      if (_isDisposed) return;
      try {
        final res = await PackageService.getSubscriptionPaymentStatus(
          subscriptionId,
        );
        final status = res.data?['data']?['status'];
        if (status == 'paid') {
          onPaymentConfirmed();
          return;
        } else if (status == 'failed') {
          AppFeedback.show(
            'package_subscription.payment_failed'.tr,
            'certification.payment_not_completed'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppThemeSystem.errorColor,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> refreshPackages() async {
    await Future.wait([loadPackages(), loadWallet()]);
  }

  /// Montant (prix en XAF) affiché dans la devise de l'utilisateur.
  String formatCurrency(double amountXaf) =>
      CurrencyService.formatFromPivot(amountXaf);

  /// Fiche détaillée avant paiement. Une boutique déjà certifiée voit sa
  /// certification prolongée à partir de l'échéance en cours (même règle que
  /// le serveur) : la fiche annonce la nouvelle date.
  Future<bool> confirmDetails(Map<String, dynamic> package) {
    final days = (package['duration_days'] as num?)?.toInt() ?? 0;
    DateTime? currentEnd;
    if (Get.isRegistered<VendorDashboardController>()) {
      final dashboard = Get.find<VendorDashboardController>();
      if (dashboard.isCertified.value) {
        currentEnd = DateTime.tryParse(
          dashboard.certificationExpiresAt.value ?? '',
        );
      }
    }
    final renewing = currentEnd != null && currentEnd.isAfter(DateTime.now());
    final end = (renewing ? currentEnd : DateTime.now()).add(
      Duration(days: days),
    );
    final endLabel = PackageDetailsSheet.formatDate(end);
    final duration = '${package['formatted_duration'] ?? ''}';

    return PackageDetailsSheet.show(
      typeLabel: 'package_details.types.certification'.tr,
      name: '${package['name'] ?? ''}',
      priceXaf: (package['price'] ?? 0).toDouble(),
      durationLabel: duration,
      description: package['description']?.toString(),
      facts: [
        PackageDetailFact(
          Icons.verified_outlined,
          'package_details.certification.badge'.tr,
          'package_details.certification.badge_value'.tr,
        ),
        PackageDetailFact(
          Icons.schedule_outlined,
          'package_details.duration'.tr,
          duration,
        ),
        PackageDetailFact(
          Icons.event_outlined,
          'package_details.valid_until'.tr,
          endLabel,
        ),
        PackageDetailFact(
          Icons.bolt_outlined,
          'package_details.activation'.tr,
          'package_details.activation_value'.tr,
        ),
      ],
      benefits: PackageDetailsSheet.benefitsOf(package['benefits']),
      notes: [
        renewing
            ? 'package_details.certification.renewal'.trParams({
                'from': PackageDetailsSheet.formatDate(currentEnd),
                'to': endLabel,
              })
            : 'package_details.certification.new'.trParams({'date': endLabel}),
        'package_details.certification.scope'.tr,
      ],
      salesCode: salesCode.code,
    );
  }

  @override
  void onClose() {
    _isDisposed = true;
    salesCode.dispose();
    super.onClose();
  }
}
