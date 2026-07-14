import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'kpay_phone_selector.dart';

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
  String? _provider;
  String? _phone;
  bool _valid = false;

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
            const Text('Paiement KPay',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Montant à payer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFF7900).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.amountLabel,
                      style: TextStyle(color: Colors.grey.shade700)),
                  Text('${widget.amount.toStringAsFixed(0)} FCFA',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7900))),
                ],
              ),
            ),
            const SizedBox(height: 20),

            KpayPhoneSelector(
              onChanged: ({
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
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_valid && _provider != null && _phone != null)
                    ? () => Get.back(result: {
                          'provider': _provider!,
                          'phone': _phone!,
                        })
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7900),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Payer maintenant',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
