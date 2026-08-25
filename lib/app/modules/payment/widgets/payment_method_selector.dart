import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../data/models/payment_method_option.dart';
import '../../../data/providers/payment_service.dart';

/// Sélecteur de moyen de paiement RÉUTILISABLE (réservation Diaspo, achat…).
///
/// Comportement produit :
///  - Affiche TOUS les moyens renvoyés par le backend, jamais masqués selon le pays.
///  - Un moyen dont le montant est trop faible (ou désactivé) est GRISÉ, non masqué.
///  - N'affiche AUCUN solde de portefeuille : ce sont des rails directs.
///  - Sous chaque moyen, le montant est recalculé dans la devise du rail
///    (via les taux de change stockés côté serveur).
///
/// Renvoie le [PaymentMethodOption] choisi, ou null si annulé.
class PaymentMethodSelector extends StatefulWidget {
  final double amount;
  final String currency;
  final String amountLabel;
  final String title;

  /// Options pré-construites. Si fourni, le widget les affiche telles quelles au
  /// lieu d'interroger `/v1/payments/methods` — permet de réutiliser EXACTEMENT ce
  /// sélecteur pour le RETRAIT (rails KPay / PayPal / IBAN) à partir des soldes.
  final List<PaymentMethodOption>? options;

  const PaymentMethodSelector({
    super.key,
    required this.amount,
    required this.currency,
    this.amountLabel = 'Montant à payer',
    this.title = 'Choisir un moyen de paiement',
    this.options,
  });

  static Future<PaymentMethodOption?> show({
    required double amount,
    required String currency,
    String amountLabel = 'Montant à payer',
    String title = 'Choisir un moyen de paiement',
    List<PaymentMethodOption>? options,
  }) {
    return Get.bottomSheet<PaymentMethodOption>(
      PaymentMethodSelector(
        amount: amount,
        currency: currency,
        amountLabel: amountLabel,
        title: title,
        options: options,
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
        _error.value = 'Aucune méthode disponible pour le moment.';
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
      );
      _methods.assignAll(methods);
      if (methods.isEmpty) {
        _error.value = 'Aucun moyen de paiement disponible pour le moment.';
      }
    } catch (e) {
      _error.value = 'Impossible de charger les moyens de paiement.';
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
    final reason = (hint != null && hint.trim().isNotEmpty)
        ? hint
        : "Ce moyen n'est pas disponible pour le moment.";
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
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: AppThemeSystem.getBackgroundColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.payment, color: AppThemeSystem.primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppThemeSystem.getPrimaryTextColor(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.amountLabel}: ${_fmt(widget.amount, widget.currency)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppThemeSystem.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close),
                      color: AppThemeSystem.getSecondaryTextColor(context),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

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
          ),
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, PaymentMethodOption m) {
    final color = _colorFor(m.code);
    final canPay = m.available;

    // Ligne secondaire : hint explicite (ex. solde disponible en mode retrait) sinon
    // montant converti (si dispo) ou raison d'indisponibilité.
    String? hint = m.hint;
    if (hint == null) {
      if (!canPay && m.unavailableReason == 'below_min' && m.minAmount != null) {
        hint = 'Minimum ${_fmt(m.minAmount!, m.minCurrency)}';
      } else if (!canPay && m.unavailableReason == 'disabled') {
        hint = 'Indisponible';
      } else if (canPay && m.convertedAmount != null && m.targetCurrency != null) {
        hint = '≈ ${_fmt(m.convertedAmount!, m.targetCurrency!)}';
      }
    }

    return Opacity(
      opacity: canPay ? 1.0 : 0.5,
      child: InkWell(
        // Indisponible : on ne bloque pas le tap en silence, on NOTIFIE la raison.
        onTap: canPay ? () => Get.back(result: m) : () => _notifyUnavailable(m, hint),
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
