import 'package:flutter/material.dart';

import '../utils/app_theme_system.dart';

/// Couleurs par défaut quand l'équipe ASSO n'a pas choisi de teinte précise.
class VariantPalette {
  static const _colorOptionNames = {
    'couleur',
    'couleurs',
    'color',
    'colour',
    'coloris',
    'teinte',
  };

  static const _named = <String, int>{
    'bleu marine': 0xFF1A237E,
    'bleu ciel': 0xFF81D4FA,
    'marine': 0xFF1A237E,
    'navy': 0xFF1A237E,
    'turquoise': 0xFF1DE9B6,
    'bordeaux': 0xFF7B1F2B,
    'rouge': 0xFFE53935,
    'red': 0xFFE53935,
    'bleu': 0xFF1E88E5,
    'blue': 0xFF1E88E5,
    'vert': 0xFF43A047,
    'green': 0xFF43A047,
    'kaki': 0xFF6B6B3A,
    'noir': 0xFF212121,
    'black': 0xFF212121,
    'blanc': 0xFFFAFAFA,
    'white': 0xFFFAFAFA,
    'jaune': 0xFFFDD835,
    'yellow': 0xFFFDD835,
    'orange': 0xFFFB8C00,
    'rose': 0xFFEC407A,
    'pink': 0xFFEC407A,
    'violet': 0xFF8E24AA,
    'purple': 0xFF8E24AA,
    'marron': 0xFF795548,
    'brown': 0xFF795548,
    'gris': 0xFF9E9E9E,
    'grey': 0xFF9E9E9E,
    'gray': 0xFF9E9E9E,
    'beige': 0xFFD7CCC8,
    'doré': 0xFFC9A227,
    'dore': 0xFFC9A227,
    'gold': 0xFFC9A227,
    'argent': 0xFFBDBDBD,
    'silver': 0xFFBDBDBD,
    'crème': 0xFFFFF8E1,
    'creme': 0xFFFFF8E1,
  };

  /// Suggestions proposées au vendeur, dans l'ordre d'affichage.
  static const suggestions = <String>[
    'Noir',
    'Blanc',
    'Gris',
    'Rouge',
    'Bleu',
    'Bleu marine',
    'Vert',
    'Jaune',
    'Orange',
    'Rose',
    'Violet',
    'Marron',
    'Beige',
    'Doré',
    'Argent',
  ];

  static bool isColorOption(String name) =>
      _colorOptionNames.contains(name.trim().toLowerCase());

  static Color? parseHex(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceFirst('#', '').trim();
    if (clean.length != 6) return null;
    final value = int.tryParse('FF$clean', radix: 16);
    return value == null ? null : Color(value);
  }

  static String toHex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color guess(String name) {
    final value = name.trim().toLowerCase();
    final keys = _named.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      if (value == key || value.contains(key)) return Color(_named[key]!);
    }
    return const Color(0xFFBDBDBD);
  }

  /// Contraste lisible pour une coche posée sur la pastille.
  static Color onColor(Color color) =>
      color.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;
}

class VariantOptionValue {
  final String value;
  final Color? color;
  const VariantOptionValue(this.value, this.color);
}

class VariantOptionGroup {
  final String name;
  final bool isColor;
  final List<VariantOptionValue> values;
  const VariantOptionGroup({
    required this.name,
    required this.isColor,
    required this.values,
  });
}

/// Lecture des variantes renvoyées par l'API (`variants` + `variant_options`).
class VariantCatalog {
  final List<Map<String, dynamic>> variants;
  final List<VariantOptionGroup> groups;

  VariantCatalog._(this.variants, this.groups);

  factory VariantCatalog.fromApi(dynamic rawVariants, dynamic rawOptions) {
    final variants =
        (rawVariants as List?)
            ?.whereType<Map>()
            .map((v) => Map<String, dynamic>.from(v))
            .where((v) => v['is_active'] != false)
            .toList() ??
        <Map<String, dynamic>>[];

    final groups = <VariantOptionGroup>[];
    final seen = <String>{};

    if (rawOptions is List) {
      for (final raw in rawOptions.whereType<Map>()) {
        final name = raw['name']?.toString() ?? '';
        if (name.isEmpty || !seen.add(name)) continue;
        final isColor =
            raw['type'] == 'color' || VariantPalette.isColorOption(name);
        final values = (raw['values'] as List? ?? const [])
            .whereType<Map>()
            .map((v) {
              final value = v['value']?.toString() ?? '';
              return VariantOptionValue(
                value,
                isColor
                    ? (VariantPalette.parseHex(v['hex']?.toString()) ??
                          VariantPalette.guess(value))
                    : null,
              );
            })
            .where((v) => v.value.isNotEmpty)
            .toList();
        if (values.isNotEmpty) {
          groups.add(
            VariantOptionGroup(name: name, isColor: isColor, values: values),
          );
        }
      }
    }

    // Produits plus anciens sans groupes enregistrés : on les déduit des variantes.
    final derived = <String, List<String>>{};
    for (final variant in variants) {
      final attributes = Map<String, dynamic>.from(
        variant['attributes'] as Map? ?? const {},
      );
      attributes.forEach((name, value) {
        if (seen.contains(name)) return;
        final list = derived.putIfAbsent(name, () => []);
        final text = value.toString();
        if (!list.contains(text)) list.add(text);
      });
    }
    derived.forEach((name, values) {
      final isColor = VariantPalette.isColorOption(name);
      groups.add(
        VariantOptionGroup(
          name: name,
          isColor: isColor,
          values: values
              .map(
                (v) => VariantOptionValue(
                  v,
                  isColor ? VariantPalette.guess(v) : null,
                ),
              )
              .toList(),
        ),
      );
    });

    return VariantCatalog._(variants, groups);
  }

  bool get isEmpty => variants.isEmpty || groups.isEmpty;

  /// Identité stable : le catalogue est reconstruit à chaque rebuild de l'écran.
  String get identity => variants.map((v) => v['id']).join(',');

  static int stockOf(Map<String, dynamic> variant) =>
      (variant['stock'] as num?)?.toInt() ??
      int.tryParse(variant['stock']?.toString() ?? '') ??
      0;

  static Map<String, String> attributesOf(Map<String, dynamic> variant) =>
      Map<String, dynamic>.from(
        variant['attributes'] as Map? ?? const {},
      ).map((k, v) => MapEntry(k, v.toString()));

  /// Libellé lisible : « Noir · 42 ».
  static String labelOf(Map<String, dynamic>? variant) {
    if (variant == null) return '';
    return attributesOf(variant).values.join(' · ');
  }

  bool _matches(
    Map<String, dynamic> variant,
    Map<String, String> selection, {
    String? ignoring,
  }) {
    final attributes = attributesOf(variant);
    for (final entry in selection.entries) {
      if (entry.key == ignoring) continue;
      if (attributes[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Une valeur est disponible si une variante en stock la contient et reste
  /// compatible avec les autres choix déjà faits.
  bool isAvailable(String group, String value, Map<String, String> selection) {
    return variants.any(
      (v) =>
          stockOf(v) > 0 &&
          attributesOf(v)[group] == value &&
          _matches(v, selection, ignoring: group),
    );
  }

  bool exists(String group, String value) =>
      variants.any((v) => attributesOf(v)[group] == value);

  Map<String, dynamic>? find(Map<String, String> selection) {
    if (selection.length < groups.length) return null;
    for (final variant in variants) {
      final attributes = attributesOf(variant);
      if (groups.every((g) => attributes[g.name] == selection[g.name])) {
        return variant;
      }
    }
    return null;
  }

  List<String> missing(Map<String, String> selection) => groups
      .where((g) => !selection.containsKey(g.name))
      .map((g) => g.name)
      .toList();
}

/// Sélecteur type « boutique en ligne » : pastilles de couleur, puces de taille,
/// valeurs indisponibles barrées, stock et supplément de la combinaison choisie.
class ProductVariantSelector extends StatefulWidget {
  final VariantCatalog catalog;
  final int? selectedVariantId;
  final ValueChanged<Map<String, dynamic>?> onChanged;

  /// Formatte un supplément exprimé en XAF (ex. « +5 000 FCFA »).
  final String Function(double amountXaf)? formatAdjustment;
  final bool showStock;

  const ProductVariantSelector({
    super.key,
    required this.catalog,
    required this.onChanged,
    this.selectedVariantId,
    this.formatAdjustment,
    this.showStock = true,
  });

  @override
  State<ProductVariantSelector> createState() => _ProductVariantSelectorState();
}

class _ProductVariantSelectorState extends State<ProductVariantSelector> {
  final Map<String, String> _selection = {};

  VariantCatalog get _catalog => widget.catalog;

  @override
  void initState() {
    super.initState();
    _restoreSelection();
  }

  @override
  void didUpdateWidget(covariant ProductVariantSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog.identity != widget.catalog.identity) {
      _selection.clear();
      _restoreSelection();
    }
  }

  void _restoreSelection() {
    final selected = _catalog.variants.where(
      (v) => v['id'] == widget.selectedVariantId,
    );
    if (selected.isNotEmpty) {
      _selection.addAll(VariantCatalog.attributesOf(selected.first));
      return;
    }
    // Choix évident : une option à valeur unique (ex. une seule couleur).
    for (final group in _catalog.groups) {
      if (group.values.length == 1) {
        _selection[group.name] = group.values.first.value;
      }
    }
    // Une variante précédemment choisie qui n'existe plus doit être oubliée.
    if (widget.selectedVariantId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    } else if (_selection.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    }
  }

  void _select(VariantOptionGroup group, String value) {
    setState(() {
      if (_selection[group.name] == value && group.values.length > 1) {
        _selection.remove(group.name);
      } else {
        _selection[group.name] = value;
        // Retire les choix devenus incompatibles au lieu de bloquer le client.
        for (final other in _catalog.groups) {
          if (other.name == group.name) continue;
          final current = _selection[other.name];
          if (current != null &&
              !_catalog.isAvailable(other.name, current, _selection)) {
            _selection.remove(other.name);
          }
        }
      }
    });
    _notify();
  }

  void _notify() {
    final variant = _catalog.find(_selection);
    final usable =
        variant != null && VariantCatalog.stockOf(variant) > 0 ? variant : null;
    widget.onChanged(usable);
  }

  @override
  Widget build(BuildContext context) {
    if (_catalog.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in _catalog.groups) ...[
          _buildGroupHeader(context, group),
          const SizedBox(height: 10),
          group.isColor
              ? _buildColorGroup(context, group)
              : _buildChipGroup(context, group),
          const SizedBox(height: 18),
        ],
        _buildStatus(context),
      ],
    );
  }

  Widget _buildGroupHeader(BuildContext context, VariantOptionGroup group) {
    final selected = _selection[group.name];
    return Row(
      children: [
        Text(
          group.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: context.primaryTextColor,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              selected ?? 'Choisissez',
              key: ValueKey(selected),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected == null
                    ? FontWeight.w400
                    : FontWeight.w600,
                color: selected == null
                    ? context.secondaryTextColor
                    : AppThemeSystem.primaryColor,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorGroup(BuildContext context, VariantOptionGroup group) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: group.values.map((option) {
        final color = option.color ?? VariantPalette.guess(option.value);
        final selected = _selection[group.name] == option.value;
        final available = _catalog.isAvailable(
          group.name,
          option.value,
          _selection,
        );
        return Semantics(
          button: true,
          selected: selected,
          label: '${group.name} ${option.value}',
          child: GestureDetector(
            onTap: () => _select(group, option.value),
            child: SizedBox(
              width: 58,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppThemeSystem.primaryColor
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.12),
                            ),
                            boxShadow: [
                              if (available)
                                BoxShadow(
                                  color: color.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                            ],
                          ),
                        ),
                        if (!available)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                            child: CustomPaint(painter: _StrikePainter()),
                          ),
                        if (selected && available)
                          Icon(
                            Icons.check_rounded,
                            size: 22,
                            color: VariantPalette.onColor(color),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: available
                          ? context.primaryTextColor
                          : context.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChipGroup(BuildContext context, VariantOptionGroup group) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: group.values.map((option) {
        final selected = _selection[group.name] == option.value;
        final available = _catalog.isAvailable(
          group.name,
          option.value,
          _selection,
        );
        return Semantics(
          button: true,
          selected: selected,
          label: '${group.name} ${option.value}',
          child: InkWell(
            onTap: () => _select(group, option.value),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minWidth: 54, minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppThemeSystem.primaryColor
                    : context.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? AppThemeSystem.primaryColor
                      : available
                      ? context.borderColor
                      : context.borderColor.withValues(alpha: 0.5),
                  width: selected ? 2 : 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppThemeSystem.primaryColor.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                option.value,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : available
                      ? context.primaryTextColor
                      : context.secondaryTextColor.withValues(alpha: 0.6),
                  decoration: available ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatus(BuildContext context) {
    final missing = _catalog.missing(_selection);
    final variant = _catalog.find(_selection);

    late final IconData icon;
    late final Color color;
    late final String text;
    String? extra;

    if (missing.isNotEmpty) {
      icon = Icons.touch_app_outlined;
      color = AppThemeSystem.infoColor;
      text = 'Sélectionnez : ${missing.join(', ')}';
    } else if (variant == null) {
      icon = Icons.block;
      color = AppThemeSystem.errorColor;
      text = "Cette combinaison n'est pas proposée";
    } else {
      final stock = VariantCatalog.stockOf(variant);
      if (stock <= 0) {
        icon = Icons.remove_shopping_cart_outlined;
        color = AppThemeSystem.errorColor;
        text = 'Épuisé pour ce choix';
      } else {
        icon = Icons.check_circle_rounded;
        color = AppThemeSystem.successColor;
        text = widget.showStock
            ? (stock <= 5
                  ? 'Plus que $stock en stock'
                  : 'En stock ($stock disponibles)')
            : 'Disponible';
      }
      final adjustment =
          (variant['price_adjustment_xaf'] as num?)?.toDouble() ??
          (variant['price_adjustment'] as num?)?.toDouble() ??
          0;
      if (adjustment != 0 && widget.formatAdjustment != null) {
        extra =
            '${adjustment > 0 ? '+' : '−'}${widget.formatAdjustment!(adjustment.abs())}';
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (extra != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                extra,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppThemeSystem.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StrikePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.8),
      Offset(size.width * 0.8, size.height * 0.2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
