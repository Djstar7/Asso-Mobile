/// Catégories et sous-catégories telles que la base du serveur les connaît.
///
/// Un produit saisi hors ligne part plus tard : entre-temps, la sélection du
/// vendeur peut ne plus correspondre à la base (cache ancien, catégorie
/// renommée, ou fiche enregistrée avec l'ancienne liste de secours codée en
/// dur, dont les identifiants étaient inventés). Le catalogue rapproche une
/// sélection des identifiants réels avant tout envoi.
class CategoryCatalog {
  CategoryCatalog._(this.categories);

  /// Clé du cache local de la réponse `GET /categories`.
  static const snapshotKey = 'product_categories';

  final List<CatalogCategory> categories;

  bool get isEmpty => categories.isEmpty;

  /// Lit la réponse du serveur (`categories: [{id, name, subcategories}]`).
  /// Les entrées sans identifiant numérique sont ignorées.
  factory CategoryCatalog.fromApi(List raw) {
    final categories = <CatalogCategory>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final id = _asId(entry['id']);
      if (id == null) continue;
      final subcategories = <CatalogSubcategory>[];
      final rawSubs = entry['subcategories'];
      if (rawSubs is List) {
        for (final sub in rawSubs) {
          if (sub is! Map) continue;
          final subId = _asId(sub['id']);
          if (subId == null) continue;
          subcategories.add(
            CatalogSubcategory(id: subId, name: '${sub['name'] ?? ''}'),
          );
        }
      }
      categories.add(
        CatalogCategory(
          id: id,
          name: '${entry['name'] ?? ''}',
          subcategories: subcategories,
        ),
      );
    }
    return CategoryCatalog._(categories);
  }

  /// Retrouve la sélection dans la base. Les noms priment sur les
  /// identifiants : un identifiant venu d'une liste périmée peut désigner
  /// une autre sous-catégorie, un nom non.
  ///
  /// Nul si la sélection ne correspond à rien de connu.
  CategorySelection? resolve({
    String? categoryId,
    String? subcategoryId,
    String? categoryName,
    String? subcategoryName,
  }) {
    var catName = categoryName?.trim() ?? '';
    var subName = subcategoryName?.trim() ?? '';

    // Fiches enregistrées avec l'ancienne liste de secours : category_id
    // contenait le nom de la catégorie et subcategory_id un numéro inventé.
    if (categoryId != null && categoryId.isNotEmpty && _asId(categoryId) == null) {
      if (catName.isEmpty) catName = categoryId;
      if (subName.isEmpty) subName = _legacySubcategoryNames[subcategoryId] ?? '';
      categoryId = null;
      subcategoryId = null;
    }

    if (subName.isNotEmpty) {
      final byName = _findSubcategoryByName(subName, catName);
      if (byName != null) return byName;
    }

    final subId = _asId(subcategoryId);
    if (subId != null) {
      for (final category in categories) {
        final sub = category.subcategoryById(subId);
        if (sub == null) continue;
        // Identifiant cohérent avec la catégorie déclarée, s'il y en a une.
        final catId = _asId(categoryId);
        if (catId != null && catId != category.id) return null;
        if (subName.isNotEmpty && _norm(sub.name) != _norm(subName)) return null;
        return CategorySelection(category: category, subcategory: sub);
      }
    }

    // Catégorie sans sous-catégorie (le serveur n'en exige pas).
    if (subName.isEmpty && subId == null) {
      final catId = _asId(categoryId);
      for (final category in categories) {
        if ((catId != null && category.id == catId) ||
            (catId == null && catName.isNotEmpty && _norm(category.name) == _norm(catName))) {
          return CategorySelection(category: category);
        }
      }
    }
    return null;
  }

  CategorySelection? _findSubcategoryByName(String subName, String catName) {
    final wanted = _norm(subName);
    CategorySelection? fallback;
    for (final category in categories) {
      for (final sub in category.subcategories) {
        if (_norm(sub.name) != wanted) continue;
        final match = CategorySelection(category: category, subcategory: sub);
        if (catName.isEmpty || _norm(category.name) == _norm(catName)) {
          return match;
        }
        fallback ??= match;
      }
    }
    return fallback;
  }

  static int? _asId(Object? value) {
    if (value is int) return value > 0 ? value : null;
    final parsed = int.tryParse('${value ?? ''}'.trim());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  /// Comparaison insensible à la casse, aux accents et aux espaces.
  static String _norm(String value) {
    const accents = {
      'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
      'ç': 'c',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i', 'í': 'i',
      'ô': 'o', 'ö': 'o', 'ó': 'o', 'õ': 'o',
      'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
      'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
    };
    final lower = value.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final char in lower.split('')) {
      buffer.write(accents[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Numéros de l'ancienne liste de secours et leur libellé, pour rattraper
  /// les fiches déjà en file quand elle était encore utilisée.
  static const _legacySubcategoryNames = <String, String>{
    '1': 'Smartphones',
    '2': 'Ordinateurs portables',
    '3': 'Tablettes',
    '4': 'Accessoires électroniques',
    '5': 'Vêtements homme',
    '6': 'Vêtements femme',
    '7': 'Chaussures',
    '8': 'Accessoires de mode',
    '9': 'Fruits et légumes',
    '10': 'Viandes et poissons',
    '11': 'Produits laitiers',
    '12': 'Épicerie',
    '13': 'Meubles',
    '14': 'Décoration',
    '15': 'Électroménager',
    '16': 'Jardinage',
    '17': 'Soins du visage',
    '18': 'Maquillage',
    '19': 'Parfums',
    '20': 'Produits de santé',
  };
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    required this.subcategories,
  });

  final int id;
  final String name;
  final List<CatalogSubcategory> subcategories;

  CatalogSubcategory? subcategoryById(int id) {
    for (final sub in subcategories) {
      if (sub.id == id) return sub;
    }
    return null;
  }
}

class CatalogSubcategory {
  const CatalogSubcategory({required this.id, required this.name});

  final int id;
  final String name;
}

/// Sélection rapprochée de la base : identifiants sûrs à envoyer.
class CategorySelection {
  const CategorySelection({required this.category, this.subcategory});

  final CatalogCategory category;
  final CatalogSubcategory? subcategory;

  String get categoryId => '${category.id}';
  String? get subcategoryId =>
      subcategory == null ? null : '${subcategory!.id}';
}
