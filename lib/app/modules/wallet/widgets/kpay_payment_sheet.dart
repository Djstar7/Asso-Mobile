import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'kpay_phone_selector.dart';
import '../../../data/providers/api_provider.dart';
import '../../../core/utils/app_design.dart';

/// Bottom sheet de paiement KPay direct (achat produit, diaspo…).
/// Affiche le montant à payer + le sélecteur pays→opérateur→numéro et renvoie
/// `{provider, phone, currency}` à la confirmation (ou null si annulé).
class KpayDirectPaymentSheet extends StatefulWidget {
  final double amount;
  final String amountLabel; // ex. "Total à payer"

  const KpayDirectPaymentSheet({
    super.key,
    required this.amount,
    this.amountLabel = 'Montant à payer',
  });

  /// Affiche le sheet ; renvoie {provider, phone, currency} ou null.
  static Future<Map<String, String>?> show({
    required double amount,
    String amountLabel = 'Total à payer',
  }) {
    return Get.bottomSheet<Map<String, String>>(
      KpayDirectPaymentSheet(amount: amount, amountLabel: amountLabel),
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }

  @override
  State<KpayDirectPaymentSheet> createState() => _KpayDirectPaymentSheetState();
}

class _KpayDirectPaymentSheetState extends State<KpayDirectPaymentSheet> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _payButtonKey = GlobalKey();
  String? _provider;
  String? _phone;
  bool _valid = false;

  String _currency = 'XAF';
  double? _converted; // montant converti dans la devise de l'opérateur
  bool _converting = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Amène le bouton de paiement dans le champ visible une fois la saisie
  /// valide, sans secouer la feuille.
  ///
  /// L'ancienne version se déclenchait à chaque frappe et forçait le bouton en
  /// bas du viewport (`alignment: 1`) : le contenu remontait brutalement à
  /// chaque caractère et l'en-tête (titre, montant, pays) sortait de l'écran.
  /// On ne défile donc plus que lorsque le numéro devient valide, et seulement
  /// si le bouton est réellement hors champ.
  void _revealPaymentButton() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final buttonContext = _payButtonKey.currentContext;
      if (buttonContext == null) return;

      final box = buttonContext.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;

      // Bas du bouton dans le repère de l'écran, comparé à la zone libre
      // au-dessus du clavier.
      final bottomOfButton =
          box.localToGlobal(Offset(0, box.size.height)).dy;
      final visibleBottom = MediaQuery.sizeOf(context).height -
          MediaQuery.viewInsetsOf(context).bottom;

      if (bottomOfButton <= visibleBottom) return;

      _scrollController.animateTo(
        (_scrollController.offset + (bottomOfButton - visibleBottom) + 16)
            .clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  /// Convertit le montant (XAF) dans la devise de l'opérateur sélectionné.
  /// Purement pour l'affichage : la conversion débitée est refaite côté serveur.
  Future<void> _convertFor(String currency) async {
    if (currency == 'XAF' || currency.isEmpty) {
      if (mounted) {
        setState(() {
            _currency = 'XAF';
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
        queryParams: {'from': 'XAF', 'to': currency, 'amount': widget.amount},
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
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Paiement Mobile Money',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

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
                        widget.amountLabel,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Text(
                        '${widget.amount.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppDesign.accentText,
                        ),
                      ),
                    ],
                  ),
                  // Montant converti dans la devise de l'opérateur (affichage)
                  if (_currency != 'XAF' &&
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
                              'Débité par votre opérateur',
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                '≈ ${_converted!.toStringAsFixed(0)} $_currency',
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
                    final becameValid = isValid && !_valid;
                    setState(() {
                      _provider = providerCode;
                      _phone = phoneNumber;
                      _valid = isValid;
                    });
                    if (becameValid) _revealPaymentButton();
                    // Convertir l'affichage dès que la devise de l'opérateur change
                    if (currency != _currency) {
                      _convertFor(currency);
                    }
                  },
            ),
            const SizedBox(height: 24),

            SizedBox(
              key: _payButtonKey,
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_valid && _provider != null && _phone != null)
                    ? () => Get.back(
                        result: {'provider': _provider!, 'phone': _phone!},
                      )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesign.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Payer maintenant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
