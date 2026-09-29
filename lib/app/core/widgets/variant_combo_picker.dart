import 'package:flutter/material.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import 'product_variant_selector.dart';
import 'quantity_stepper.dart';
import 'variant_quantity_list.dart';

/// Choix des options par combinaison : les couleurs et les tailles défilent
/// à l'horizontale, une seule saisie de quantité vaut pour la combinaison
/// choisie (« Bleu · M »), et chaque combinaison garde sa quantité.
///
/// Le client choisit Bleu · M, saisit 10, puis Rouge · L, saisit 5 : la
/// commande part avec les deux lignes. La liste « Votre sélection » rappelle
/// chaque combinaison ; la toucher la rouvre, la croix la retire.
///
/// [quantities] associe l'identifiant d'une variante à sa quantité, comme
/// pour [VariantQuantityList].
class VariantComboPicker extends StatefulWidget {
  const VariantComboPicker({
    super.key,
    required this.catalog,
    required this.quantities,
    required this.onChanged,
    this.limitToStock = true,
    this.priceOf,
    this.onStockLimit,
    this.onFocusChanged,
    this.lineHasError,
  });

  final VariantCatalog catalog;
  final Map<int, int> quantities;
  final ValueChanged<Map<int, int>> onChanged;

  /// Vente au détail : la quantité ne dépasse pas le stock de la combinaison
  /// et une combinaison épuisée ne se choisit pas. En gros, le stock des
  /// variantes est sans objet.
  final bool limitToStock;

  /// Prix unitaire affiché pour la combinaison choisie.
  final String Function(Map<String, dynamic> variant)? priceOf;

  /// Appelé quand on bute sur le stock de la combinaison.
  final void Function(Map<String, dynamic> variant, int stock)? onStockLimit;

  /// Combinaison en cours de saisie (null tant qu'elle est incomplète).
  final ValueChanged<int?>? onFocusChanged;

  /// Quantité en erreur pour une ligne (ex. sous le minimum du palier).
  final bool Function(int variantId, int quantity)? lineHasError;

  @override
  State<VariantComboPicker> createState() => _VariantComboPickerState();
}

class _VariantComboPickerState extends State<VariantComboPicker> {
  final Map<String, String> _selection = {};

  VariantCatalog get _catalog => widget.catalog;

  @override
  void initState() {
    super.initState();
    _restoreSelection();
  }

  @override
  void didUpdateWidget(covariant VariantComboPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog.identity != widget.catalog.identity) {
      _selection.clear();
      _restoreSelection();
    }
  }

  /// Rouvre la première combinaison déjà commandée, sinon présélectionne les
  /// options à valeur unique.
  void _restoreSelection() {
    final first = _orderedLines.firstOrNull;
    if (first != null) {
      _selection.addAll(VariantCatalog.attributesOf(first.$1));
    } else {
      for (final group in _catalog.groups) {
        if (group.values.length == 1 &&
            _exists(group.name, group.values.first.value, const {})) {
          _selection[group.name] = group.values.first.value;
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFocusChanged?.call(_focusedId);
    });
  }

  bool _usable(Map<String, dynamic> variant) =>
      !widget.limitToStock || VariantCatalog.stockOf(variant) > 0;

  /// Une valeur est proposable si une combinaison commandable la contient et
  /// reste compatible avec les autres choix.
  bool _exists(String group, String value, Map<String, String> selection) =>
      _catalog.variants.any((variant) {
        if (!_usable(variant)) return false;
        final attributes = VariantCatalog.attributesOf(variant);
        if (attributes[group] != value) return false;
        return selection.entries.every(
          (e) => e.key == group || attributes[e.key] == e.value,
        );
      });

  Map<String, dynamic>? get _focused {
    final variant = _catalog.find(_selection);
    return variant != null && _usable(variant) ? variant : null;
  }

  int? get _focusedId {
    final variant = _focused;
    return variant == null ? null : VariantQuantityList.idOf(variant);
  }

  /// Combinaisons commandées, dans l'ordre du catalogue.
  List<(Map<String, dynamic>, int)> get _orderedLines => [
    for (final variant in _catalog.variants)
      if ((widget.quantities[VariantQuantityList.idOf(variant)] ?? 0) > 0)
        (variant, widget.quantities[VariantQuantityList.idOf(variant)]!),
  ];

  void _select(VariantOptionGroup group, String value) {
    setState(() {
      _selection[group.name] = value;
      // Retire les choix devenus incompatibles au lieu de bloquer le client.
      for (final other in _catalog.groups) {
        if (other.name == group.name) continue;
        final current = _selection[other.name];
        if (current != null && !_exists(other.name, current, _selection)) {
          _selection.remove(other.name);
        }
      }
    });
    widget.onFocusChanged?.call(_focusedId);
  }

  void _open(Map<String, dynamic> variant) {
    setState(() {
      _selection
        ..clear()
        ..addAll(VariantCatalog.attributesOf(variant));
    });
    widget.onFocusChanged?.call(_focusedId);
  }

  void _set(int variantId, int quantity) {
    final next = Map<int, int>.from(widget.quantities);
    if (quantity > 0) {
      next[variantId] = quantity;
    } else {
      next.remove(variantId);
    }
    widget.onChanged(next);
  }

  /// Quantité déjà commandée sur les combinaisons qui portent cette valeur :
  /// la pastille rappelle qu'on a déjà pris du bleu.
  int _orderedWith(String group, String value) {
    var total = 0;
    for (final (variant, quantity) in _orderedLines) {
      if (VariantCatalog.attributesOf(variant)[group] == value) {
        total += quantity;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_catalog.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in _catalog.groups) ...[
          _buildGroup(context, group),
          const SizedBox(height: AppDesign.space3),
        ],
        _buildComboQuantity(context),
        if (_orderedLines.isNotEmpty) ...[
          const SizedBox(height: AppDesign.space3),
          _buildSummary(context),
        ],
      ],
    );
  }

  Widget _buildGroup(BuildContext context, VariantOptionGroup group) {
    final selected = _selection[group.name];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: group.name,
                style: context.textStyle(
                  FontSizeType.body2,
                  fontWeight: FontWeight.w700,
                  color: context.ds.textPrimary,
                ),
              ),
              TextSpan(
                text: '  ${selected ?? 'Choisissez'}',
                style: context.textStyle(
                  FontSizeType.body2,
                  fontWeight: selected == null
                      ? FontWeight.w400
                      : FontWeight.w600,
                  color: selected == null
                      ? context.ds.textSecondary
                      : AppDesign.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDesign.space2),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in group.values) ...[
                _buildChip(context, group, option),
                const SizedBox(width: AppDesign.space2),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
    BuildContext context,
    VariantOptionGroup group,
    VariantOptionValue option,
  ) {
    final selected = _selection[group.name] == option.value;
    // Une valeur incompatible reste touchable : elle remplace les autres
    // choix au lieu d'être cachée.
    final available = _exists(group.name, option.value, const {});
    final compatible = _exists(group.name, option.value, _selection);
    final ordered = _orderedWith(group.name, option.value);
    final swatch = group.isColor
        ? (option.color ?? VariantPalette.guess(option.value))
        : null;

    return Semantics(
      button: true,
      selected: selected,
      enabled: available,
      label: '${group.name} ${option.value}',
      child: Opacity(
        opacity: !available ? 0.35 : (compatible || selected ? 1 : 0.6),
        child: Material(
          color: selected ? AppDesign.accentSubtle : context.ds.surface,
          borderRadius: BorderRadius.circular(AppDesign.radiusSm),
          child: InkWell(
            onTap: available ? () => _select(group, option.value) : null,
            borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: AppDesign.minTapTarget,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppDesign.space3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                border: Border.all(
                  color: selected ? AppDesign.accent : context.ds.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (swatch != null) ...[
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: swatch,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.ds.borderStrong),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: VariantPalette.onColor(swatch),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppDesign.space2),
                  ],
                  Text(
                    option.value,
                    style: context.textStyle(
                      FontSizeType.body2,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: context.ds.textPrimary,
                    ),
                  ),
                  if (ordered > 0) ...[
                    const SizedBox(width: AppDesign.space2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppDesign.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$ordered',
                        style: context.textStyle(
                          FontSizeType.caption,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Une seule saisie : la quantité de la combinaison choisie.
  Widget _buildComboQuantity(BuildContext context) {
    final variant = _focused;
    if (variant == null) {
      final missing = _catalog.missing(_selection);
      return _notice(
        context,
        icon: Icons.touch_app_outlined,
        text: missing.isEmpty
            ? 'Cette combinaison n’est pas disponible'
            : 'Choisissez : ${missing.join(', ')}',
      );
    }

    final id = VariantQuantityList.idOf(variant)!;
    final quantity = widget.quantities[id] ?? 0;
    final stock = VariantCatalog.stockOf(variant);
    final details = [
      if (widget.priceOf != null) widget.priceOf!(variant),
      if (widget.limitToStock) '$stock en stock',
    ];
    final hasError =
        quantity > 0 && (widget.lineHasError?.call(id, quantity) ?? false);

    return Container(
      padding: const EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(
        color: AppDesign.accentSubtle,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        border: Border.all(color: AppDesign.accent, width: 1.5),
      ),
      // Libellé à gauche, quantité à droite : une seule ligne nette.
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  VariantCatalog.labelOf(variant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textPrimary,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details.join(' · '),
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: context.ds.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDesign.space2),
          QuantityStepper(
            // Nouvelle combinaison : champ neuf, sans reprendre la saisie
            // de la précédente.
            key: ValueKey('combo-$id'),
            value: quantity,
            min: 0,
            max: widget.limitToStock ? stock : null,
            hasError: hasError,
            onChanged: (value) => _set(id, value),
            onMaxReached: widget.onStockLimit == null
                ? null
                : () => widget.onStockLimit!(variant, stock),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final lines = _orderedLines;
    final focusedId = _focusedId;
    final total = VariantQuantityList.totalOf(widget.quantities);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Votre sélection · $total au total',
          style: context.textStyle(
            FontSizeType.caption,
            fontWeight: FontWeight.w700,
            color: context.ds.textSecondary,
          ),
        ),
        const SizedBox(height: AppDesign.space2),
        Wrap(
          spacing: AppDesign.space2,
          runSpacing: AppDesign.space2,
          children: [
            for (final (variant, quantity) in lines)
              _buildLine(
                context,
                variant,
                quantity,
                focused: VariantQuantityList.idOf(variant) == focusedId,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLine(
    BuildContext context,
    Map<String, dynamic> variant,
    int quantity, {
    required bool focused,
  }) {
    final id = VariantQuantityList.idOf(variant)!;
    final hasError = widget.lineHasError?.call(id, quantity) ?? false;
    final color = hasError ? AppDesign.danger : AppDesign.accent;

    return Material(
      color: focused ? AppDesign.accentSubtle : context.ds.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _open(variant),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.only(
            left: AppDesign.space3,
            top: 4,
            bottom: 4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: focused || hasError ? color : context.ds.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${VariantCatalog.labelOf(variant)} × $quantity',
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: FontWeight.w600,
                  color: hasError
                      ? AppDesign.dangerText
                      : context.ds.textPrimary,
                ),
              ),
              IconButton(
                tooltip: 'Retirer',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: () => _set(id, 0),
                icon: Icon(Icons.close_rounded, color: context.ds.icon),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notice(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) => Container(
    padding: const EdgeInsets.all(AppDesign.space3),
    decoration: BoxDecoration(
      color: context.ds.surface,
      borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      border: Border.all(color: context.ds.border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: context.ds.textSecondary),
        const SizedBox(width: AppDesign.space2),
        Expanded(
          child: Text(
            text,
            style: context.textStyle(
              FontSizeType.body2,
              color: context.ds.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}
