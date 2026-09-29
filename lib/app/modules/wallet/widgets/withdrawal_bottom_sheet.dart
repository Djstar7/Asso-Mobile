import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/controllers/app_config_controller.dart';
import '../../../routes/app_pages.dart';
import '../../../data/providers/api_provider.dart';
import '../controllers/wallet_controller.dart';
import 'kpay_phone_selector.dart';
import '../../../core/widgets/app_sheet.dart';

/// Bottom sheet pour initier un retrait Mobile Money (KPay)
class WithdrawalBottomSheet extends StatefulWidget {
  final String provider; // 'kpay'
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
    return AppSheet.show<bool>(
      WithdrawalBottomSheet(
        provider: provider,
        availableBalance: availableBalance,
      ),
    );
  }

  @override
  State<WithdrawalBottomSheet> createState() => _WithdrawalBottomSheetState();
}

class _WithdrawalBottomSheetState extends State<WithdrawalBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  // Sélection KPay (renseignée par KpayPhoneSelector)
  String? _kpayProvider; // code opérateur (ex. MTN_MOMO_CMR)
  String? _kpayPhone; // numéro international sans '+'
  String _kpayCurrency = 'XAF'; // devise de l'opérateur sélectionné
  bool _kpayValid = false;
  bool _isProcessing = false;

  // Mémoriser le numéro saisi comme compte de retrait (proposé si différent de l'enregistré).
  bool _rememberAccount = true;

  Map<String, dynamic>? get _savedAccount => walletController.payoutAccount.value;

  bool get _differsFromSaved =>
      _savedAccount == null ||
      _savedAccount!['provider'] != _kpayProvider ||
      _savedAccount!['phone_number'] != _kpayPhone;

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
    _notesController.dispose();
    super.dispose();
  }

  bool get isKpay => widget.provider == 'kpay';

  String get title => 'wallet.withdrawal.title'.tr;
  String get providerLabel => 'Mobile Money';

  double get minAmount => appConfig.minWithdrawalAmount;

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: title,
      color: AppThemeSystem.getBackgroundColor(context),
      // Bouton épinglé au-dessus du clavier : sous les champs, il passait
      // dessous dès qu'on saisissait le montant.
      footer: SizedBox(
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
              : Text(
                  'wallet.withdrawal.confirm'.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    'wallet.withdrawal.balance_of'.trParams({'label': isKpay ? _kpayCurrency : providerLabel}),
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
                    ? 'wallet.withdrawal.amount_label'.trParams({'currency': _currencyLabel(_kpayCurrency)})
                    : 'wallet.withdrawal.amount_label'.trParams({'currency': 'FCFA'}),
                hintText: 'wallet.withdrawal.amount_hint'.trParams({'amount': minAmount.toStringAsFixed(0)}),
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
                  return 'wallet.recharge.amount_required'.tr;
                }
                final amount = double.tryParse(value);
                if (amount == null || amount < minAmount) {
                  return 'wallet.withdrawal.min_amount'.trParams({'amount': minAmount.toStringAsFixed(0)});
                }
                if (amount > _availableBalance) {
                  return 'wallet.stripe_dialog.insufficient_balance'.tr;
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Champs spécifiques à KPay
            if (isKpay) ...[
              // Pré-rempli avec le compte de retrait enregistré (s'il existe).
              KpayPhoneSelector(
                initialProviderCode: _savedAccount?['provider']?.toString(),
                initialPhone: _savedAccount?['phone_number']?.toString(),
                onChanged: ({
                  required String? providerCode,
                  required String? phoneNumber,
                  required String currency,
                  required bool isValid,
                }) {
                  final wasDifferent = _differsFromSaved;
                  _kpayProvider = providerCode;
                  _kpayPhone = phoneNumber;
                  _kpayValid = isValid;
                  if (wasDifferent != _differsFromSaved && mounted) setState(() {});
                  // Rafraîchir le solde + convertir le montant saisi si la devise change
                  if (currency != _kpayCurrency) {
                    final old = _kpayCurrency;
                    _kpayCurrency = currency;
                    if (mounted) setState(() {});
                    _convertFieldToCurrency(old, currency);
                  }
                },
              ),
              if (_kpayValid && _differsFromSaved)
                CheckboxListTile(
                  value: _rememberAccount,
                  onChanged: (v) => setState(() => _rememberAccount = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: Text(
                    _savedAccount == null
                        ? 'wallet.withdrawal.remember_number'.tr
                        : 'wallet.withdrawal.replace_account'.tr,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppThemeSystem.getPrimaryTextColor(context),
                    ),
                  ),
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
                labelText: 'wallet.withdrawal.notes_label'.tr,
                hintText: 'wallet.withdrawal.notes_hint'.tr,
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
                      'wallet.withdrawal.processing_delay'.tr,
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
    );
  }

  Future<void> _handleWithdrawal() async {
    // Validation supplémentaire pour KPay (opérateur + numéro valides)
    if (isKpay && (!_kpayValid || _kpayProvider == null || _kpayPhone == null)) {
      Get.snackbar(
        'wallet.recharge.error'.tr,
        'wallet.recharge.fields_required_message'.tr,
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

      final result = await walletController.initiateWithdrawal(
        provider: 'kpay',
        amount: amount,
        kpayProvider: _kpayProvider,
        phoneNumber: _kpayPhone,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Mémorisation du compte de retrait (non bloquante).
        if (isKpay && _rememberAccount && _differsFromSaved) {
          walletController.savePayoutAccount(
            provider: _kpayProvider!,
            phoneNumber: _kpayPhone!,
          );
        }

        // Suivi du statut en arrière-plan (polling 5 s + notification) pour tous les
        // rails : le retrait ne passe 'completed' qu'une fois le versement réellement
        // réglé (KPay, PayPal Payouts, Stripe payout).
        final wId = result['data']?['withdrawal_id'];
        if (wId is int) {
          walletController.trackWithdrawalInBackground(wId);
        }

        // Fermer le bottom sheet
        Get.back(result: true);

        // Afficher un message de succès
        Get.snackbar(
          'wallet.webview.success_title'.tr,
          result['message'] ?? 'wallet.messages.withdrawal_initiated'.tr,
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
          'wallet.recharge.error'.tr,
          result['message'] ?? 'wallet.withdrawal.failed'.tr,
          backgroundColor: AppThemeSystem.errorColor,
          colorText: AppThemeSystem.whiteColor,
        );
      }
    } catch (e) {
      print('[WithdrawalBottomSheet] Error: $e');
      Get.snackbar(
        'wallet.recharge.error'.tr,
        'wallet.recharge.generic_error'.tr,
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
