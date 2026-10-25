import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';

/// Attente du paiement Wallet ou de la préparation USSD / Stripe.
/// Chaque opération possède sa route : sa fermeture ne touche ni une page,
/// ni une autre modale, même si l'opération échoue immédiatement.
class PaymentPreparation {
  const PaymentPreparation._();

  static Future<T> run<T>({
    required String method,
    required Future<T> Function() action,
  }) async {
    if (!{
      'wallet',
      'kpay',
      'kpay_direct',
      'stripe',
      'stripe_direct',
    }.contains(method)) {
      return action();
    }
    final navigator = Get.key.currentState;
    if (navigator == null) return action();
    final route = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => PaymentPreparationDialog(method: method),
    );
    navigator.push(route);
    try {
      return await action();
    } finally {
      if (route.isActive && navigator.mounted) {
        navigator.removeRoute(route);
        await route.completed;
      }
    }
  }
}

class PaymentPreparationDialog extends StatelessWidget {
  const PaymentPreparationDialog({super.key, required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final kind = method == 'wallet'
        ? 'wallet'
        : method.startsWith('stripe')
        ? 'card'
        : 'mobile_money';
    final icon = switch (kind) {
      'wallet' => Icons.account_balance_wallet_outlined,
      'card' => Icons.credit_card_rounded,
      _ => Icons.phone_android_rounded,
    };
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox.square(
                dimension: 56,
                child: CircularProgressIndicator(
                  color: AppDesign.accent,
                  strokeWidth: 3,
                ),
              ),
              Icon(icon, color: AppDesign.accent, size: 26),
            ],
          ),
        ),
        title: Text(
          'payment.preparation.${kind}_title'.tr,
          textAlign: TextAlign.center,
        ),
        content: Text(
          'payment.preparation.${kind}_message'.tr,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
