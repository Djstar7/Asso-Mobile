import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/app_design.dart';
import '../../core/widgets/deposit_widgets.dart';
import '../../data/providers/order_service.dart';
import '../../data/services/stripe_native_service.dart';
import '../wallet/widgets/kpay_payment_sheet.dart';
import 'widgets/payment_method_selector.dart';
import 'widgets/wallet_payment_confirm_dialog.dart';

/// Paiement du solde d'une commande avec acompte, débloqué après la livraison
/// et la vérification du produit avec ASSO. Partagé par « Mes commandes » et
/// le suivi des colis.
class DepositBalancePayment {
  const DepositBalancePayment._();

  /// Choix du moyen de paiement, paiement puis suivi de la confirmation.
  /// Renvoie true si le solde est payé.
  static Future<bool> pay({
    required int orderId,
    required String orderNumber,
    required DepositOrderInfo info,
  }) async {
    if (!info.balancePayable) return false;

    final method = await PaymentMethodSelector.show(
      amount: info.balanceAmount,
      currency: 'XAF',
      amountLabel: 'core.deposit.balance'.tr,
      allowedCodes: const {'kpay', 'stripe'},
      includeWallet: true,
    );
    if (method == null) return false;

    String mode;
    String? provider;
    String? phone;
    switch (method.code) {
      case 'wallet':
        final ok = await WalletPaymentConfirmDialog.show(
          itemLabel: 'core.deposit.balance_of'.trParams({'order': orderNumber}),
          amount: info.balanceAmount,
          balance: method.balance ?? 0,
        );
        if (!ok) return false;
        mode = 'wallet';
      case 'kpay':
        final selection = await KpayDirectPaymentSheet.show(
          amount: info.balanceAmount,
          amountLabel: 'core.deposit.balance'.tr,
        );
        if (selection == null) return false;
        mode = 'kpay_direct';
        provider = selection['provider'];
        phone = selection['phone'];
      case 'stripe':
        if (!StripeNativeService.isSupported) {
          _error('product.payment.card_mobile_only'.tr);
          return false;
        }
        mode = 'stripe_direct';
      default:
        _error('product.payment.method_unavailable'.tr);
        return false;
    }

    try {
      final response = await OrderService.payBalance(
        orderId,
        paymentMode: mode,
        provider: provider,
        phone: phone,
      );
      if (!response.success) {
        _error(response.message);
        return false;
      }

      if (mode == 'stripe_direct') {
        final data = response.data ?? const {};
        final paid = await StripeNativeService().payWithCard(
          publishableKey: data['publishable_key']?.toString() ?? '',
          clientSecret: data['client_secret']?.toString() ?? '',
        );
        if (!paid) {
          _error('product.payment.cancelled_message'.tr);
          return false;
        }
      }

      if (mode == 'wallet') {
        _paid();
        return true;
      }
      Get.snackbar(
        'core.deposit.balance'.tr,
        response.message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return await _poll(orderId);
    } catch (e) {
      _error(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// Suit la confirmation serveur du paiement du solde (Mobile Money / carte).
  static Future<bool> _poll(int orderId) async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        final data = (await OrderService.orderPaymentStatus(orderId)).data?['data'];
        if (data?['balance_status'] == 'paid') {
          _paid();
          return true;
        }
        if (data?['balance_payment_pending'] == false) {
          _error('core.deposit.balance_failed'.tr);
          return false;
        }
      } catch (_) {}
    }
    return false;
  }

  static void _paid() => Get.snackbar(
    'core.deposit.balance_status.paid'.tr,
    'core.deposit.balance_paid_message'.tr,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: AppDesign.success,
    colorText: Colors.white,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
  );

  static void _error(String message) => Get.snackbar(
    'my_order.errors.title'.tr,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: AppDesign.danger,
    colorText: Colors.white,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
  );
}
