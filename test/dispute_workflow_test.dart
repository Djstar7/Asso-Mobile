import 'package:asso/app/modules/disputes/models/dispute_models.dart';
import 'package:asso/app/modules/import/widgets/wholesale_delivery.dart';
import 'package:asso/app/modules/myOrder/controllers/my_order_controller.dart';
import 'package:asso/app/modules/myOrder/models/customer_order_models.dart';
import 'package:asso/app/modules/myOrder/views/order_control_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(() => Get.reset());

  testWidgets(
    'replacement buttons remain visible after the initial order window closes',
    (tester) async {
      Get.put(MyOrderController());
      final order = CustomerOrder.fromMap({
        'id': 1,
        'status': 'delivered',
        'control': {'window_open': false, 'validated': true},
        'items': [
          {
            'id': 2,
            'quantity': 1,
            'product': {'name': 'Produit ASSO'},
            'dispute': {
              'id': 3,
              'number': 'LIT123',
              'status': 'replacement',
              'can_confirm_replacement': true,
              'can_report_replacement': true,
              'replacement_control_until': DateTime.now()
                  .add(const Duration(hours: 48))
                  .toIso8601String(),
            },
          },
        ],
      });
      expect(order.items.single.dispute!.inReplacementControl, isTrue);
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: CustomerOrderControlSection(order: order)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('disputes.control.conform'.tr), findsOneWidget);
      expect(find.text('disputes.control.report_issue'.tr), findsOneWidget);
      expect(find.byIcon(Icons.report_problem_outlined), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('server replacement permissions do not depend on the device clock', () {
    final ref = OrderItemDisputeRef.fromMap({
      'id': 1,
      'number': 'LIT1',
      'status': 'replacement',
      'replacement_control_until': '2020-01-01T00:00:00Z',
      'can_confirm_replacement': true,
      'can_report_replacement': true,
    });
    expect(ref!.inReplacementControl, isTrue);
  });

  test(
    'manual grossist address is sufficient and editing it invalidates the selected quote',
    () {
      final delivery = WholesaleDelivery(
        items: () => [
          {'product_id': 1, 'quantity': 50},
        ],
      );
      delivery.cityController.text = 'Douala';
      delivery.quarterController.text = 'Makèpè';
      delivery.addressController.text = 'Rue 123, près du marché';
      delivery.editAddress();
      expect(delivery.hasLocation, isTrue);
      expect(delivery.latitude, isNull);
      delivery.select({'company_id': 1, 'delivery_price': 1000});
      expect(delivery.selected, isNotNull);
      delivery.addressController.text = 'Autre adresse';
      delivery.editAddress();
      expect(delivery.selected, isNull);
      delivery.dispose();
    },
  );
}
