import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/models/parcel_nature.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/diaspo_service.dart';

/// État du formulaire « nature + valeur déclarée » d'un colis Diaspo, partagé
/// par la réservation avion et l'envoi maritime. Le supplément d'assurance est
/// toujours calculé par le serveur (même formule qu'à l'encaissement).
class ParcelInsuranceForm {
  ParcelInsuranceForm({required this.currency}) {
    valueController.addListener(_onValueChanged);
  }

  /// Devise de l'offre ou du départ (celle du montant encaissé).
  final String Function() currency;

  /// Devise de saisie de la valeur : celle de l'utilisateur. Le serveur la
  /// convertit dans la devise de l'offre avant de calculer l'assurance.
  String get valueCurrency => Get.isRegistered<CurrencyService>()
      ? CurrencyService.to.displayCurrencyCode
      : CurrencyService.pivot;

  String get valueCurrencySymbol => CurrencyService.getSymbolForCode(valueCurrency);

  final DiaspoService _service = Get.find<DiaspoService>();

  final natures = <ParcelNature>[].obs;
  final selectedNature = Rx<ParcelNature?>(null);
  final valueController = TextEditingController();
  final declaredValue = 0.0.obs;
  final insuranceAmount = 0.0.obs;
  final quoteAvailable = false.obs;
  final isQuoting = false.obs;
  final airMaxKgHint = 23.0.obs;

  Timer? _debounce;
  int _quoteSeq = 0;

  bool get isComplete =>
      selectedNature.value != null && valueController.text.trim().isNotEmpty;

  Future<void> load() async {
    try {
      final result = await _service.getParcelNatures();
      natures.assignAll(result.natures);
      airMaxKgHint.value = result.airMaxKgHint;
    } catch (_) {
      // Liste indisponible : le formulaire reste vide, l'envoi sera refusé.
    }
  }

  void selectNature(ParcelNature? nature) {
    _quoteSeq++;
    quoteAvailable.value = false;
    isQuoting.value = false;
    selectedNature.value = nature;
    _requestQuote();
  }

  void _onValueChanged() {
    _quoteSeq++;
    isQuoting.value = false;
    declaredValue.value =
        double.tryParse(valueController.text.replaceAll(',', '.')) ?? 0;
    quoteAvailable.value = false;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _requestQuote);
  }

  Future<void> _requestQuote() async {
    final nature = selectedNature.value;
    if (nature == null || valueController.text.trim().isEmpty) {
      insuranceAmount.value = 0;
      quoteAvailable.value = false;
      return;
    }
    final seq = ++_quoteSeq;
    isQuoting.value = true;
    try {
      final amount = await _service.insuranceQuote(
        natureId: nature.id,
        declaredValue: declaredValue.value,
        declaredValueCurrency: valueCurrency,
        currency: currency(),
      );
      if (seq == _quoteSeq) {
        insuranceAmount.value = amount;
        quoteAvailable.value = true;
      }
    } catch (_) {
      if (seq == _quoteSeq) {
        insuranceAmount.value = 0;
        quoteAvailable.value = false;
      }
    } finally {
      if (seq == _quoteSeq) isQuoting.value = false;
    }
  }

  void dispose() {
    _debounce?.cancel();
    valueController.dispose();
  }
}
/// Carte « Nature et valeur du colis » avec le supplément d'assurance.
class ParcelInsuranceCard extends StatelessWidget {
  const ParcelInsuranceCard({
    super.key,
    required this.form,
    required this.formatAmount,
    required this.decoration,
    this.introKey = 'parcel_insurance.intro',
    this.showQuote = true,
    this.natureError,
    this.valueError,
    this.natureKey,
    this.valueKey,
  });

  final ParcelInsuranceForm form;

  /// Formate un montant exprimé dans la devise de l'offre.
  final String Function(double) formatAmount;
  final BoxDecoration decoration;
  final String introKey;
  final bool showQuote;

  /// Message d'erreur affiché sous le sélecteur de nature.
  final String? natureError;

  /// Message d'erreur affiché sous le champ valeur déclarée.
  final String? valueError;

  /// Clés utilisées par Scrollable.ensureVisible pour le scroll automatique.
  final Key? natureKey;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final muted = isDark ? Colors.white70 : AppDesign.neutral500;
    final fill = isDark ? Colors.white.withValues(alpha: 0.04) : AppDesign.neutral50;

    InputDecoration deco(String label, {String? suffix, String? error}) => InputDecoration(
          labelText: label,
          suffixText: suffix,
          errorText: error,
          errorMaxLines: 2,
          filled: true,
          fillColor: fill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppDesign.danger, width: 1.2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppDesign.danger, width: 1.5),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 20, color: AppThemeSystem.primaryColor),
              const SizedBox(width: 8),
              Text(
                'parcel_insurance.title'.tr,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            introKey.tr,
            style: TextStyle(fontSize: 12, color: muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: natureKey,
            child: Obx(
              () => DropdownButtonFormField<int>(
                value: form.selectedNature.value?.id,
                isExpanded: true,
                decoration: deco('parcel_insurance.nature'.tr, error: natureError),
                items: form.natures
                    .map((n) => DropdownMenuItem(value: n.id, child: Text(n.name)))
                    .toList(),
                onChanged: (id) => form.selectNature(
                  form.natures.firstWhereOrNull((n) => n.id == id),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: valueKey,
            child: TextField(
              controller: form.valueController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+[.,]?\d{0,2}')),
              ],
              decoration: deco(
                'parcel_insurance.value'.tr,
                suffix: form.valueCurrencySymbol,
                error: valueError,
              ),
            ),
          ),
          if (showQuote) ...[
            const SizedBox(height: 12),
            Obx(
              () => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('parcel_insurance.supplement'.tr, style: TextStyle(color: muted)),
                  form.isQuoting.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          formatAmount(form.insuranceAmount.value),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}