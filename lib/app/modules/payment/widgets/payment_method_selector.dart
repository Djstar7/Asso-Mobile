import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/models/payment_method_option.dart';
import '../../../data/providers/payment_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../routes/app_pages.dart';

/// Sélecteur de moyen de paiement RÉUTILISABLE (réservation Diaspo, achat…).
///
/// Comportement produit :
///  - Affiche TOUS les moyens renvoyés par le backend, jamais masqués selon le pays.
///  - Un moyen dont le montant est trop faible (ou désactivé) est GRISÉ, non masqué.
///  - Avec [includeWallet], propose en tête le paiement par solde « Wallet ASSO »
///    (grisé si le solde est insuffisant, avec un raccourci pour recharger).
///  - Sous chaque moyen, le montant est recalculé dans la devise du rail
///    (via les taux de change stockés côté serveur).
///
/// Renvoie le [PaymentMethodOption] choisi, ou null si annulé.
class PaymentMethodSelector extends StatefulWidget {
  final double amount;
  final String currency;
  final String? amountLabel;
  final String? title;

  /// Options pré-construites. Si fourni, le widget les affiche telles quelles au
  /// lieu d'interroger `/v1/payments/methods` — permet de réutiliser EXACTEMENT ce
  /// sélecteur pour le RETRAIT (rails KPay / PayPal / IBAN) à partir des soldes.
  final List<PaymentMethodOption>? options;

  /// Limite l'affichage aux rails acceptés par le parcours appelant
  /// (ex. commandes produit : Mobile Money et carte). null = tous.
  final Set<String>? allowedCodes;

  /// Propose le paiement par solde Wallet ASSO (parcours acceptés côté serveur :
  /// commandes et forfaits).
  final bool includeWallet;

  const PaymentMethodSelector({
    super.key,
    required this.amount,
    required this.currency,
    this.amountLabel,
    this.title,
    this.options,
    this.allowedCodes,
    this.includeWallet = false,
  });

  static Future<PaymentMethodOption?> show({
    required double amount,
    required String currency,
    String? amountLabel,
    String? title,
    List<PaymentMethodOption>? options,
    Set<String>? allowedCodes,
    bool includeWallet = false,
  }) {
    return AppSheet.show<PaymentMethodOption>(
      PaymentMethodSelector(
        amount: amount,
        currency: currency,
        amountLabel: amountLabel,
        title: title,
        options: options,
        allowedCodes: allowedCodes,
        includeWallet: includeWallet,
      ),
    );
  }

  @override
  State<PaymentMethodSelector> createState() => _PaymentMethodSelectorState();
}

class _PaymentMethodSelectorState extends State<PaymentMethodSelector> {
  final _loading = true.obs;
  final _error = ''.obs;
  final _methods = <PaymentMethodOption>[].obs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Mode RETRAIT : options fournies directement (aucun appel réseau).
    if (widget.options != null) {
      _methods.assignAll(widget.options!);
      if (widget.options!.isEmpty) {
        _error.value = 'payment.selector.no_method'.tr;
      }
      _loading.value = false;
      return;
    }

    _loading.value = true;
    _error.value = '';
    try {
      final methods = await PaymentService.fetchMethods(
        amount: widget.amount,
        currency: widget.currency,
        includeWallet: widget.includeWallet,
      );
      final allowed = widget.allowedCodes;
      final visible = allowed == null
          ? methods
          : methods
                .where((m) => m.isWallet || allowed.contains(m.code))
                .toList();
      _methods.assignAll(visible);
      if (visible.isEmpty) {
        _error.value = 'payment.selector.no_payment_method'.tr;
      }
    } catch (e) {
      _error.value = 'payment.selector.load_error'.tr;
    } finally {
      _loading.value = false;
    }
  }

  String _fmt(double value, String currency) {
    final rounded = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '$rounded $currency';
  }

  IconData _iconFor(String code) {
    switch (code) {
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      case 'kpay':
        return Icons.phone_android_rounded;
      case 'stripe':
        return Icons.credit_card_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Color _colorFor(String code) {
    switch (code) {
      case 'wallet':
        return AppThemeSystem.successColor;
      case 'kpay':
        return AppThemeSystem.kpayColor;
      case 'stripe':
        return AppThemeSystem.primaryColor;
      default:
        return AppThemeSystem.primaryColor;
    }
  }

  /// Tap sur un moyen indisponible : notifier la raison au lieu d'ignorer le clic.
  void _notifyUnavailable(PaymentMethodOption m, String? hint) {
    // Solde insuffisant : raccourci direct vers la recharge du Wallet.
    if (m.isWallet) {
      Get.snackbar(
        'payment.selector.wallet_insufficient'.tr,
        hint ?? 'payment.selector.recharge_hint'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
        duration: const Duration(seconds: 5),
        mainButton: TextButton(
          onPressed: () {
            Get.closeCurrentSnackbar();
            // Ferme le sélecteur par son Navigator : Get.back() ne fermait que
            // la bannière encore en train de se refermer, et le Wallet
            // s'ouvrait par-dessus le sélecteur resté ouvert. S'il est déjà
            // fermé, on ne ferme rien d'autre à sa place.
            if (mounted) Navigator.of(context).pop();
            Get.toNamed(Routes.WALLET, arguments: {'openRecharge': true});
          },
          child: Text('wallet.actions.recharge'.tr),
        ),
      );
      return;
    }
    final reason = (hint != null && hint.trim().isNotEmpty)
        ? hint
        : 'payment.selector.method_unavailable'.tr;
    Get.snackbar(
      m.label,
      reason,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      backgroundColor: AppThemeSystem.errorColor.withValues(alpha: 0.12),
      colorText: AppThemeSystem.errorColor,
      icon: Icon(Icons.info_outline_rounded, color: AppThemeSystem.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pas de marge pour le clavier ici : la route de la feuille s'en charge
    // déjà, et la compter deux fois laissait un grand vide sous la liste.
    return AppSheet(
      title: widget.title ?? 'payment.selector.title'.tr,
      color: AppThemeSystem.getBackgroundColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'payment.selector.amount_line'.trParams({
              'label': widget.amountLabel ?? 'wallet.kpay.amount_to_pay'.tr,
              'amount': _fmt(widget.amount, widget.currency),
            }),
            style: context.textStyle(
              FontSizeType.body2,
              fontWeight: FontWeight.w600,
              color: AppThemeSystem.primaryColor,
            ),
          ),
          const SizedBox(height: AppDesign.space4),
          Obx(() {
            if (_loading.value) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (_error.value.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  _error.value,
                  style: TextStyle(color: AppThemeSystem.errorColor),
                ),
              );
            }
            return Column(
              children: [
                for (final m in _methods) ...[
                  _buildOption(context, m),
                  const SizedBox(height: 12),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, PaymentMethodOption m) {
    final color = _colorFor(m.code);
    final canPay = m.available;

    // Ligne secondaire : hint explicite (ex. solde disponible en mode retrait) sinon
    // montant converti (si dispo) ou raison d'indisponibilité.
    String? hint = m.hint;
    if (hint == null && m.isWallet) {
      // Solde et manque renvoyés en XAF : affichés dans la devise de l'utilisateur.
      final balance = CurrencyService.formatFromPivot(m.balance ?? 0);
      hint = canPay
          ? 'payment.selector.balance_available'.trParams({'balance': balance})
          : 'payment.selector.balance_missing'.trParams({
              'balance': balance,
              'missing': CurrencyService.formatFromPivot(m.missingAmount ?? 0),
            });
    }
    if (hint == null) {
      if (!canPay && m.unavailableReason == 'below_min' && m.minAmount != null) {
        hint = 'payment.selector.minimum'.trParams({'amount': _fmt(m.minAmount!, m.minCurrency)});
      } else if (!canPay && m.unavailableReason == 'disabled') {
        hint = 'wallet.recharge.unavailable_title'.tr;
      } else if (canPay && m.convertedAmount != null && m.targetCurrency != null) {
        hint = '≈ ${_fmt(m.convertedAmount!, m.targetCurrency!)}';
      }
    }

    return Opacity(
      opacity: canPay ? 1.0 : 0.5,
      child: InkWell(
        // Indisponible : on ne bloque pas le tap en silence, on NOTIFIE la raison.
        //
        // Navigator et non Get.back() : avec GetX 4.7.3, Get.back() ne ferme
        // que la bannière « Solde insuffisant » / « Indisponible » si elle
        // est affichée, et le choix du moyen de paiement semblait ignoré.
        onTap: canPay
            ? () => Navigator.of(context).pop(m)
            : () => _notifyUnavailable(m, hint),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppThemeSystem.getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: canPay
                  ? color.withValues(alpha: 0.3)
                  : AppThemeSystem.getBorderColor(context),
              width: canPay ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: canPay ? color.withValues(alpha: 0.1) : AppThemeSystem.getBorderColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(m.code),
                  color: canPay ? color : AppThemeSystem.getSecondaryTextColor(context),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppThemeSystem.getPrimaryTextColor(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppThemeSystem.getSecondaryTextColor(context),
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: canPay ? color : AppThemeSystem.errorColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                canPay ? Icons.chevron_right_rounded : Icons.block,
                color: canPay ? color : AppThemeSystem.getSecondaryTextColor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
