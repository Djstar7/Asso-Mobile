/// Ce que ML Kit a lu sur la photo du produit, sur le téléphone.
///
/// Seules ces données partent au serveur (jamais l'image) : le serveur
/// cherche la fiche dans les bases ouvertes, puis la complète par règles.
class ScanExtraction {
  const ScanExtraction({
    required this.imagePath,
    this.barcode,
    this.barcodeFormat,
    this.ocrText = '',
    this.ocrLines = const [],
    this.labels = const [],
  });

  /// Photo capturée ou importée : devient une photo du produit.
  final String imagePath;
  final String? barcode;
  final String? barcodeFormat;
  final String ocrText;

  /// Lignes de l'étiquette, de la plus grande à la plus petite : la première
  /// porte en général la marque ou le nom.
  final List<String> ocrLines;

  /// Labels d'image ML Kit (anglais) avec leur confiance.
  final List<({String text, double confidence})> labels;

  bool get isEmpty =>
      (barcode ?? '').isEmpty && ocrText.trim().isEmpty && labels.isEmpty;

  ScanExtraction copyWith({String? barcode, String? barcodeFormat}) =>
      ScanExtraction(
        imagePath: imagePath,
        barcode: barcode ?? this.barcode,
        barcodeFormat: barcodeFormat ?? this.barcodeFormat,
        ocrText: ocrText,
        ocrLines: ocrLines,
        labels: labels,
      );

  /// Corps de `POST /products/scan-lookup` (limites du serveur respectées).
  Map<String, dynamic> toPayload() => {
        if ((barcode ?? '').isNotEmpty) 'barcode': barcode,
        if ((barcodeFormat ?? '').isNotEmpty) 'barcode_format': barcodeFormat,
        if (ocrText.trim().isNotEmpty)
          'ocr_text': ocrText.length > 5000 ? ocrText.substring(0, 5000) : ocrText,
        'ocr_lines': ocrLines
            .take(200)
            .map((l) => l.length > 300 ? l.substring(0, 300) : l)
            .toList(),
        'labels': labels
            .take(20)
            .map((l) => {'text': l.text, 'confidence': l.confidence})
            .toList(),
      };
}

/// Fiche proposée par le serveur. Chaque champ porte une confiance (0..1) :
/// le formulaire n'applique que ce qui dépasse le seuil.
class ScanSuggestion {
  const ScanSuggestion({
    required this.source,
    this.name,
    this.description,
    this.brand,
    this.barcode,
    this.weightKg,
    this.categoryId,
    this.subcategoryId,
    this.confidence = const {},
  });

  /// asso, openfoodfacts, openbeautyfacts, openproductsfacts, upcitemdb,
  /// rules (déduit de l'étiquette) ou none.
  final String source;
  final String? name;
  final String? description;
  final String? brand;
  final String? barcode;
  final double? weightKg;
  final String? categoryId;
  final String? subcategoryId;
  final Map<String, double> confidence;

  bool get isEmpty => source == 'none';

  double confidenceOf(String field) => confidence[field] ?? 0;

  factory ScanSuggestion.fromApi(Map<String, dynamic> data) {
    final suggested = Map<String, dynamic>.from(
      data['suggested_data'] as Map? ?? const {},
    );
    final confidence = <String, double>{};
    (data['confidence'] as Map? ?? const {}).forEach((key, value) {
      if (value is num) confidence['$key'] = value.toDouble();
    });
    String? text(String key) {
      final value = suggested[key]?.toString().trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return ScanSuggestion(
      source: data['source']?.toString() ?? 'none',
      name: text('name'),
      description: text('description'),
      brand: text('brand'),
      barcode: text('barcode'),
      weightKg: (suggested['weight_kg'] as num?)?.toDouble(),
      categoryId: text('category_id'),
      subcategoryId: text('subcategory_id'),
      confidence: confidence,
    );
  }

  /// Libellé de la provenance, affiché au vendeur.
  String get sourceLabel => switch (source) {
        'asso' => 'catalogue ASSO',
        'openfoodfacts' => 'Open Food Facts',
        'openbeautyfacts' => 'Open Beauty Facts',
        'openproductsfacts' => 'Open Products Facts',
        'upcitemdb' => 'UPCitemdb',
        'rules' => 'lecture de l\'étiquette',
        _ => 'aucune source',
      };
}

/// Résultat rendu par l'écran de scan au formulaire.
class ScanResult {
  const ScanResult({required this.extraction, this.suggestion});

  final ScanExtraction extraction;

  /// Nul hors ligne ou si le serveur n'a pas répondu.
  final ScanSuggestion? suggestion;
}
