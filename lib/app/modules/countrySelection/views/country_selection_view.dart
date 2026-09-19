import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/currency_model.dart';
import '../controllers/country_selection_controller.dart';

/// Choix du pays, et donc de la devise d'affichage des prix.
///
/// C'est le tout premier écran après l'installation : il doit être lisible
/// et neutre. Les pastilles bleues d'origine et le bouton de confirmation
/// bleu ont été remplacés — ils contredisaient l'identité orange de la
/// marque et inversaient la hiérarchie des actions.
class CountrySelectionView extends GetView<CountrySelectionController> {
  const CountrySelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ds.canvas,
      appBar: AppBar(
        title: const Text('Choisissez votre pays'),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.ds.gutter,
                  AppDesign.space3,
                  context.ds.gutter,
                  AppDesign.space3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Les prix et les frais de livraison seront affichés dans la devise du pays choisi.',
                      style: context.textStyle(
                        FontSizeType.caption,
                        color: context.ds.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: AppDesign.space3),
                    AppTextField(
                      hint: 'Rechercher un pays ou une devise',
                      onChanged: controller.filterCountries,
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: context.ds.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value &&
                      controller.allCountries.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.filteredCountries.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun pays trouvé',
                      message: 'Essayez avec un autre nom de pays ou un code de devise.',
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.only(
                      left: context.ds.gutter,
                      right: context.ds.gutter,
                      bottom: AppDesign.space8,
                    ),
                    itemCount: controller.filteredCountries.length,
                    separatorBuilder: (_, _) => const AppDivider(),
                    itemBuilder: (context, index) {
                      final item = controller.filteredCountries[index];
                      final String country = item['country'] as String;
                      final CurrencyModel currency =
                          item['currency'] as CurrencyModel;

                      return _CountryTile(
                        country: country,
                        currency: currency,
                        onTap: () => _showConfirmationSheet(context, item),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirmation présentée en feuille plutôt qu'en boîte de dialogue :
  /// elle reste dans le pouce et laisse la liste visible derrière.
  void _showConfirmationSheet(
    BuildContext context,
    Map<String, dynamic> countryData,
  ) {
    final String country = countryData['country'] as String;
    final CurrencyModel currency = countryData['currency'] as CurrencyModel;

    Get.bottomSheet(
      SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.ds.gutter,
            AppDesign.space5,
            context.ds.gutter,
            AppDesign.space5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.ds.borderStrong,
                    borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                  ),
                ),
              ),
              SizedBox(height: AppDesign.space5),
              Text(
                country,
                style: context.textStyle(
                  FontSizeType.h5,
                  fontWeight: FontWeight.w700,
                  color: context.ds.textPrimary,
                ),
              ),
              SizedBox(height: AppDesign.space1),
              Text(
                '${currency.code} — ${currency.name}',
                style: context.textStyle(
                  FontSizeType.body2,
                  color: context.ds.textSecondary,
                ),
              ),
              SizedBox(height: AppDesign.space4),
              Container(
                padding: EdgeInsets.all(AppDesign.space3),
                decoration: BoxDecoration(
                  color: context.ds.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: context.ds.textSecondary,
                    ),
                    SizedBox(width: AppDesign.space2),
                    Expanded(
                      child: Text(
                        'Les prix seront affichés en ${currency.code}. Vous pourrez changer de pays plus tard dans les réglages.',
                        style: context.textStyle(
                          FontSizeType.overline,
                          color: context.ds.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppDesign.space5),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Annuler',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => Get.back<void>(),
                    ),
                  ),
                  SizedBox(width: AppDesign.space3),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Confirmer',
                      onPressed: () {
                        Get.back<void>();
                        controller.selectCountry(countryData);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      backgroundColor: context.ds.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDesign.radiusXl),
        ),
      ),
      isScrollControlled: true,
    );
  }
}

/// Ligne de la liste des pays.
class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.currency,
    required this.onTap,
  });

  final String country;
  final CurrencyModel currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppDesign.space3),
        child: Row(
          children: [
            // Pastille neutre portant le symbole monétaire. Le symbole peut
            // être long (« FCFA ») : on le réduit au lieu de le tronquer.
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: context.ds.surfaceMuted,
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  currency.symbol,
                  style: context.textStyle(
                    FontSizeType.caption,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(width: AppDesign.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    country,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: FontWeight.w600,
                      color: context.ds.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${currency.code} — ${currency.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: context.ds.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: AppDesign.space2),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.ds.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
