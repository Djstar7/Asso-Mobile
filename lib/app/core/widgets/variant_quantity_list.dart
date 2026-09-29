import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import 'product_variant_selector.dart';
import 'quantity_stepper.dart';

/// Une quantité par option : 3 rouges, 2 noires… dans la même commande.
///
/// Le sélecteur d'options ne laissait choisir qu'une seule combinaison, si
/// bien qu'un client voulant plusieurs couleurs devait passer autant de
/// commandes. Chaque combinaison a ici sa propre ligne et sa propre
/// quantité ; la commande part avec une ligne par combinaison choisie.
///
/// [quantities] associe l'identifiant d'une variante à sa quantité ; les
/// variantes absentes valent 0.
class VariantQuantityList extends StatelessWidget {
  const VariantQuantityList({
    super.key,
    required this.catalog,
    required this.quantities,
    required this.onChanged,
    this.limitToStock = true,
    this.priceOf,
    this.onStockLimit,
  });

  final VariantCatalog catalog;
  final Map<int, int> quantities;
  final ValueChanged<Map<int, int>> onChanged;

  /// Vente au détail : la quantité d'une option ne dépasse pas son stock, et
  /// une option épuisée ne se commande pas. En gros, la marchandise vient du
  /// fournisseur : le stock saisi sur une variante n'a pas de sens et ne doit
  /// pas masquer une couleur.
  final bool limitToStock;

  /// Prix unitaire affiché sous l'option (supplément compris).
  final String Function(Map<String, dynamic> variant)? priceOf;

  /// Appelé quand on bute sur le stock d'une option.
  final void Function(Map<String, dynamic> variant, int stock)? onStockLimit;

  static int? idOf(Map<String, dynamic> variant) {
    final raw = variant['id'];
    return raw is int ? raw : int.tryParse(raw?.toString() ?? '');
  }

  /// Total des quantités, toutes options confondues.
  static int totalOf(Map<int, int> quantities) =>
      quantities.values.fold(0, (sum, q) => sum + (q > 0 ? q : 0));

  void _set(int variantId, int quantity) {
    final next = Map<int, int>.from(quantities);
    if (quantity > 0) {
      next[variantId] = quantity;
    } else {
      next.remove(variantId);
    }
    onChanged(next);
  }

  /// Pastille de la couleur de la variante, s'il y a une option couleur.
  Color? _swatchOf(Map<String, dynamic> variant) {
    final attributes = VariantCatalog.attributesOf(variant);
    for (final group in catalog.groups.where((g) => g.isColor)) {
      final value = attributes[group.name];
      if (value == null) continue;
      for (final option in group.values) {
        if (option.value == value) {
          return option.color ?? VariantPalette.guess(value);
        }
      }
      return VariantPalette.guess(value);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rows = catalog.variants
        .where((v) => idOf(v) != null)
        .toList(growable: false);

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDesign.space2),
          _buildRow(context, rows[i]),
        ],
      ],
    );
  }

  Widget _buildRow(BuildContext context, Map<String, dynamic> variant) {
    final id = idOf(variant)!;
    final quantity = quantities[id] ?? 0;
    final stock = VariantCatalog.stockOf(variant);
    final soldOut = limitToStock && stock <= 0;
    final selected = quantity > 0;
    final swatch = _swatchOf(variant);
    final label = VariantCatalog.labelOf(variant);

    final details = [
      if (priceOf != null) priceOf!(variant),
      if (limitToStock) soldOut ? 'core.variant.sold_out'.tr : 'core.variant.in_stock'.trParams({'count': '$stock'}),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space3,
        vertical: AppDesign.space2,
      ),
      decoration: BoxDecoration(
        color: selected ? AppDesign.accentSubtle : context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        border: Border.all(
          color: selected ? AppDesign.accent : context.ds.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Opacity(
        opacity: soldOut ? 0.5 : 1,
        child: Row(
          children: [
            if (swatch != null) ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.ds.borderStrong),
                ),
              ),
              const SizedBox(width: AppDesign.space3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.isEmpty ? 'core.variant.option'.tr : label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: FontWeight.w600,
                      color: context.ds.textPrimary,
                    ),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.caption,
                        color: soldOut
                            ? AppDesign.dangerText
                            : context.ds.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppDesign.space2),
            QuantityStepper(
              compact: true,
              value: quantity,
              min: 0,
              max: limitToStock ? stock : null,
              enabled: !soldOut,
              onChanged: (value) => _set(id, value),
              onMaxReached: onStockLimit == null
                  ? null
                  : () => onStockLimit!(variant, stock),
            ),
          ],
        ),
      ),
    );
  }
}
