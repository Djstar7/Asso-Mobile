import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/controllers/app_config_controller.dart';
import '../../../routes/app_pages.dart';
import '../../../data/providers/api_provider.dart';
import '../controllers/wallet_controller.dart';
import 'kpay_phone_selector.dart';

/// Bottom sheet pour initier un retrait depuis KPay ou PayPal
class WithdrawalBottomSheet extends StatefulWidget {
  final String provider; // 'kpay' ou 'paypal'
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
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  // Sélection KPay (renseignée par KpayPhoneSelector)
  String? _kpayProvider; // code opérateur (ex. MTN_MOMO_CMR)
  String? _kpayPhone; // numéro international sans '+'
  String _kpayCurrency = 'XAF'; // devise de l'opérateur sélectionné
  bool _kpayValid = false;
  bool _isProcessing = false;

  /// Solde disponible pour le retrait : devise de l'opérateur (KPay) ou PayPal.
  double get _availableBalance => isKpay
      ? walletController.kpayAvailableFor(_kpayCurrency)
      : widget.availableBalance;

  /// Libellé de devise affiché (FCFA pour XAF/XOF, sinon le code ISO).
  String _currencyLabel(String c) =>
      (c == 'XAF' || c == 'XOF') ? '$c (FCFA)' : c;

  /// Convertit le montant déjà saisi lorsqu'on change de devise d'opérateur.
  Future<void> _convertFieldToCurrency(String from, String to) async {
    final amount = double.tryParse(_amountController.text.trim());
    if (from == to || amount == null || amount <= 0) return;
    final response = await ApiProvider.get('/v1/currencies/convert', queryParams: {
      'from': from,
      'to': to,
      'amount': amount,
    });
    if (!mounted) return;
    if (response.success && response.data?['data'] != null) {
      _amountController.text = response.data!['data']['converted'].toString();
    }
  }

  WalletController get walletController => Get.find<WalletController>();
  AppConfigController get appConfig => Get.find<AppConfigController>();

  @override
  void dispose() {
    _amountController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get isKpay => widget.provider == 'kpay';
  bool get isPayPal => widget.provider == 'paypal';

  String get title => isKpay ? 'Retrait Mobile Money' : 'Retrait PayPal';
  String get providerLabel => isKpay ? 'KPay' : 'PayPal';

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
                        isKpay ? 'Solde $_kpayCurrency' : 'Solde $providerLabel',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppThemeSystem.getSecondaryTextColor(context),
                        ),
                      ),
                      Text(
                        '${_availableBalance.toStringAsFixed(0)} ${isKpay ? _kpayCurrency : "FCFA"}',
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
                    labelText: isKpay
                        ? 'Montant à retirer (${_currencyLabel(_kpayCurrency)})'
                        : 'Montant à retirer (FCFA)',
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
                    if (amount == null || amount < minAmount) {
                      return 'Le montant minimum est de ${minAmount.toStringAsFixed(0)} FCFA';
                    }
                    if (amount > _availableBalance) {
                      return 'Solde insuffisant';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Champs spécifiques à KPay
                if (isKpay) ...[
                  KpayPhoneSelector(
                    onChanged: ({
                      required String? providerCode,
                      required String? phoneNumber,
                      required String currency,
                      required bool isValid,
                    }) {
                      _kpayProvider = providerCode;
                      _kpayPhone = phoneNumber;
                      _kpayValid = isValid;
                      // Rafraîchir le solde + convertir le montant saisi si la devise change
                      if (currency != _kpayCurrency) {
                        final old = _kpayCurrency;
                        _kpayCurrency = currency;
                        if (mounted) setState(() {});
                        _convertFieldToCurrency(old, currency);
                      }
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
                          isKpay
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

  Future<void> _handleWithdrawal() async {
    // Validation supplémentaire pour KPay (opérateur + numéro valides)
    if (isKpay && (!_kpayValid || _kpayProvider == null || _kpayPhone == null)) {
      Get.snackbar(
        'Erreur',
        'Sélectionnez votre opérateur et saisissez un numéro valide.',
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

      if (isKpay) {
        result = await walletController.initiateWithdrawal(
          provider: 'kpay',
          amount: amount,
          kpayProvider: _kpayProvider,
          phoneNumber: _kpayPhone,
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
        // Suivi du statut en arrière-plan (polling 5 s + notification) pour KPay
        if (isKpay) {
          final wId = result['data']?['withdrawal_id'];
          if (wId is int) {
            walletController.trackWithdrawalInBackground(wId);
          }
        }

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
