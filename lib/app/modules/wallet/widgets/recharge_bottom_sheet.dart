import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/controllers/app_config_controller.dart';
import '../../../routes/app_pages.dart';
import '../../../data/providers/api_provider.dart';
import '../controllers/wallet_controller.dart';
import '../../../data/services/stripe_native_service.dart';
import '../../payment/widgets/mobile_money_waiting.dart';
import 'kpay_phone_selector.dart';
import '../../../core/widgets/app_sheet.dart';

/// Bottom sheet pour recharger le wallet en 2 étapes
/// Step 1: Choix de la méthode de paiement
/// Step 2: Formulaire de paiement correspondant
class RechargeBottomSheet extends StatefulWidget {
  const RechargeBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    // `AppSheet.show` place la feuille au-dessus du clavier et l'arrête sous
    // la barre d'état ; elle ne recouvre plus tout l'écran.
    return AppSheet.show<void>(const RechargeBottomSheet());
  }

  @override
  State<RechargeBottomSheet> createState() => _RechargeBottomSheetState();
}

class _RechargeBottomSheetState extends State<RechargeBottomSheet> {
  int _currentStep = 1; // 1 = choix méthode, 2 = formulaire
  String? _selectedMethod; // 'kpay', 'card', 'crypto'

  // Sélection KPay (renseignée par KpayPhoneSelector)
  String? _kpayProvider; // code opérateur (ex. MTN_MOMO_CMR)
  String? _kpayPhone; // numéro international sans '+'
  String _kpayCurrency = 'XAF'; // devise de l'opérateur sélectionné
  bool _kpayValid = false;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  bool _isProcessing = false;

  WalletController get walletController => Get.find<WalletController>();
  AppConfigController get appConfig => Get.find<AppConfigController>();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Libellé de devise affiché (FCFA pour XAF/XOF, sinon le code ISO).
  /// Nom court de la devise, tel qu'on l'écrit sur un montant.
  ///
  /// Le franc CFA s'écrit « FCFA » à l'usage ; afficher « XAF (FCFA) » dans
  /// un libellé donnait « Montant (XAF (FCFA)) », avec deux parenthèses
  /// imbriquées.
  String _currencyLabel(String c) =>
      (c == 'XAF' || c == 'XOF') ? 'FCFA' : c;

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
      final converted = response.data!['data']['converted'];
      _amountController.text = converted.toString();
    }
  }

  void _backToMethodChoice() => setState(() {
        _currentStep = 1;
        _selectedMethod = null;
      });

  @override
  Widget build(BuildContext context) {
    // Clavier ouvert, la barre d'étapes cède sa place au champ en cours de
    // saisie : sur un petit téléphone, elle repoussait le montant sous le
    // clavier. Le titre et la flèche disent déjà où l'on en est.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    // Le retour système suit la flèche : à l'étape 2, il ramène au choix de
    // la méthode au lieu de refermer la feuille et de perdre la saisie.
    return PopScope(
      canPop: _currentStep == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToMethodChoice();
      },
      child: _buildSheet(context, keyboardOpen),
    );
  }

  Widget _buildSheet(BuildContext context, bool keyboardOpen) {
    return AppSheet(
      title: _currentStep == 1
          ? 'wallet.recharge.title'.tr
          : 'wallet.recharge.amount_title'.tr,
      // La flèche ramène au choix de la méthode, la croix referme la feuille.
      onBack: _currentStep == 2 ? _backToMethodChoice : null,
      // `pop` et non `maybePop` : la garde ci-dessus renverrait la croix à
      // l'étape 1 au lieu de refermer.
      onClose: () => Navigator.of(context).pop(),
      color: AppThemeSystem.getBackgroundColor(context),
      // Bouton épinglé au-dessus du clavier : au bout du formulaire, il
      // passait dessous pendant la saisie du montant ou du numéro.
      footer: _currentStep == 2 ? _buildConfirmButton() : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!keyboardOpen) ...[
            // Barre de progression par étapes
            _buildStepProgressBar(context),

            SizedBox(height: AppThemeSystem.getSectionSpacing(context)),
          ],

          // Contenu selon l'étape
          if (_currentStep == 1) _buildStep1MethodSelection(context),
          if (_currentStep == 2) _buildStep2PaymentForm(context),
        ],
      ),
    );
  }

  /// Barre de progression par étapes
  Widget _buildStepProgressBar(BuildContext context) {
    return Row(
      children: [
        // Étape 1
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  // Cercle étape 1
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentStep >= 1
                          ? AppThemeSystem.primaryColor
                          : AppThemeSystem.grey300,
                    ),
                    child: Center(
                      child: _currentStep > 1
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppThemeSystem.whiteColor,
                              size: 18,
                            )
                          : Text(
                              '1',
                              style: TextStyle(
                                color: _currentStep >= 1
                                    ? AppThemeSystem.whiteColor
                                    : AppThemeSystem.grey600,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
                  // Ligne de connexion
                  Expanded(
                    child: Container(
                      height: 2,
                      color: _currentStep >= 2
                          ? AppThemeSystem.primaryColor
                          : AppThemeSystem.grey300,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'wallet.recharge.step_method'.tr,
                style: TextStyle(
                  fontSize: 12,
                  color: _currentStep >= 1
                      ? AppThemeSystem.getPrimaryTextColor(context)
                      : AppThemeSystem.getSecondaryTextColor(context),
                  fontWeight: _currentStep == 1
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),

        // Étape 2
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentStep >= 2
                    ? AppThemeSystem.primaryColor
                    : AppThemeSystem.grey300,
              ),
              child: Center(
                child: Text(
                  '2',
                  style: TextStyle(
                    color: _currentStep >= 2
                        ? AppThemeSystem.whiteColor
                        : AppThemeSystem.grey600,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'wallet.recharge.step_amount'.tr,
              style: TextStyle(
                fontSize: 12,
                color: _currentStep >= 2
                    ? AppThemeSystem.getPrimaryTextColor(context)
                    : AppThemeSystem.getSecondaryTextColor(context),
                fontWeight: _currentStep == 2
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Step 1: Sélection de la méthode de paiement
  Widget _buildStep1MethodSelection(BuildContext context) {
    return Column(
      children: [
        // KPay — pays + opérateur choisis à l'étape suivante
        _buildMethodOption(
          context: context,
          logoPath: 'assets/images/kpay.png',
          title: 'Mobile Money',
          subtitle: 'MTN, Orange, Moov, Airtel, M-Pesa…',
          color: const Color(0xFFFF7900),
          onTap: () => _selectMethod('kpay'),
        ),

        const SizedBox(height: 12),

        // Carte bancaire (VISA / MasterCard) via Stripe natif (Payment Sheet)
        _buildMethodOption(
          context: context,
          logoPath: 'assets/images/visa.png',
          title: 'wallet.recharge.bank_card'.tr,
          subtitle: 'VISA, MasterCard',
          color: const Color(0xFF1A1F71),
          onTap: () {
            // Carte désactivée côté plateforme : on l'explique au lieu d'échouer plus loin.
            if (!walletController.stripeConfigured.value) {
              Get.snackbar(
                'wallet.recharge.card_unavailable_title'.tr,
                'wallet.recharge.card_unavailable_message'.tr,
                backgroundColor: AppThemeSystem.warningColor,
                colorText: AppThemeSystem.whiteColor,
              );
              return;
            }
            _selectMethod('card');
          },
        ),

      ],
    );
  }

  Widget _buildMethodOption({
    required BuildContext context,
    required String logoPath,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isComingSoon = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isComingSoon
              ? AppThemeSystem.getSurfaceColor(context).withValues(alpha: 0.5)
              : AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isComingSoon
                ? AppThemeSystem.getBorderColor(context).withValues(alpha: 0.3)
                : AppThemeSystem.getBorderColor(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Logo circulaire
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: ClipOval(
                child: Image.asset(
                  logoPath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback si l'image n'existe pas
                    return Container(
                      color: color.withValues(alpha: 0.1),
                      child: Icon(Icons.payment, color: color, size: 24),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isComingSoon
                          ? AppThemeSystem.getSecondaryTextColor(context)
                          : AppThemeSystem.getPrimaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppThemeSystem.getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
            if (isComingSoon)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppThemeSystem.infoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'wallet.recharge.coming_soon'.tr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppThemeSystem.infoColor,
                  ),
                ),
              )
            else
              Icon(
                Icons.chevron_right,
                color: AppThemeSystem.getSecondaryTextColor(context),
              ),
          ],
        ),
      ),
    );
  }

  void _selectMethod(String method) {
    setState(() {
      _selectedMethod = method;
      _currentStep = 2;
    });
  }

  String _getPaymentButtonText() {
    switch (_selectedMethod) {
      case 'kpay':
        return 'wallet.recharge.confirm_recharge'.tr;
      case 'card':
        return 'wallet.recharge.pay_by_card'.tr;
      default:
        return 'wallet.recharge.confirm_payment'.tr;
    }
  }

  /// Step 2: Formulaire de paiement
  Widget _buildStep2PaymentForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Montant
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              color: AppThemeSystem.getPrimaryTextColor(context),
            ),
            decoration: InputDecoration(
              labelText: _selectedMethod == 'kpay'
                  ? 'wallet.recharge.amount_label'
                      .trParams({'currency': _currencyLabel(_kpayCurrency)})
                  : 'wallet.recharge.amount_label'.trParams({'currency': 'FCFA'}),
              // Le libellé reste au-dessus du champ, même vide : en
              // placeholder, il disparaissait à la première frappe et on ne
              // savait plus dans quelle devise on saisissait.
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: 'wallet.recharge.amount_hint'.tr,
              prefixIcon: const Icon(Icons.attach_money),
              filled: true,
              fillColor: AppThemeSystem.getSurfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppThemeSystem.getBorderColor(context),
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'wallet.recharge.amount_required'.tr;
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'wallet.recharge.amount_invalid'.tr;
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Champs spécifiques selon la méthode
          if (_selectedMethod == 'kpay')
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
                if (currency != _kpayCurrency) {
                  final old = _kpayCurrency;
                  _kpayCurrency = currency;
                  if (mounted) setState(() {}); // met à jour le libellé de devise
                  _convertFieldToCurrency(old, currency); // convertit le montant saisi
                }
              },
            ),

          // Pour la carte bancaire, aucun champ supplémentaire : la Payment Sheet
          // Stripe native recueille les informations de carte.
        ],
      ),
    );
  }

  /// Bouton de confirmation, épinglé en pied de feuille.
  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _handleRecharge,
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
                _getPaymentButtonText(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _handleRecharge() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final amount = double.parse(_amountController.text);

      if (_selectedMethod == 'kpay') {
        // Mobile Money via KPay (pays + opérateur choisis dans le sélecteur)
        if (!_kpayValid || _kpayProvider == null || _kpayPhone == null) {
          Get.snackbar(
            'wallet.recharge.fields_required_title'.tr,
            'wallet.recharge.fields_required_message'.tr,
            backgroundColor: AppThemeSystem.errorColor,
            colorText: AppThemeSystem.whiteColor,
          );
          return;
        }

        final result = await walletController.initiateRecharge(
          amount: amount,
          paymentMethod: 'kpay',
          provider: _kpayProvider,
          phoneNumber: _kpayPhone,
        );

        if (!mounted) return;

        if (result['success'] == true) {
          final txId = result['data']?['transaction_id'];
          // Rien n'est annoncé avant la réponse de l'opérateur ; en cas de
          // refus, la feuille reste ouverte pour corriger l'opérateur.
          final outcome = txId is int
              ? await MobileMoneyWaiting.run(
                  amount: amount,
                  formatAmount: (value) =>
                      '${value.toStringAsFixed(0)} ${_currencyLabel(_kpayCurrency)}',
                  provider: _kpayProvider!,
                  phone: _kpayPhone!,
                  check: () => _depositState(txId),
                )
              : (status: 'pending', failure: null);
          if (!mounted || outcome.status == 'failed') return;

          Navigator.of(context).pop(); // fermer la feuille
          await walletController.refresh();

          if (outcome.status == 'paid') {
            Get.snackbar(
              'wallet.recharge.title'.tr,
              'wallet.messages.payment_success'.tr,
              backgroundColor: AppThemeSystem.successColor,
              colorText: AppThemeSystem.whiteColor,
            );
          } else {
            // Toujours en attente : suivi en arrière-plan (notification à la
            // réponse) et transaction visible « en attente » dans l'historique.
            if (txId is int) walletController.trackDepositInBackground(txId);
            Get.toNamed(Routes.WALLET_HISTORY);
          }
        } else {
          Get.snackbar(
            'wallet.recharge.error'.tr,
            result['message'] ?? 'wallet.recharge.failed'.tr,
            backgroundColor: AppThemeSystem.errorColor,
            colorText: AppThemeSystem.whiteColor,
          );
        }
      } else {
        // Carte bancaire — recharge via Stripe natif (Payment Sheet).
        if (!StripeNativeService.isSupported) {
          Get.snackbar(
            'wallet.recharge.unavailable_title'.tr,
            'wallet.recharge.card_mobile_only'.tr,
            backgroundColor: AppThemeSystem.warningColor,
            colorText: AppThemeSystem.whiteColor,
          );
          return;
        }

        // Créer l'intention de recharge carte (montant en XAF).
        final result = await walletController.initiateRecharge(
          amount: amount,
          paymentMethod: 'stripe',
        );

        if (!mounted) return;

        if (result['success'] != true) {
          Get.snackbar(
            'wallet.recharge.error'.tr,
            result['message'] ?? 'wallet.recharge.failed'.tr,
            backgroundColor: AppThemeSystem.errorColor,
            colorText: AppThemeSystem.whiteColor,
          );
          return;
        }

        final data = result['data'] as Map<String, dynamic>?;
        final txId = data?['transaction_id'];
        final clientSecret = data?['client_secret']?.toString();
        final publishableKey = data?['publishable_key']?.toString();

        if (txId == null ||
            clientSecret == null || clientSecret.isEmpty ||
            publishableKey == null || publishableKey.isEmpty) {
          Get.snackbar(
            'wallet.recharge.error'.tr,
            'wallet.recharge.card_data_unavailable'.tr,
            backgroundColor: AppThemeSystem.errorColor,
            colorText: AppThemeSystem.whiteColor,
          );
          return;
        }

        // Présenter la Payment Sheet native.
        final ok = await StripeNativeService().payWithCard(
          publishableKey: publishableKey,
          clientSecret: clientSecret,
        );

        if (!mounted) return;

        if (!ok) {
          Get.snackbar(
            'wallet.recharge.cancelled_title'.tr,
            'wallet.recharge.card_cancelled'.tr,
            backgroundColor: AppThemeSystem.warningColor,
            colorText: AppThemeSystem.whiteColor,
          );
          return;
        }

        // Suivre le crédit du solde XAF en arrière-plan (polling + notification).
        if (txId is int) {
          walletController.trackDepositInBackground(txId);
        }

        // Fermer le bottom sheet et informer.
        Navigator.of(context).pop();
        Get.snackbar(
          'wallet.recharge.pending_title'.tr,
          'wallet.recharge.pending_message'.tr,
          backgroundColor: AppThemeSystem.successColor,
          colorText: AppThemeSystem.whiteColor,
          duration: const Duration(seconds: 5),
        );

        await walletController.refresh();
        Get.toNamed(Routes.WALLET_HISTORY);
      }
    } catch (e) {
      print('[RechargeBottomSheet] Error: $e');
      // Message réel de Stripe quand il y en a un (comme les autres paiements carte).
      final message = e is Exception
          ? e.toString().replaceAll('Exception: ', '')
          : 'wallet.recharge.generic_error'.tr;
      Get.snackbar(
        'wallet.recharge.error'.tr,
        message,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: AppThemeSystem.whiteColor,
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// État d'une recharge Mobile Money relu sur le serveur (une lecture).
  Future<MobileMoneyStatus> _depositState(int txId) async {
    final result = await walletController.checkPaymentStatus(txId);
    final status = result['status']?.toString();
    return switch (status) {
      'completed' => (status: 'paid', failure: null),
      'failed' || 'cancelled' => (
        status: 'failed',
        failure: result['payment_failure']?.toString(),
      ),
      _ => (status: 'pending', failure: null),
    };
  }
}
