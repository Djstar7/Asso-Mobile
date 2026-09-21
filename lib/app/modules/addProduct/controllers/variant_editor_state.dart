import 'dart:convert';

import 'package:get/get.dart';

import '../../../core/widgets/product_variant_selector.dart';

class VariantDraftValue {
  String value;
  String? hex;
  VariantDraftValue(this.value, [this.hex]);
}

class VariantDraftGroup {
  String name;
  bool isColor;
  final List<VariantDraftValue> values;
  VariantDraftGroup(
    this.name, {
    required this.isColor,
    List<VariantDraftValue>? values,
  }) : values = values ?? [];
}

class VariantDraftRow {
  /// Identifiant serveur de la déclinaison, conservé entre deux éditions.
  ///
  /// Sans lui, `replace_variants=1` faisait supprimer puis recréer toutes les
  /// déclinaisons à chaque enregistrement : les `variant_id` déjà référencés
  /// par des commandes passées pointaient alors dans le vide.
  int? id;

  int stock;
  double priceAdjustment;
  String sku;
  bool isActive;

  /// Poids propre à la déclinaison, en kg.
  ///
  /// Une pointure 46 ou un modèle XXL ne pèsent pas le même colis qu'un XS :
  /// laisser le poids uniquement au niveau du produit faussait le calcul de
  /// livraison. `null` signifie « utiliser le poids du produit ».
  double? weightKg;

  /// Image propre à la déclinaison (chemin local tant qu'elle n'est pas envoyée).
  ///
  /// Permet d'afficher la photo du coloris choisi plutôt que l'image générique.
  String? imagePath;

  VariantDraftRow({
    this.id,
    this.stock = 0,
    this.priceAdjustment = 0,
    this.sku = '',
    this.isActive = true,
    this.weightKg,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'stock': stock,
        'priceAdjustment': priceAdjustment,
        'sku': sku,
        'isActive': isActive,
        if (weightKg != null) 'weightKg': weightKg,
        if (imagePath != null) 'imagePath': imagePath,
      };

  factory VariantDraftRow.fromJson(Map<String, dynamic> json) =>
      VariantDraftRow(
        id: (json['id'] as num?)?.toInt(),
        stock: (json['stock'] as num?)?.toInt() ?? 0,
        priceAdjustment: (json['priceAdjustment'] as num?)?.toDouble() ?? 0,
        sku: json['sku']?.toString() ?? '',
        isActive: json['isActive'] as bool? ?? true,
        weightKg: (json['weightKg'] as num?)?.toDouble(),
        imagePath: json['imagePath']?.toString(),
      );
}

/// État de l'éditeur de variantes vendeur : groupes d'options + quantité par combinaison.
/// Les combinaisons sont le produit cartésien des options (ex. 3 couleurs × 4 pointures).
class VariantEditorState {
  static const presets = <String, List<String>>{
    'couleur': VariantPalette.suggestions,
    'taille': ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'],
    'pointure': [
      '36',
      '37',
      '38',
      '39',
      '40',
      '41',
      '42',
      '43',
      '44',
      '45',
      '46',
    ],
    'stockage': ['64 Go', '128 Go', '256 Go', '512 Go', '1 To'],
    'mémoire': ['4 Go', '6 Go', '8 Go', '12 Go', '16 Go'],
  };

  final groups = <VariantDraftGroup>[].obs;

  /// Volontairement non réactif : les lignes sont créées à la volée pendant le build.
  final Map<String, VariantDraftRow> rows = {};

  /// À lire dans les Obx pour suivre toute modification de l'éditeur.
  final revision = 0.obs;

  /// Déclenche le rafraîchissement de l'UI après une mutation en place.
  void touch() {
    groups.refresh();
    revision.value++;
  }

  bool get hasVariants => combinations.isNotEmpty;

  List<VariantDraftGroup> get _validGroups => groups
      .where((g) => g.name.trim().isNotEmpty && g.values.isNotEmpty)
      .toList();

  List<Map<String, String>> get combinations {
    final valid = _validGroups;
    if (valid.isEmpty) return const [];
    var result = <Map<String, String>>[{}];
    for (final group in valid) {
      result = [
        for (final combo in result)
          for (final value in group.values)
            {...combo, group.name.trim(): value.value},
      ];
    }
    return result;
  }

  static String signature(Map<String, String> attributes) {
    final entries =
        attributes.entries
            .map(
              (e) => [e.key.trim().toLowerCase(), e.value.trim().toLowerCase()],
            )
            .toList()
          ..sort((a, b) => a[0].compareTo(b[0]));
    return jsonEncode(entries);
  }

  VariantDraftRow rowFor(Map<String, String> combo) =>
      rows.putIfAbsent(signature(combo), () => VariantDraftRow());

  /// Même règle que le serveur : somme de toutes les combinaisons.
  int get totalStock =>
      combinations.fold(0, (sum, combo) => sum + rowFor(combo).stock);

  List<String> presetsFor(VariantDraftGroup group) {
    final list = presets[group.name.trim().toLowerCase()] ?? const [];
    return list
        .where(
          (p) => !group.values.any(
            (v) => v.value.toLowerCase() == p.toLowerCase(),
          ),
        )
        .toList();
  }

  String? hexOf(String groupName, String value) {
    final group = groups.firstWhereOrNull((g) => g.name.trim() == groupName);
    if (group == null || !group.isColor) return null;
    return group.values.firstWhereOrNull((v) => v.value == value)?.hex ??
        VariantPalette.toHex(VariantPalette.guess(value));
  }

  // ───────────── Mutations ─────────────

  /// Retourne l'index du groupe (existant ou créé).
  int addGroup(String name) {
    final clean = _cap(name.trim());
    if (clean.isNotEmpty) {
      final existing = groups.indexWhere(
        (g) => g.name.toLowerCase() == clean.toLowerCase(),
      );
      if (existing >= 0) return existing;
    }
    groups.add(
      VariantDraftGroup(clean, isColor: VariantPalette.isColorOption(clean)),
    );
    return groups.length - 1;
  }

  void removeGroup(int index) {
    groups.removeAt(index);
    touch();
  }

  void renameGroup(int index, String name) {
    final group = groups[index];
    final clean = _cap(name.trim());
    if (clean == group.name) return;
    // Les quantités déjà saisies suivent le nouveau nom.
    final oldKey = group.name.trim().toLowerCase();
    final moved = <String, VariantDraftRow>{};
    rows.forEach((sig, row) {
      final pairs =
          (jsonDecode(sig) as List)
              .map(
                (p) => [
                  (p as List)[0] == oldKey ? clean.toLowerCase() : p[0],
                  p[1],
                ],
              )
              .toList()
            ..sort((a, b) => (a[0] as String).compareTo(b[0] as String));
      moved[jsonEncode(pairs)] = row;
    });
    rows
      ..clear()
      ..addAll(moved);
    group.name = clean;
    if (VariantPalette.isColorOption(clean)) group.isColor = true;
    touch();
  }

  void setColorMode(int index, bool isColor) {
    final group = groups[index];
    group.isColor = isColor;
    for (final v in group.values) {
      v.hex = isColor
          ? (v.hex ?? VariantPalette.toHex(VariantPalette.guess(v.value)))
          : null;
    }
    touch();
  }

  /// Accepte plusieurs valeurs séparées par des virgules : « S, M, L ».
  void addValues(int groupIndex, String raw, {String? hex}) {
    final group = groups[groupIndex];
    for (final part in raw.split(RegExp(r'[,;]+'))) {
      final value = part.trim();
      if (value.isEmpty) continue;
      if (group.values.any(
        (v) => v.value.toLowerCase() == value.toLowerCase(),
      )) {
        continue;
      }
      group.values.add(
        VariantDraftValue(
          value,
          group.isColor
              ? (hex ?? VariantPalette.toHex(VariantPalette.guess(value)))
              : null,
        ),
      );
    }
    touch();
  }

  void removeValue(int groupIndex, int valueIndex) {
    groups[groupIndex].values.removeAt(valueIndex);
    touch();
  }

  void setValueHex(int groupIndex, int valueIndex, String hex) {
    groups[groupIndex].values[valueIndex].hex = hex;
    touch();
  }

  void applyStockToAll(int stock) {
    for (final combo in combinations) {
      rowFor(combo).stock = stock;
    }
    touch();
  }

  void clear() {
    groups.clear();
    rows.clear();
    revision.value++;
  }

  // ───────────── API ─────────────

  void loadFromApi(dynamic rawVariants, dynamic rawOptions) {
    clear();
    final list = rawVariants is List ? rawVariants : const [];
    final catalog = VariantCatalog.fromApi(
      // Le vendeur doit aussi voir ses variantes masquées.
      list
          .whereType<Map>()
          .map((v) => {...Map<String, dynamic>.from(v), 'is_active': true})
          .toList(),
      rawOptions,
    );
    for (final group in catalog.groups) {
      groups.add(
        VariantDraftGroup(
          group.name,
          isColor: group.isColor,
          values: group.values
              .map(
                (v) => VariantDraftValue(
                  v.value,
                  v.color == null ? null : VariantPalette.toHex(v.color!),
                ),
              )
              .toList(),
        ),
      );
    }
    for (final raw in list.whereType<Map>()) {
      final variant = Map<String, dynamic>.from(raw);
      rows[signature(VariantCatalog.attributesOf(variant))] = VariantDraftRow(
        id: (variant['id'] as num?)?.toInt(),
        stock: VariantCatalog.stockOf(variant),
        priceAdjustment: (variant['price_adjustment'] as num?)?.toDouble() ?? 0,
        sku: variant['sku']?.toString() ?? '',
        isActive: variant['is_active'] != false,
        weightKg: (variant['weight'] as num?)?.toDouble(),
      );
    }
    touch();
  }

  // ───────────── Brouillon local ─────────────

  /// Sérialise l'éditeur pour le brouillon (format interne, pas celui de l'API).
  Map<String, dynamic> toDraftJson() => {
        'groups': groups
            .map(
              (g) => {
                'name': g.name,
                'isColor': g.isColor,
                'values': g.values
                    .map((v) => {'value': v.value, 'hex': v.hex})
                    .toList(),
              },
            )
            .toList(),
        'rows': rows.map((key, row) => MapEntry(key, row.toJson())),
      };

  void loadFromDraftJson(Map<String, dynamic> json) {
    clear();
    final rawGroups = json['groups'];
    if (rawGroups is List) {
      for (final rawGroup in rawGroups.whereType<Map>()) {
        final rawValues = rawGroup['values'];
        groups.add(
          VariantDraftGroup(
            rawGroup['name']?.toString() ?? '',
            isColor: rawGroup['isColor'] == true,
            values: rawValues is List
                ? rawValues
                    .whereType<Map>()
                    .map(
                      (v) => VariantDraftValue(
                        v['value']?.toString() ?? '',
                        v['hex']?.toString(),
                      ),
                    )
                    .where((v) => v.value.isNotEmpty)
                    .toList()
                : <VariantDraftValue>[],
          ),
        );
      }
    }

    final rawRows = json['rows'];
    if (rawRows is Map) {
      rawRows.forEach((key, value) {
        if (value is Map) {
          rows['$key'] =
              VariantDraftRow.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }
    touch();
  }

  /// Champs multipart attendus par l'API (`variants[i][attributes][Nom]`…).
  Map<String, String> toFields() {
    final fields = <String, String>{};
    final combos = combinations;
    if (combos.isEmpty) return fields;

    fields['variant_options'] = jsonEncode(
      _validGroups
          .map(
            (g) => {
              'name': g.name.trim(),
              'type': g.isColor ? 'color' : 'text',
              'values': g.values
                  .map(
                    (v) => {'value': v.value, if (v.hex != null) 'hex': v.hex},
                  )
                  .toList(),
            },
          )
          .toList(),
    );
    for (var i = 0; i < combos.length; i++) {
      final row = rowFor(combos[i]);
      combos[i].forEach((name, value) {
        fields['variants[$i][attributes][$name]'] = value;
      });
      // L'identifiant permet au serveur de mettre à jour la déclinaison
      // existante au lieu d'en créer une nouvelle.
      if (row.id != null) {
        fields['variants[$i][id]'] = '${row.id}';
      }
      fields['variants[$i][stock]'] = '${row.stock}';
      fields['variants[$i][price_adjustment]'] =
          row.priceAdjustment.toStringAsFixed(2);
      // Une référence vide ne doit pas être transmise : plusieurs chaînes
      // vides entreraient en collision sur une contrainte d'unicité.
      if (row.sku.trim().isNotEmpty) {
        fields['variants[$i][sku]'] = row.sku.trim();
      }
      fields['variants[$i][is_active]'] = row.isActive ? '1' : '0';
      // Poids par déclinaison : ignoré par les versions d'API qui ne le
      // connaissent pas encore, exploité dès qu'elles le supportent.
      if (row.weightKg != null) {
        fields['variants[$i][weight]'] = '${row.weightKg}';
      }
    }
    return fields;
  }

  static String _cap(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}
