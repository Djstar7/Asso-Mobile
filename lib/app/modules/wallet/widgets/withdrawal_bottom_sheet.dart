import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/controllers/app_config_controller.dart';
import '../../../routes/app_pages.dart';
import '../controllers/wallet_controller.dart';

/// Bottom sheet pour initier un retrait depuis FreeMoPay ou PayPal
class WithdrawalBottomSheet extends StatefulWidget {
  final String provider; // 'freemopay' ou 'paypal'
  final double availableBalance;

  const WithdrawalBottomSheet({
    super.key,
    required this.provider,
    required this.availableBalance,
  });

  /// Affiche le bottom sheet et retourne true si le retrait a été initié avec succès
  static Future<bool?> show({
    required String provider,
    required double availableBalance,
  }) {
    return Get.bottomSheet<bool>(
      WithdrawalBottomSheet(
        provider: provider,
        availableBalance: availableBalance,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  State<WithdrawalBottomSheet> createState() => _WithdrawalBottomSheetState();
}

class _WithdrawalBottomSheetState extends State<WithdrawalBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedPaymentMethod; // 'om' ou 'momo' pour freemopay
  bool _isProcessing = false;

  WalletController get walletController => Get.find<WalletController>();
  AppConfigController get appConfig => Get.find<AppConfigController>();

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get isFreeMoPay => widget.provider == 'freemopay';
  bool get isPayPal => widget.provider == 'paypal';

  String get title => isFreeMoPay ? 'Retrait Mobile Money' : 'Retrait PayPal';
  String get providerLabel => isFreeMoPay ? 'FreeMoPay' : 'PayPal';

  double get minAmount => appConfig.minWithdrawalAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppThemeSystem.getBackgroundColor(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.getPrimaryTextColor(context),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Solde disponible
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppThemeSystem.primaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Solde $providerLabel',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppThemeSystem.getSecondaryTextColor(context),
                        ),
                      ),
                      Text(
                        '${widget.availableBalance.toStringAsFixed(0)} FCFA',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppThemeSystem.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Montant
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: AppThemeSystem.getPrimaryTextColor(context),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Montant à retirer (FCFA)',
                    hintText: 'Ex: ${minAmount.toStringAsFixed(0)}',
                    prefixIcon: const Icon(Icons.attach_money),
                    filled: true,
                    fillColor: AppThemeSystem.getSurfaceColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppThemeSystem.getBorderColor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppThemeSystem.getBorderColor(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppThemeSystem.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un montant';
                    }
                    final amount = double.tryParse(value);
                    print('Validating amount: $minAmount, available: ${widget.availableBalance}, entered: $amount');
                    if (amount == null || amount < minAmount) {
                      return 'Le montant minimum est de ${minAmount.toStringAsFixed(0)} FCFA';
                    }
                    if (amount > widget.availableBalance) {
                      return 'Solde insuffisant';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Champs spécifiques à FreeMoPay
                if (isFreeMoPay) ...[
                  // Méthode de paiement
                  Text(
                    'Méthode de retrait',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppThemeSystem.getPrimaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPaymentMethodOption(
                          label: 'Orange Money',
                          value: 'om',
                          selected: _selectedPaymentMethod == 'om',
                          onTap: () => setState(() => _selectedPaymentMethod = 'om'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPaymentMethodOption(
                          label: 'MTN MoMo',
                          value: 'momo',
                          selected: _selectedPaymentMethod == 'momo',
                          onTap: () => setState(() => _selectedPaymentMethod = 'momo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Numéro de téléphone
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(
                      color: AppThemeSystem.getPrimaryTextColor(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Numéro de téléphone',
                      hintText: '651826475 ou 237651826475',
                      prefixIcon: const Icon(Icons.phone),
                      filled: true,
                      fillColor: AppThemeSystem.getSurfaceColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppThemeSystem.getBorderColor(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppThemeSystem.getBorderColor(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppThemeSystem.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre numéro de téléphone';
                      }
                      // Validation basique du format
                      final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');
                      if (cleaned.length != 9 && cleaned.length != 12) {
                        return 'Format invalide (9 ou 12 chiffres)';
                      }
                      return null;
                    },
                  ),
                ],

                // Champs spécifiques à PayPal
                if (isPayPal) ...[
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(
                      color: AppThemeSystem.getPrimaryTextColor(context),
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email PayPal',
                      hintText: 'votre.email@exemple.com',
                      prefixIcon: const Icon(Icons.email),
                      filled: true,
                      fillColor: AppThemeSystem.getSurfaceColor(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppThemeSystem.getBorderColor(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppThemeSystem.getBorderColor(context),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppThemeSystem.primaryColor,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre email PayPal';
                      }
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 16),

                // Notes (optionnel)
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  style: TextStyle(
                    color: AppThemeSystem.getPrimaryTextColor(context),
                  ),
                  decoration: InputDecoration(
                    labelText: 'Notes (optionnel)',
                    hintText: 'Ajouter une note pour ce retrait...',
                    prefixIcon: const Icon(Icons.note_outlined),
                    filled: true,
                    fillColor: AppThemeSystem.getSurfaceColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppThemeSystem.getBorderColor(context),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppThemeSystem.getBorderColor(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppThemeSystem.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Bouton de confirmation
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handleWithdrawal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                      foregroundColor: AppThemeSystem.whiteColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: AppThemeSystem.whiteColor,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Confirmer le retrait',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // Info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppThemeSystem.infoColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppThemeSystem.infoColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isFreeMoPay
                              ? 'Le retrait sera traité dans les 24-48h ouvrables.'
                              : 'Le retrait PayPal sera traité dans les 3-5 jours ouvrables.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppThemeSystem.getSecondaryTextColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppThemeSystem.primaryColor.withOpacity(0.1)
              : AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppThemeSystem.primaryColor
                : AppThemeSystem.getBorderColor(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected)
              const Icon(
                Icons.check_circle,
                color: AppThemeSystem.primaryColor,
                size: 18,
              ),
            if (selected) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected
                    ? AppThemeSystem.primaryColor
                    : AppThemeSystem.getPrimaryTextColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWithdrawal() async {
    // Validation supplémentaire pour FreeMoPay
    if (isFreeMoPay && _selectedPaymentMethod == null) {
      Get.snackbar(
        'Erreur',
        'Veuillez sélectionner une méthode de retrait',
        backgroundColor: AppThemeSystem.errorColor,
        colorText: AppThemeSystem.whiteColor,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final amount = double.parse(_amountController.text);
      Map<String, dynamic> result;

      if (isFreeMoPay) {
        result = await walletController.initiateWithdrawal(
          provider: 'freemopay',
          amount: amount,
          paymentMethod: _selectedPaymentMethod!,
          phoneNumber: _phoneController.text.trim(),
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );
      } else {
        result = await walletController.initiateWithdrawal(
          provider: 'paypal',
          amount: amount,
          paypalEmail: _emailController.text.trim(),
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );
      }

      if (!mounted) return;

      if (result['success'] == true) {
        // Fermer le bottom sheet
        Get.back(result: true);

        // Afficher un message de succès
        Get.snackbar(
          'Succès',
          result['message'] ?? 'Retrait initié avec succès',
          backgroundColor: AppThemeSystem.successColor,
          colorText: AppThemeSystem.whiteColor,
          duration: const Duration(seconds: 3),
        );

        // Rafraîchir le wallet et naviguer vers l'historique
        await walletController.refresh();

        // Naviguer vers l'historique pour voir le retrait en pending
        Get.toNamed(Routes.WALLET_HISTORY);
      } else {
        Get.snackbar(
          'Erreur',
          result['message'] ?? 'Échec du retrait',
          backgroundColor: AppThemeSystem.errorColor,
          colorText: AppThemeSystem.whiteColor,
        );
      }
    } catch (e) {
      print('[WithdrawalBottomSheet] Error: $e');
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue',
        backgroundColor: AppThemeSystem.errorColor,
        colorText: AppThemeSystem.whiteColor,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
