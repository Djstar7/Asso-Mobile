import 'package:asso/app/data/models/pending_product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingProduct', () {
    PendingProduct sample({String status = PendingProductStatus.pending}) =>
        PendingProduct(
          id: 'abc',
          userId: 7,
          createdAt: DateTime(2026, 9, 28, 11, 33),
          fields: {'name': 'Pagne wax', 'price': '15000', 'currency': 'XAF'},
          imagePaths: ['/data/offline_products/abc/0.jpg'],
          status: status,
          error: status == PendingProductStatus.failed ? 'Refusé' : null,
          attempts: 2,
        );

    test('se relit à l\'identique depuis Hive', () {
      final copy = PendingProduct.fromJson(sample().toJson())!;
      expect(copy.id, 'abc');
      expect(copy.userId, 7);
      expect(copy.createdAt, DateTime(2026, 9, 28, 11, 33));
      expect(copy.fields['price'], '15000');
      expect(copy.imagePaths, ['/data/offline_products/abc/0.jpg']);
      expect(copy.attempts, 2);
      expect(copy.status, PendingProductStatus.pending);
    });

    test('un envoi interrompu repart en attente', () {
      final copy = PendingProduct.fromJson(
        sample(status: PendingProductStatus.syncing).toJson(),
      )!;
      expect(copy.status, PendingProductStatus.pending);
    });

    test('un refus garde son motif', () {
      final copy = PendingProduct.fromJson(
        sample(status: PendingProductStatus.failed).toJson(),
      )!;
      expect(copy.isFailed, isTrue);
      expect(copy.error, 'Refusé');
    });

    test('une entrée illisible est ignorée', () {
      expect(PendingProduct.fromJson({'id': 'x'}), isNull);
    });

    test('nom de repli', () {
      final item = PendingProduct.fromJson(
        {...sample().toJson(), 'fields': {'name': '  '}},
      )!;
      expect(item.name, 'Produit sans nom');
    });
  });
}
