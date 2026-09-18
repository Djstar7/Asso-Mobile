import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../controllers/wallet_controller.dart';
import 'kpay_phone_selector.dart';

/// Bottom sheet d'enregistrement des coordonnées de retrait Mobile Money.
///
/// Le compte enregistré pré-remplit ensuite chaque retrait. Le virement bancaire
/// (IBAN) reste géré par l'écran Stripe Connect.
class PayoutAccountSheet extends StatefulWidget {
  const PayoutAccountSheet({super.key});

  /// Renvoie true si le compte a été enregistré ou supprimé.
  static Future<bool?> show() {
    return Get.bottomSheet<bool>(
      const PayoutAccountSheet(),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<PayoutAccountSheet> createState() => _PayoutAccountSheetState();
}

class _PayoutAccountSheetState extends State<PayoutAccountSheet> {
  WalletController get _wallet => Get.find<WalletController>();

  final _holderController = TextEditingController();
  String? _provider;
  String? _phone;
  bool _valid = false;

  Map<String, dynamic>? get _existing => _wallet.payoutAccount.value;

  @override
  void initState() {
    super.initState();
    _holderController.text = _existing?['account_holder']?.toString() ?? '';
  }

  @override
  void dispose() {
    _holderController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _provider == null || _phone == null) {
      Get.snackbar(
        'Numéro incomplet',
        'Choisissez votre opérateur et saisissez un numéro valide.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
      return;
    }

    final error = await _wallet.savePayoutAccount(
      provider: _provider!,
      phoneNumber: _phone!,
      accountHolder: _holderController.text.trim(),
    );
    if (!mounted) return;

    if (error != null) {
      Get.snackbar('Erreur', error,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.errorColor,
          colorText: Colors.white);
      return;
    }

    Get.back(result: true);
    Get.snackbar(
      'Compte enregistré',
      'Vos prochains retraits seront pré-remplis avec ce numéro.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.successColor,
      colorText: Colors.white,
    );
  }

  Future<void> _delete() async {
    final ok = await _wallet.deletePayoutAccount();
    if (!mounted) return;
    Get.back(result: ok);
    if (ok) {
      Get.snackbar('Compte supprimé', 'Vos coordonnées de retrait ont été effacées.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = _existing;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: AppThemeSystem.getBackgroundColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.kpayColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.phone_android_rounded, color: AppThemeSystem.kpayColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compte de retrait Mobile Money',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppThemeSystem.getPrimaryTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Là où vous recevez l'argent de votre Wallet ASSO.",
                          style: TextStyle(
                            fontSize: 13,
                            color: AppThemeSystem.getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              KpayPhoneSelector(
                initialProviderCode: existing?['provider']?.toString(),
                initialPhone: existing?['phone_number']?.toString(),
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
              const SizedBox(height: 16),
              TextField(
                controller: _holderController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nom du titulaire (facultatif)',
                  helperText: 'Tel qu\'enregistré chez votre opérateur',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              Obx(() {
                final saving = _wallet.isSavingPayoutAccount.value;
                return SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(existing == null ? 'Enregistrer ce compte' : 'Mettre à jour'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                );
              }),
              if (existing != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded, color: AppThemeSystem.errorColor),
                    label: Text(
                      'Supprimer ce compte',
                      style: TextStyle(color: AppThemeSystem.errorColor),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
