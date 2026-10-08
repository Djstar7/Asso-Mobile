import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import 'app_ui.dart';

/// Commande avec acompte (produits sur commande / importés).
///
/// L'acheteur paie l'acompte (et la livraison) à la commande. Le solde n'est
/// payable qu'après la livraison ou le retrait, une fois que le client et un
/// employé ASSO ont vérifié ensemble la marchandise.

/// Option « acompte » d'un produit renvoyé par l'API.
class DepositProduct {
  const DepositProduct._();

  static bool enabled(Map<String, dynamic> product) {
    final value = product['deposit_enabled'];
    final on = value == true || value == 1 || value == '1' || value == 'true';
    return on && rate(product) > 0;
  }

  /// Acompte en % du prix acheteur.
  static double rate(Map<String, dynamic> product) {
    final raw = product['deposit_rate'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  /// Acompte d'une ligne, arrondi au franc comme le serveur.
  static double depositFor(double buyerTotalXaf, double rate) =>
      (buyerTotalXaf * rate / 100).roundToDouble();
}

/// Bloc « Produit sur commande » de la fiche : total, acompte, solde et
/// rappel de la vérification ASSO avant le solde.
class DepositInfoCard extends StatelessWidget {
  const DepositInfoCard({
    super.key,
    required this.total,
    required this.deposit,
    required this.balance,
  });

  final String total;
  final String deposit;
  final String balance;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.body2,
                color: AppDesign.warningText,
                fontWeight: strong ? FontWeight.w700 : null,
              ),
            ),
          ),
          Text(
            value,
            style: context.textStyle(
              FontSizeType.body2,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: AppDesign.warningText,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(
        color: AppDesign.warningSubtle,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppBadge(
            label: 'core.deposit.on_order'.tr,
            tone: AppBadgeTone.warning,
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: AppDesign.space2),
          row('core.deposit.total_price'.tr, total),
          row('core.deposit.deposit_now'.tr, deposit, strong: true),
          row('core.deposit.balance_later'.tr, balance),
          const SizedBox(height: AppDesign.space2),
          Text(
            'core.deposit.verification_notice'.tr,
            style: context.textStyle(
              FontSizeType.caption,
              color: AppDesign.warningText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Champs « acompte » d'une commande (`order.deposit` de l'API).
class DepositOrderInfo {
  DepositOrderInfo(this.raw);

  final Map<String, dynamic> raw;

  static DepositOrderInfo? fromOrder(Map<String, dynamic>? order) {
    final deposit = order?['deposit'];
    return deposit is Map
        ? DepositOrderInfo(Map<String, dynamic>.from(deposit))
        : null;
  }

  double _num(String key) {
    final value = raw[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double get depositAmount => _num('deposit_amount');
  double get balanceAmount => _num('balance_amount');
  String? get balanceStatus => raw['balance_status']?.toString();
  String? get verificationStatus => raw['verification_status']?.toString();
  bool get balancePayable => raw['balance_payable'] == true;
  bool get balancePaid => balanceStatus == 'paid';

  /// Étapes de la timeline : [{key, state: done|current|todo}].
  List<Map<String, dynamic>> get timeline => [
    for (final step in (raw['timeline'] as List? ?? const []))
      if (step is Map) Map<String, dynamic>.from(step),
  ];
}

/// Suivi d'une commande avec acompte, de l'acompte à la remise.
class DepositOrderTimeline extends StatelessWidget {
  const DepositOrderTimeline({super.key, required this.info});

  final DepositOrderInfo info;

  @override
  Widget build(BuildContext context) {
    final steps = info.timeline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepRow(
            label: 'core.deposit.steps.${steps[i]['key']}'.tr,
            state: steps[i]['state']?.toString() ?? 'todo',
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.state,
    required this.isLast,
  });

  final String label;
  final String state;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final done = state == 'done';
    final current = state == 'current';
    final color = done
        ? AppDesign.success
        : current
        ? AppDesign.accent
        : context.ds.textTertiary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : current
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: color,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: done ? AppDesign.success : context.ds.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppDesign.space2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppDesign.space3),
              child: Text(
                label,
                style: context.textStyle(
                  FontSizeType.body2,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                  color: done || current
                      ? context.ds.textPrimary
                      : context.ds.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Montants et action « Payer le solde » d'une commande avec acompte.
class DepositBalanceCard extends StatelessWidget {
  const DepositBalanceCard({
    super.key,
    required this.info,
    required this.total,
    required this.formatPrice,
    this.onPayBalance,
    this.isPaying = false,
  });

  final DepositOrderInfo info;
  final double total;
  final String Function(double amountXaf) formatPrice;
  final VoidCallback? onPayBalance;
  final bool isPaying;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.body2,
                color: context.ds.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: context.textStyle(
              FontSizeType.body2,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: strong ? AppDesign.accent : context.ds.textPrimary,
            ),
          ),
        ],
      ),
    );

    final status = switch (info.balanceStatus) {
      'paid' => 'core.deposit.balance_status.paid'.tr,
      'unlocked' => 'core.deposit.balance_status.unlocked'.tr,
      'cancelled' => 'core.deposit.balance_status.cancelled'.tr,
      _ => 'core.deposit.balance_status.locked'.tr,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row('core.deposit.total_price'.tr, formatPrice(total)),
        row(
          'core.deposit.already_paid'.tr,
          formatPrice(info.balancePaid ? total : info.depositAmount),
        ),
        row(
          'core.deposit.balance'.tr,
          formatPrice(info.balanceAmount),
          strong: !info.balancePaid,
        ),
        const SizedBox(height: AppDesign.space2),
        Text(status, style: context.caption),
        if (info.balancePayable && onPayBalance != null) ...[
          const SizedBox(height: AppDesign.space3),
          AppButton(
            label: 'core.deposit.pay_balance'.trParams({
              'amount': formatPrice(info.balanceAmount),
            }),
            icon: Icons.lock_rounded,
            size: AppButtonSize.large,
            isLoading: isPaying,
            onPressed: isPaying ? null : onPayBalance,
          ),
        ],
      ],
    );
  }
}

/// Commande avec acompte côté vendeur : il est payé une fois le produit livré,
/// vérifié avec ASSO et le solde réglé par le client.
class DepositVendorNotice extends StatelessWidget {
  const DepositVendorNotice({super.key, required this.info, required this.settled});

  final DepositOrderInfo info;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final status = switch (info.balanceStatus) {
      _ when settled => 'core.deposit.vendor.settled'.tr,
      'cancelled' => 'core.deposit.balance_status.cancelled'.tr,
      'unlocked' => 'core.deposit.vendor.balance_due'.tr,
      _ when info.verificationStatus != null && info.verificationStatus != 'pending' =>
        'core.deposit.vendor.verification'.tr,
      _ => 'core.deposit.vendor.in_progress'.tr,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesign.space2),
      decoration: BoxDecoration(
        color: settled ? AppDesign.successSubtle : AppDesign.warningSubtle,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            settled ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 16,
            color: settled ? AppDesign.success : AppDesign.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${'core.deposit.vendor.title'.tr} · $status',
              style: context.textStyle(
                FontSizeType.caption,
                fontWeight: FontWeight.w600,
                color: settled ? AppDesign.successText : AppDesign.warningText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
