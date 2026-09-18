import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/currency_service.dart';

/// Confirmation d'un paiement par solde Wallet ASSO : montant, solde avant/après.
/// Montants attendus en XAF (devise du Wallet), affichés dans la devise utilisateur.
///
/// Renvoie true si l'utilisateur confirme. Réutilisable par tous les parcours qui
/// acceptent le Wallet (forfaits, certification, commandes).
class WalletPaymentConfirmDialog extends StatelessWidget {
  final String title;
  final String itemLabel;
  final double amount;
  final double balance;

  const WalletPaymentConfirmDialog({
    super.key,
    required this.title,
    required this.itemLabel,
    required this.amount,
    required this.balance,
  });

  static Future<bool> show({
    required String itemLabel,
    required double amount,
    required double balance,
    String title = 'Payer avec mon Wallet',
  }) async {
    final ok = await Get.dialog<bool>(
      WalletPaymentConfirmDialog(
        title: title,
        itemLabel: itemLabel,
        amount: amount,
        balance: balance,
      ),
    );
    return ok == true;
  }

  /// Montants reçus en XAF, affichés dans la devise de l'utilisateur.
  String _fmt(double v) => CurrencyService.formatFromPivot(v);

  @override
  Widget build(BuildContext context) {
    final after = balance - amount;

    Widget row(String label, String value, {bool strong = false, Color? color}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: AppThemeSystem.getSecondaryTextColor(context),
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: strong ? 16 : 14,
                fontWeight: strong ? FontWeight.bold : FontWeight.w600,
                color: color ?? AppThemeSystem.getPrimaryTextColor(context),
              ),
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      backgroundColor: AppThemeSystem.getSurfaceColor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded, color: AppThemeSystem.successColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.getPrimaryTextColor(context),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            itemLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppThemeSystem.getPrimaryTextColor(context),
            ),
          ),
          const SizedBox(height: 12),
          row('Solde actuel', _fmt(balance)),
          row('À payer', '− ${_fmt(amount)}', color: AppThemeSystem.errorColor),
          const Divider(height: 20),
          row('Solde après paiement', _fmt(after), strong: true),
          const SizedBox(height: 8),
          Text(
            'Le montant est débité immédiatement de votre Wallet ASSO.',
            style: TextStyle(
              fontSize: 12,
              color: AppThemeSystem.getSecondaryTextColor(context),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeSystem.successColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Confirmer le paiement'),
        ),
      ],
    );
  }
}
