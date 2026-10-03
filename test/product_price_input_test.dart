import 'package:asso/app/data/services/offline_product_sync_service.dart';
import 'package:asso/app/modules/addProduct/controllers/add_product_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prix saisi', () {
    test('virgule, point et espaces acceptés', () {
      expect(AddProductController.parsePrice('15000'), 15000);
      expect(AddProductController.parsePrice('15 000'), 15000);
      expect(AddProductController.parsePrice('15 000'), 15000);
      expect(AddProductController.parsePrice('1500,50'), 1500.5);
      expect(AddProductController.parsePrice(' 9.99 '), 9.99);
    });

    test('saisie illisible refusée au lieu de partir à 0', () {
      expect(AddProductController.parsePrice(''), isNull);
      expect(AddProductController.parsePrice('1,500,00'), isNull);
      expect(AddProductController.parsePrice('12.345'), isNull);
      expect(AddProductController.parsePrice('-5'), isNull);
      expect(AddProductController.parsePrice('abc'), isNull);
    });

    test('envoyé sans arrondir les centimes', () {
      expect(AddProductController.formatPriceForApi(15000), '15000');
      expect(AddProductController.formatPriceForApi(9.99), '9.99');
      expect(AddProductController.formatPriceForApi(1500.5), '1500.50');
    });
  });

  test('chaque création a sa propre référence', () {
    final references = {
      for (var i = 0; i < 50; i++) OfflineProductSyncService.newReference(),
    };
    expect(references, hasLength(50));
    expect(references.every((r) => r.length <= 64), isTrue);
  });
}
