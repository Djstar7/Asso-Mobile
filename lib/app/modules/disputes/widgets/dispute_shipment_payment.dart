import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/providers/dispute_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/services/stripe_native_service.dart';
import '../../payment/widgets/mobile_money_waiting.dart';
import '../../payment/widgets/payment_method_selector.dart';
import '../../payment/widgets/wallet_payment_confirm_dialog.dart';
import '../../wallet/widgets/kpay_payment_sheet.dart';

/// Course d'un litige payée par le vendeur (remplacement ou retour) : choix du
/// partenaire de livraison, puis paiement comme un client (Wallet, Mobile Money
/// / OM, carte). Le dossier reprend dès que le paiement est confirmé.
class DisputeShipmentPayment {
  const DisputeShipmentPayment._();

  static String _price(double amount) => Get.isRegistered<CurrencyService>()
      ? CurrencyService.to.formatPrice(amount)
      : '${amount.toStringAsFixed(0)} FCFA';

  /// Renvoie true si la course est payée.
  static Future<bool> pay({required int shipmentId, required bool isReturn}) async {
    final partnersResponse = await DisputeService.shipmentPartners(shipmentId);
    if (!partnersResponse.success) {
      _error(partnersResponse.message);
      return false;
    }
    final quotes = Map<String, dynamic>.from(partnersResponse.data?['quotes'] as Map? ?? const {});
    final partners = ((quotes['partners'] as List?) ?? const [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    if (partners.isEmpty) {
      _error(quotes['message']?.toString() ?? 'disputes.payment.no_partner'.tr);
      return false;
    }

    final partner = await AppSheet.show<Map<String, dynamic>>(
      _PartnerPickerSheet(partners: partners, isReturn: isReturn),
    );
    if (partner == null) return false;

    final chosen = await DisputeService.choosePartner(shipmentId, partner);
    if (!chosen.success) {
      _error(chosen.message);
      return false;
    }
    final amount = double.tryParse('${chosen.data?['shipment']?['price'] ?? 0}') ?? 0;

    final method = await PaymentMethodSelector.show(
      amount: amount,
      currency: 'XAF',
      amountLabel: isReturn ? 'disputes.payment.return_fee'.tr : 'disputes.payment.replacement_fee'.tr,
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
          itemLabel: isReturn ? 'disputes.payment.return_fee'.tr : 'disputes.payment.replacement_fee'.tr,
          amount: amount,
          balance: method.balance ?? 0,
        );
        if (!ok) return false;
        mode = 'wallet';
      case 'kpay':
        final selection = await KpayDirectPaymentSheet.show(
          amount: amount,
          amountLabel: 'disputes.payment.delivery_fee'.tr,
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
      final response = await DisputeService.payShipment(shipmentId, paymentMode: mode, provider: provider, phone: phone);
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
      if (mode == 'kpay_direct') {
        // Rien n'est annoncé avant la réponse de l'opérateur.
        final outcome = await MobileMoneyWaiting.run(
          amount: amount,
          provider: provider!,
          phone: phone!,
          check: () => _state(shipmentId),
        );
        if (outcome.status == 'paid') {
          _paid();
          return true;
        }
        if (outcome.status == 'pending') _poll(shipmentId); // prévient à la réponse
        return false;
      }
      Get.snackbar(
        'disputes.payment.delivery_fee'.tr,
        response.message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return await _poll(shipmentId);
    } catch (e) {
      _error(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  /// État du paiement de la course (une lecture).
  static Future<MobileMoneyStatus> _state(int shipmentId) async {
    final shipment = (await DisputeService.shipmentPaymentStatus(shipmentId)).data?['shipment'];
    final status = shipment?['payment_status']?.toString();
    return (
      status: status == 'paid' || status == 'failed' ? status! : 'pending',
      failure: null,
    );
  }

  /// Suit la confirmation serveur du paiement (Mobile Money / carte).
  static Future<bool> _poll(int shipmentId) async {
    for (var i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        final shipment = (await DisputeService.shipmentPaymentStatus(shipmentId)).data?['shipment'];
        if (shipment?['payment_status'] == 'paid') {
          _paid();
          return true;
        }
        if (shipment?['payment_status'] == 'failed') {
          _error('disputes.payment.failed'.tr);
          return false;
        }
      } catch (_) {}
    }
    return false;
  }

  static void _paid() => Get.snackbar(
        'disputes.payment.paid_title'.tr,
        'disputes.payment.paid_message'.tr,
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

/// Partenaires de livraison disponibles pour la course, avec leur prix.
class _PartnerPickerSheet extends StatelessWidget {
  const _PartnerPickerSheet({required this.partners, required this.isReturn});

  final List<Map<String, dynamic>> partners;
  final bool isReturn;

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return AppSheet(
      title: 'disputes.payment.choose_partner'.tr,
      subtitle: isReturn ? 'disputes.payment.return_subtitle'.tr : 'disputes.payment.replacement_subtitle'.tr,
      child: Column(
        children: partners
            .map((partner) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDesign.space2),
                  child: Material(
                    color: ds.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                      side: BorderSide(color: ds.border),
                    ),
                    child: ListTile(
                      onTap: () => Navigator.of(context).pop(partner),
                      leading: Icon(Icons.local_shipping_outlined, color: ds.textSecondary),
                      title: Text(
                        '${partner['company_name'] ?? ''}',
                        style: context.body1.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [partner['route_label'], partner['lead_time']]
                            .where((v) => v != null && '$v'.isNotEmpty)
                            .join(' · '),
                        style: context.caption,
                      ),
                      trailing: Text(
                        DisputeShipmentPayment._price(double.tryParse('${partner['delivery_price']}') ?? 0),
                        style: context.body2.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
