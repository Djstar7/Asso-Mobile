import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';

/// Attente de la création du paiement, avant l'USSD ou la feuille Stripe.
/// Chaque opération possède sa route : sa fermeture ne touche ni une page,
/// ni une autre modale, même si l'opération échoue immédiatement.
class PaymentPreparation {
  const PaymentPreparation._();

  static Future<T> run<T>({
    required String method,
    required Future<T> Function() action,
  }) async {
    if (!{'kpay', 'kpay_direct', 'stripe', 'stripe_direct'}.contains(method)) {
      return action();
    }
    final navigator = Get.key.currentState;
    if (navigator == null) return action();
    final route = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) =>
          PaymentPreparationDialog(card: method.startsWith('stripe')),
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
  const PaymentPreparationDialog({super.key, required this.card});

  final bool card;

  @override
  Widget build(BuildContext context) => PopScope(
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
            Icon(
              card ? Icons.credit_card_rounded : Icons.phone_android_rounded,
              color: AppDesign.accent,
              size: 26,
            ),
          ],
        ),
      ),
      title: Text(
        (card
                ? 'payment.preparation.card_title'
                : 'payment.preparation.mobile_money_title')
            .tr,
        textAlign: TextAlign.center,
      ),
      content: Text(
        (card
                ? 'payment.preparation.card_message'
                : 'payment.preparation.mobile_money_message')
            .tr,
        textAlign: TextAlign.center,
      ),
    ),
  );
}
