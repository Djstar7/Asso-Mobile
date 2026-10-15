import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/providers/currency_service.dart';

/// Une ligne « ce que vous achetez » : icône, libellé, valeur.
class PackageDetailFact {
  final IconData icon;
  final String label;
  final String value;

  const PackageDetailFact(this.icon, this.label, this.value);
}

/// Récapitulatif d'un forfait, affiché avant le choix du moyen de paiement :
/// l'acheteur voit exactement ce qu'il paie, ce qu'il obtient, jusqu'à quand,
/// et ce qui change sur son compte. Commun aux forfaits stockage,
/// certification et Asso Ads.
///
/// Renvoie true quand l'acheteur continue vers le paiement.
class PackageDetailsSheet extends StatelessWidget {
  const PackageDetailsSheet({
    super.key,
    required this.typeLabel,
    required this.name,
    required this.priceXaf,
    required this.durationLabel,
    this.description,
    this.facts = const [],
    this.benefits = const [],
    this.notes = const [],
    this.salesCode,
  });

  /// Nature du forfait (Stockage, Certification, Asso Ads).
  final String typeLabel;
  final String name;

  /// Prix en FCFA (pivot), affiché dans la devise de l'utilisateur.
  final double priceXaf;
  final String durationLabel;
  final String? description;
  final List<PackageDetailFact> facts;
  final List<String> benefits;

  /// « Bon à savoir » : effet de l'achat sur le compte (cumul, échéance…).
  final List<String> notes;

  /// Code commercial validé, rappelé avant de payer.
  final String? salesCode;

  static Future<bool> show({
    required String typeLabel,
    required String name,
    required double priceXaf,
    required String durationLabel,
    String? description,
    List<PackageDetailFact> facts = const [],
    List<String> benefits = const [],
    List<String> notes = const [],
    String? salesCode,
  }) async {
    final result = await AppSheet.show<bool>(
      PackageDetailsSheet(
        typeLabel: typeLabel,
        name: name,
        priceXaf: priceXaf,
        durationLabel: durationLabel,
        description: description,
        facts: facts,
        benefits: benefits,
        notes: notes,
        salesCode: salesCode,
      ),
    );
    return result == true;
  }

  /// Date lisible dans la langue de l'utilisateur (ex. 14 nov. 2026).
  static String formatDate(DateTime date) =>
      DateFormat('d MMM y', Get.locale?.toLanguageTag()).format(date.toLocal());

  /// Avantages renvoyés par l'API (liste de textes), sans entrées vides.
  static List<String> benefitsOf(dynamic raw) => raw is List
      ? raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
      : const [];

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final hasDescription = (description ?? '').trim().isNotEmpty;

    return AppSheet(
      title: 'package_details.title'.tr,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            label: 'package_details.continue'.tr,
            icon: Icons.lock_outline_rounded,
            onPressed: () => Get.back(result: true),
          ),
          SizedBox(height: AppDesign.space2),
          AppButton(
            label: 'package_details.cancel'.tr,
            variant: AppButtonVariant.secondary,
            onPressed: () => Get.back(result: false),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            typeLabel.toUpperCase(),
            style: context.caption.copyWith(
              color: ds.textTertiary,
              fontWeight: FontWeight.w600,
              letterSpacing: .6,
            ),
          ),
          SizedBox(height: AppDesign.space1),
          Text(
            name,
            style: context.h5.copyWith(fontWeight: FontWeight.w700, color: ds.textPrimary),
          ),
          if (hasDescription) ...[
            SizedBox(height: AppDesign.space2),
            Text(
              description!.trim(),
              style: context.body2.copyWith(color: ds.textSecondary, height: 1.4),
            ),
          ],

          SizedBox(height: AppDesign.space5),

          // Montant à payer.
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppDesign.space4),
            decoration: BoxDecoration(
              color: ds.surfaceMuted,
              borderRadius: BorderRadius.circular(AppDesign.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'package_details.to_pay'.tr,
                  style: context.caption.copyWith(color: ds.textSecondary),
                ),
                SizedBox(height: AppDesign.space1),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        CurrencyService.formatFromPivot(priceXaf),
                        style: context.h4.copyWith(fontWeight: FontWeight.w700, color: ds.textPrimary),
                      ),
                    ),
                    SizedBox(width: AppDesign.space2),
                    Text(durationLabel, style: context.body2.copyWith(color: ds.textSecondary)),
                  ],
                ),
                SizedBox(height: AppDesign.space1),
                Text(
                  'package_details.one_time'.tr,
                  style: context.caption.copyWith(color: ds.textTertiary),
                ),
              ],
            ),
          ),

          if (facts.isNotEmpty) ...[
            SizedBox(height: AppDesign.space5),
            _sectionTitle(context, 'package_details.what_you_get'.tr),
            SizedBox(height: AppDesign.space3),
            for (final fact in facts) _factRow(context, fact),
          ],

          if (benefits.isNotEmpty) ...[
            SizedBox(height: AppDesign.space4),
            _sectionTitle(context, 'package_details.benefits'.tr),
            SizedBox(height: AppDesign.space3),
            for (final benefit in benefits)
              Padding(
                padding: EdgeInsets.only(bottom: AppDesign.space2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_rounded, size: 16, color: AppDesign.successText),
                    ),
                    SizedBox(width: AppDesign.space2),
                    Expanded(
                      child: Text(benefit, style: context.body2.copyWith(color: ds.textPrimary)),
                    ),
                  ],
                ),
              ),
          ],

          if (salesCode != null && salesCode!.isNotEmpty) ...[
            SizedBox(height: AppDesign.space3),
            _factRow(
              context,
              PackageDetailFact(Icons.badge_outlined, 'package_details.sales_code'.tr, salesCode!),
            ),
          ],

          if (notes.isNotEmpty) ...[
            SizedBox(height: AppDesign.space4),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppDesign.space3),
              decoration: BoxDecoration(
                color: AppDesign.infoSubtle,
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18, color: AppDesign.infoText),
                  SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < notes.length; i++) ...[
                          if (i > 0) SizedBox(height: AppDesign.space2),
                          Text(
                            notes[i],
                            style: context.body2.copyWith(color: AppDesign.infoText, height: 1.35),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: AppDesign.space2),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: context.subtitle2.copyWith(fontWeight: FontWeight.w700, color: context.ds.textPrimary),
      );

  Widget _factRow(BuildContext context, PackageDetailFact fact) {
    final ds = context.ds;
    return Padding(
      padding: EdgeInsets.only(bottom: AppDesign.space3),
      child: Row(
        children: [
          Icon(fact.icon, size: 18, color: ds.icon),
          SizedBox(width: AppDesign.space3),
          Expanded(
            child: Text(fact.label, style: context.body2.copyWith(color: ds.textSecondary)),
          ),
          SizedBox(width: AppDesign.space2),
          Flexible(
            child: Text(
              fact.value,
              textAlign: TextAlign.end,
              style: context.body2.copyWith(color: ds.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
