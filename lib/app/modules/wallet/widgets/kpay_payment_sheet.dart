import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'kpay_phone_selector.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_sheet.dart';

/// Bottom sheet de paiement KPay direct (achat produit, diaspo…).
/// Affiche le montant à payer + le sélecteur pays→opérateur→numéro et renvoie
/// `{provider, phone, currency}` à la confirmation (ou null si annulé).
class KpayDirectPaymentSheet extends StatefulWidget {
  final double amount;

  /// Devise de [amount] : XAF (commandes, forfaits…) ou celle d'une offre Diaspo.
  final String currency;
  final String? amountLabel; // ex. "Total à payer"

  const KpayDirectPaymentSheet({
    super.key,
    required this.amount,
    this.currency = 'XAF',
    this.amountLabel,
  });

  /// Affiche le sheet ; renvoie {provider, phone, currency} ou null.
  static Future<Map<String, String>?> show({
    required double amount,
    String currency = 'XAF',
    String? amountLabel,
  }) {
    return AppSheet.show<Map<String, String>>(
      KpayDirectPaymentSheet(
          amount: amount,
          currency: currency,
          amountLabel: amountLabel ?? 'wallet.kpay.total_to_pay'.tr),
    );
  }

  @override
  State<KpayDirectPaymentSheet> createState() => _KpayDirectPaymentSheetState();
}

class _KpayDirectPaymentSheetState extends State<KpayDirectPaymentSheet> {
  String? _provider;
  String? _phone;
  bool _valid = false;

  /// Montant à payer, affiché uniquement dans la devise de l'utilisateur
  /// (converti depuis sa devise d'origine : FCFA, devise d'une offre Diaspo…).
  /// La conversion vers la devise de l'opérateur est faite par le serveur.
  String get _amountText =>
      CurrencyService.formatFromCurrency(widget.amount, widget.currency);

  @override
  Widget build(BuildContext context) {
    final canPay = _valid && _provider != null && _phone != null;

    // Le bouton de paiement est épinglé au-dessus du clavier. Au bout du
    // contenu, il passait dessous pendant la saisie du numéro ; il fallait
    // alors faire défiler la feuille de force, ce qui la secouait. Et la
    // marge du clavier n'est plus ajoutée ici : la route de la feuille s'en
    // charge déjà, la compter deux fois écrasait le formulaire.
    return AppSheet(
      title: 'wallet.webview.title_mobile_money'.tr,
      footer: SizedBox(
        height: 52,
        child: ElevatedButton(
          // Navigator et non Get.back() : avec GetX 4.7.3, Get.back() ne ferme
          // que la bannière éventuellement affichée, et « Payer » restait
          // sans effet.
          onPressed: canPay
              ? () => Navigator.of(
                  context,
                ).pop({'provider': _provider!, 'phone': _phone!})
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppDesign.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'wallet.kpay.pay_now'.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Montant à payer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              // Décor de la feuille : l'accent de marque, et non un
              // orange voisin qui faisait cohabiter deux primaires.
              color: AppDesign.accentSubtle,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.amountLabel ?? 'wallet.kpay.amount_to_pay'.tr,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    Obx(
                      () => Text(
                        _amountText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppDesign.accentText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          KpayPhoneSelector(
            onChanged:
                ({
                  required String? providerCode,
                  required String? phoneNumber,
                  required String currency,
                  required bool isValid,
                }) {
                  setState(() {
                    _provider = providerCode;
                    _phone = phoneNumber;
                    _valid = isValid;
                  });
                },
          ),
        ],
      ),
    );
  }
}
