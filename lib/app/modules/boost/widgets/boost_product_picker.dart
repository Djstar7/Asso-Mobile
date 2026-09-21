import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../data/providers/currency_service.dart';
import '../controllers/boost_controller.dart';

/// Choix de l'article à sponsoriser, parmi ceux du vendeur.
///
/// Les articles déjà sponsorisés restent visibles mais non sélectionnables :
/// les masquer laisserait le vendeur chercher en vain un produit qu'il sait
/// avoir publié.
class BoostProductPicker extends GetView<BoostController> {
  const BoostProductPicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.products.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppDesign.surfaceMuted(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "Vous n'avez aucun article en ligne à sponsoriser.",
            style: TextStyle(
              color: AppDesign.textSecondary(context),
              fontSize: 14,
            ),
          ),
        );
      }

      final selected = controller.selectedProduct.value;

      return Column(
        children: [
          InkWell(
            onTap: () => _openSheet(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppDesign.surface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected != null
                      ? AppDesign.accent
                      : AppDesign.border(context),
                  width: selected != null ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  _thumb(context, selected),
                  const SizedBox(width: 12),
                  Expanded(
                    child: selected == null
                        ? Text(
                            'Choisir un article',
                            style: TextStyle(
                              color: AppDesign.textSecondary(context),
                              fontSize: 14,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selected['name']?.toString() ?? 'Article',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppDesign.textPrimary(context),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _price(selected),
                                style: TextStyle(
                                  color: AppDesign.textSecondary(context),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                  ),
                  Icon(
                    Icons.expand_more,
                    color: AppDesign.icon(context),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Prix converti dans la devise de l'utilisateur.
  ///
  /// `formatted_price` de l'API est toujours libellé en FCFA : on repart du
  /// montant pivot pour que le vendeur lise ses prix dans sa propre devise.
  String _price(Map<String, dynamic> product) {
    final raw = product['price_xaf'] ?? product['price'];
    final value = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');

    if (value == null || value <= 0) {
      return product['formatted_price']?.toString() ?? '';
    }

    return CurrencyService.formatFromPivot(value);
  }

  Widget _thumb(BuildContext context, Map<String, dynamic>? product) {
    final url = product?['primary_image']?.toString();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 46,
        height: 46,
        color: AppDesign.surfaceMuted(context),
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Icon(
                  Icons.inventory_2_outlined,
                  color: AppDesign.icon(context),
                  size: 20,
                ),
              )
            : Icon(
                Icons.inventory_2_outlined,
                color: AppDesign.icon(context),
                size: 20,
              ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: AppDesign.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppDesign.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Vos articles en ligne',
                    style: TextStyle(
                      color: AppDesign.textPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Obx(
                () => ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: controller.products.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final product = controller.products[index];
                    final boosted = controller.isProductBoosted(product['id']);

                    return _row(context, product, boosted);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _row(
    BuildContext context,
    Map<String, dynamic> product,
    bool boosted,
  ) {
    return Opacity(
      opacity: boosted ? 0.5 : 1,
      child: InkWell(
        onTap: boosted
            ? null
            : () {
                controller.selectProduct(product);
                Get.back();
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _thumb(context, product),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name']?.toString() ?? 'Article',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppDesign.textPrimary(context),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      boosted
                          ? 'Déjà sponsorisé'
                          : _price(product),
                      style: TextStyle(
                        color: boosted
                            ? AppDesign.accentText
                            : AppDesign.textSecondary(context),
                        fontSize: 12.5,
                        fontWeight: boosted ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
