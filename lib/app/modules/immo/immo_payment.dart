import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/real_estate_models.dart';
import '../../data/providers/real_estate_service.dart';
import '../../data/services/stripe_native_service.dart';
import '../payment/widgets/mobile_money_waiting.dart';
import '../payment/widgets/payment_method_selector.dart';
import '../payment/widgets/wallet_payment_confirm_dialog.dart';
import '../wallet/widgets/kpay_payment_sheet.dart';

/// Paiement d'une réservation immobilière, sur le modèle des autres parcours
/// (solde d'acompte, forfaits) : choix du moyen, Mobile Money ou carte, puis
/// attente de la confirmation du serveur. Renvoie la réservation payée.
class ImmoPayment {
  const ImmoPayment._();

  static Future<RealEstateReservation?> pay({
    required int listingId,
    required int total,
    required String label,
    required Map<String, dynamic> body,
  }) async {
    final method = await PaymentMethodSelector.show(
      amount: total.toDouble(),
      currency: 'XAF',
      amountLabel: label,
      allowedCodes: const {'kpay', 'stripe'},
      includeWallet: true,
    );
    if (method == null) return null;

    String mode;
    String? provider;
    String? phone;
    switch (method.code) {
      case 'wallet':
        final ok = await WalletPaymentConfirmDialog.show(
          itemLabel: label,
          amount: total.toDouble(),
          balance: method.balance ?? 0,
        );
        if (!ok) return null;
        mode = 'wallet';
      case 'kpay':
        final selection = await KpayDirectPaymentSheet.show(amount: total.toDouble(), amountLabel: label);
        if (selection == null) return null;
        mode = 'kpay_direct';
        provider = selection['provider'];
        phone = selection['phone'];
      case 'stripe':
        if (!StripeNativeService.isSupported) {
          _error('product.payment.card_mobile_only'.tr);
          return null;
        }
        mode = 'stripe_direct';
      default:
        _error('product.payment.method_unavailable'.tr);
        return null;
    }

    final res = await RealEstateService.reserve(listingId, {
      ...body,
      'payment_mode': mode,
      'provider': ?provider,
      'phone_number': ?phone,
    });
    final data = res.data?['data'];
    if (!res.success || data is! Map) {
      _error(res.message);
      return null;
    }
    var reservation = RealEstateReservation.fromJson(Map<String, dynamic>.from(data));
    if (mode == 'wallet') return reservation;

    if (mode == 'stripe_direct') {
      final paid = await StripeNativeService().payWithCard(
        publishableKey: reservation.publishableKey ?? '',
        clientSecret: reservation.clientSecret ?? '',
      );
      if (!paid) {
        _error('product.payment.cancelled_message'.tr);
        return null;
      }
      return _poll(reservation.id);
    }

    final outcome = await MobileMoneyWaiting.run(
      amount: total.toDouble(),
      provider: provider!,
      phone: phone!,
      check: () async {
        final r = await RealEstateService.reservationPaymentStatus(reservation.id);
        if (r == null) return (status: 'pending', failure: null);
        reservation = r;
        if (r.isPaid) return (status: 'paid', failure: null);
        if (r.status == 'cancelled') return (status: 'failed', failure: null);
        return (status: 'pending', failure: null);
      },
    );
    if (outcome.status == 'paid') return reservation;
    if (outcome.status == 'pending') {
      Get.snackbar('immo.reserve.pending_title'.tr, 'immo.reserve.pending_message'.tr, snackPosition: SnackPosition.BOTTOM);
    }

    return null;
  }

  static Future<RealEstateReservation?> _poll(int id) async {
    for (var i = 0; i < 24; i++) {
      final r = await RealEstateService.reservationPaymentStatus(id);
      if (r != null && r.isPaid) return r;
      if (r?.status == 'cancelled') return null;
      await Future.delayed(const Duration(seconds: 5));
    }
    Get.snackbar('immo.reserve.pending_title'.tr, 'immo.reserve.pending_message'.tr, snackPosition: SnackPosition.BOTTOM);

    return null;
  }

  static void _error(String message) {
    if (message.isEmpty) return;
    Get.snackbar('immo.reserve.error'.tr, message, snackPosition: SnackPosition.BOTTOM, margin: const EdgeInsets.all(16));
  }
}
