import 'package:asso/app/modules/myOrder/controllers/my_order_controller.dart';
import 'package:asso/app/modules/myOrder/models/customer_order_models.dart';
import 'package:asso/app/modules/myOrder/views/order_delivery_section.dart';
import 'package:asso/app/modules/myOrder/views/order_control_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _HandoverController extends MyOrderController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  String formatPrice(double amountXaf, {bool showSymbol = true}) =>
      '$amountXaf';
}

void main() {
  for (final handedOver in [false, true]) {
    testWidgets(
      'carrier customer sees handover code or quality controls ($handedOver)',
      (tester) async {
        addTearDown(Get.reset);
        Get.put<MyOrderController>(_HandoverController());
        final order = CustomerOrder.fromMap({
          'id': 38,
          'status': handedOver ? 'delivered' : 'shipped',
          'confirmation_code': handedOver ? null : '123456',
          'items': [
            {
              'id': 1,
              'product_id': 1,
              'product_name': 'Produit',
              'can_report': handedOver,
            },
          ],
          'control': {
            'window_open': handedOver,
            'until': '2026-10-24T10:00:00Z',
          },
          'delivery': {
            'mode': 'carrier',
            'company_name': 'SOLEX',
            'tracking_status': handedOver ? 'delivered' : 'pickup_accepted',
            'can_confirm_reception': handedOver,
          },
        });
        await tester.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    CustomerOrderDeliverySection(order: order),
                    CustomerOrderControlSection(order: order),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (handedOver) {
          expect(find.text('123456'), findsNothing);
          expect(find.text('my_order.delivery.received'.tr), findsNothing);
          expect(find.text('disputes.control.conform'.tr), findsOneWidget);
          expect(find.text('disputes.control.report_issue'.tr), findsOneWidget);
        } else {
          expect(find.text('123456'), findsOneWidget);
          expect(find.text('tracking.code_hint'.tr), findsOneWidget);
          expect(find.text('my_order.delivery.received'.tr), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
