import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/values/kpay_catalog.dart';

/// État d'un paiement Mobile Money relu sur le serveur : `paid`, `failed`
/// (avec le motif de l'opérateur s'il est connu) ou `pending`.
typedef MobileMoneyStatus = ({String status, String? failure});

/// Attente de la validation d'un paiement Mobile Money (USSD), commune à tous
/// les parcours : commande, gros, acompte, Diaspo, forfaits, boost,
/// certification, litiges.
///
/// Rien n'est annoncé comme réussi avant la réponse de l'opérateur : une
/// fenêtre d'attente reste ouverte pendant que [check] est relu, puis
///  - `paid`    : l'appelant affiche son succès ;
///  - `failed`  : le motif est expliqué ici (numéro d'un autre réseau, solde
///                insuffisant…) et l'appelant laisse l'acheteur réessayer ;
///  - `pending` : délai dépassé ou « Continuer en arrière-plan » — l'appelant
///                poursuit le suivi et prévient à la réponse.
class MobileMoneyWaiting {
  const MobileMoneyWaiting._();

  static Future<MobileMoneyStatus> run({
    /// Montant à payer (XAF, sauf si [formatAmount] le présente autrement).
    required double amount,
    required String provider,
    required String phone,
    required Future<MobileMoneyStatus> Function() check,
    String Function(double amount)? formatAmount,
    String? failureNote,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final background = Completer<void>();
    BuildContext? dialogContext;

    Get.dialog(
      Builder(
        builder: (context) {
          dialogContext = context;
          return _WaitingDialog(
            amount: formatAmount?.call(amount) ??
                '${amount.toStringAsFixed(0)} FCFA',
            operator: KPayCatalog.labelFor(provider),
            phone: '+$phone',
            onBackground: () {
              if (!background.isCompleted) background.complete();
            },
          );
        },
      ),
      barrierDismissible: false,
    );

    final outcome = await Future.any([
      _poll(check, timeout, () => background.isCompleted),
      background.future.then((_) => (status: 'pending', failure: null)),
    ]);
    // Contexte de la fenêtre elle-même, vérifié (mounted) avant usage.
    // ignore: use_build_context_synchronously
    _close(dialogContext);

    if (outcome.status == 'failed') {
      await _showFailure(outcome.failure, failureNote);
    }
    return outcome;
  }

  /// Explication d'un refus Mobile Money, d'après le motif de l'opérateur.
  static String failureMessage(String? failure) => switch (failure) {
    'wrong_network' => 'payment.mobile_money.failed_wrong_network'.tr,
    'insufficient_funds' => 'payment.mobile_money.failed_insufficient_funds'.tr,
    'expired' => 'payment.mobile_money.failed_expired'.tr,
    'declined' => 'payment.mobile_money.failed_declined'.tr,
    _ => 'payment.mobile_money.failed_generic'.tr,
  };

  static Future<MobileMoneyStatus> _poll(
    Future<MobileMoneyStatus> Function() check,
    Duration timeout,
    bool Function() stopped,
  ) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 3));
      if (stopped()) break;
      try {
        final state = await check();
        if (state.status == 'paid' || state.status == 'failed') return state;
      } catch (_) {
        // Réseau momentané : on relit au tour suivant.
      }
    }
    return (status: 'pending', failure: null);
  }

  /// Retire exactement la fenêtre d'attente, même si une autre route s'est
  /// ouverte par-dessus (cf. PaymentLoadingDialog.hide).
  static void _close(BuildContext? context) {
    if (context == null || !context.mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    Navigator.of(context).removeRoute(route);
  }

  static Future<void> _showFailure(String? failure, String? note) {
    return Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.error_rounded,
          color: AppDesign.danger,
          size: 56,
        ),
        title: Text(
          'payment.mobile_money.failed_title'.tr,
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(failureMessage(failure), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              note ?? 'payment.mobile_money.nothing_charged'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppThemeSystem.grey600),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
              ),
              child: Text(
                'payment.mobile_money.retry'.tr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaitingDialog extends StatelessWidget {
  final String amount;
  final String operator;
  final String phone;
  final VoidCallback onBackground;

  const _WaitingDialog({
    required this.amount,
    required this.operator,
    required this.phone,
    required this.onBackground,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(strokeWidth: 3.5),
        ),
        title: Text(
          'payment.mobile_money.waiting_title'.tr,
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              amount,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '$operator · $phone',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppThemeSystem.grey600),
            ),
            const SizedBox(height: 12),
            Text(
              'payment.mobile_money.waiting_message'.tr,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: onBackground,
            child: Text('payment.mobile_money.waiting_background'.tr),
          ),
        ],
      ),
    );
  }
}
