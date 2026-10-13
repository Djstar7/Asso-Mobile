import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'kpay_phone_selector.dart';
import '../../../data/providers/api_provider.dart';
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

  late String _currency = _source;
  double? _converted; // montant converti dans la devise de l'opérateur
  bool _converting = false;

  String get _source {
    final code = widget.currency.toUpperCase();
    return code == 'FCFA' ? 'XAF' : code;
  }

  /// Montant à payer : un montant FCFA est affiché dans la devise de
  /// l'utilisateur, avec le montant FCFA entre parenthèses s'il diffère.
  String get _amountText {
    if (_source != 'XAF') {
      return CurrencyService.formatAmountInCurrency(widget.amount, _source);
    }
    final display = CurrencyService.formatFromPivot(widget.amount);
    final pivot = CurrencyService.formatAmountInCurrency(widget.amount, 'XAF');
    return display == pivot ? pivot : '$display ($pivot)';
  }

  /// Convertit le montant dans la devise de l'opérateur sélectionné.
  /// Purement pour l'affichage : la conversion débitée est refaite côté serveur.
  Future<void> _convertFor(String currency) async {
    if (currency == _source || currency.isEmpty) {
      if (mounted) {
        setState(() {
          _currency = _source;
          _converted = null;
          _converting = false;
        });
      }
      return;
    }
    setState(() {
      _currency = currency;
      _converting = true;
    });
    try {
      final res = await ApiProvider.get(
        '/v1/currencies/convert',
        queryParams: {'from': _source, 'to': currency, 'amount': widget.amount},
      );
      final value = res.data?['data']?['converted'];
      if (mounted) {
        setState(() {
          _converted = (value is num)
              ? value.toDouble()
              : double.tryParse('$value');
          _converting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _converted = null;
          _converting = false;
        });
      }
    }
  }

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
                    Text(
                      _amountText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppDesign.accentText,
                      ),
                    ),
                  ],
                ),
                // Montant converti dans la devise de l'opérateur (affichage)
                if (_currency != _source &&
                    (_converting || _converted != null)) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sync_alt_rounded,
                            size: 15,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'wallet.kpay.debited_by_operator'.tr,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      _converting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              '≈ ${CurrencyService.formatAmountInCurrency(_converted!, _currency)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppDesign.neutral900,
                              ),
                            ),
                    ],
                  ),
                ],
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
                  // Convertir l'affichage dès que la devise de l'opérateur change
                  if (currency != _currency) {
                    _convertFor(currency);
                  }
                },
          ),
        ],
      ),
    );
  }
}
