import 'package:asso/app/data/models/scan_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le corps envoyé respecte les limites du serveur', () {
    final extraction = ScanExtraction(
      imagePath: '/tmp/photo.jpg',
      barcode: '3017620422003',
      barcodeFormat: 'ean13',
      ocrText: 'x' * 6000,
      ocrLines: List.generate(250, (i) => 'ligne $i ${'y' * 400}'),
      labels: List.generate(30, (i) => (text: 'Food', confidence: 0.9)),
    );

    final payload = extraction.toPayload();

    expect(payload['barcode'], '3017620422003');
    expect(payload['barcode_format'], 'ean13');
    expect((payload['ocr_text'] as String).length, 5000);
    expect(payload['ocr_lines'], hasLength(200));
    expect((payload['ocr_lines'] as List).first, hasLength(300));
    expect(payload['labels'], hasLength(20));
    expect((payload['labels'] as List).first,
        {'text': 'Food', 'confidence': 0.9});
    expect(payload.containsKey('image'), isFalse);
  });

  test('rien de lu : extraction vide, champs absents du corps', () {
    const extraction = ScanExtraction(imagePath: '/tmp/photo.jpg');

    expect(extraction.isEmpty, isTrue);
    final payload = extraction.toPayload();
    expect(payload.containsKey('barcode'), isFalse);
    expect(payload.containsKey('ocr_text'), isFalse);
  });

  test('le code vu en direct remplace celui de la capture', () {
    const extraction = ScanExtraction(imagePath: '/tmp/p.jpg', ocrText: 'Nido');
    final merged = extraction.copyWith(barcode: '96385074', barcodeFormat: 'ean8');

    expect(merged.barcode, '96385074');
    expect(merged.ocrText, 'Nido');
    expect(merged.isEmpty, isFalse);
  });

  test('réponse du serveur lue avec identifiants et confiances', () {
    final suggestion = ScanSuggestion.fromApi({
      'source': 'openfoodfacts',
      'suggested_data': {
        'name': 'Nutella 400 g',
        'description': 'Pâte à tartiner.',
        'brand': 'Nutella',
        'barcode': '3017620422003',
        'weight_kg': 0.4,
        'category_id': 8,
        'subcategory_id': 49,
      },
      'confidence': {'name': 0.9, 'category': 0.72, 'weight': 1},
    });

    expect(suggestion.isEmpty, isFalse);
    expect(suggestion.name, 'Nutella 400 g');
    expect(suggestion.weightKg, 0.4);
    expect(suggestion.categoryId, '8');
    expect(suggestion.subcategoryId, '49');
    expect(suggestion.confidenceOf('name'), 0.9);
    expect(suggestion.confidenceOf('weight'), 1.0);
    expect(suggestion.confidenceOf('brand'), 0);
    expect(suggestion.sourceLabel, 'Open Food Facts');
  });

  test('réponse vide du serveur', () {
    final suggestion = ScanSuggestion.fromApi({
      'source': 'none',
      'suggested_data': {'name': null, 'description': '  ', 'category_id': null},
    });

    expect(suggestion.isEmpty, isTrue);
    expect(suggestion.name, isNull);
    expect(suggestion.description, isNull);
    expect(suggestion.categoryId, isNull);
  });
}
