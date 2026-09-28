import 'package:asso/app/core/widgets/free_delivery_widgets.dart';
import 'package:asso/app/data/models/delivery_info.dart';
import 'package:asso/app/modules/product/controllers/product_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Livraison gratuite offerte par le vendeur : prix affiché barré, jamais
/// ajouté au total payé par l'acheteur.
void main() {
  final product = <String, dynamic>{'id': 1, 'price': 10000, 'stock': 5};

  test('une course offerte reste affichée mais n\'est pas payée', () {
    const free = DeliveryPartnerQuote({
      'delivery_price': 2200,
      'free_delivery': true,
    });
    const paid = DeliveryPartnerQuote({'delivery_price': 2200});

    expect(free.isFree, isTrue);
    expect(free.price, 2200);
    expect(free.buyerPrice, 0);
    expect(paid.isFree, isFalse);
    expect(paid.buyerPrice, 2200);
  });

  test('le total de la commande exclut la course offerte', () {
    final controller = ProductController();

    controller.selectPartner({'delivery_price': 2200, 'free_delivery': true});
    expect(controller.deliveryIsFree, isTrue);
    expect(controller.deliveryPrice.value, 2200);
    expect(controller.orderTotal(product), controller.orderSubtotal(product));

    controller.selectPartner({'delivery_price': 2200});
    expect(controller.deliveryIsFree, isFalse);
    expect(
      controller.orderTotal(product),
      controller.orderSubtotal(product) + 2200,
    );
  });

  testWidgets('le prix offert est barré et suivi de « Offerte »', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DeliveryPriceText(price: '2 200 FCFA', isFree: true),
        ),
      ),
    );

    final price = tester.widget<Text>(find.text('2 200 FCFA'));
    expect(price.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('Offerte'), findsOneWidget);
  });

  test('le drapeau de l\'API est lu quel que soit son format', () {
    expect(readFreeDelivery(true), isTrue);
    expect(readFreeDelivery(1), isTrue);
    expect(readFreeDelivery('true'), isTrue);
    expect(readFreeDelivery(null), isFalse);
    expect(readFreeDelivery(0), isFalse);
  });
}
