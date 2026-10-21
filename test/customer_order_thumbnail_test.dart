import 'package:asso/app/core/widgets/app_network_image.dart';
import 'package:asso/app/modules/myOrder/controllers/my_order_controller.dart';
import 'package:asso/app/modules/myOrder/models/customer_order_models.dart';
import 'package:asso/app/modules/myOrder/views/my_order_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _OrdersController extends MyOrderController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  String formatPrice(double amountXaf, {bool showSymbol = true}) =>
      '$amountXaf FCFA';
}

void main() {
  testWidgets(
    'Order items show their product photo with a fallback when absent',
    (tester) async {
      addTearDown(Get.reset);
      tester.view.physicalSize = const Size(530, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = Get.put<MyOrderController>(_OrdersController());
      controller.filteredOrders.add(
        CustomerOrder.fromMap({
          'id': 1,
          'status': 'cancelled',
          'delivery_address': 'Douala',
          'created_at': '2026-10-21T10:00:00Z',
          'items': [
            {
              'id': 1,
              'product_id': 1,
              'product_name': 'Ventilateur',
              'product_image': 'https://example.com/fan.jpg',
            },
            {'id': 2, 'product_id': 2, 'product_name': 'Chaise'},
          ],
        }),
      );

      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: MyOrderList())),
      );
      final photo = tester.widget<AppNetworkImage>(
        find.byType(AppNetworkImage),
      );
      expect(photo.url, 'https://example.com/fan.jpg');
      expect(photo.decodeSize, const Size(50, 50));
      expect(find.byIcon(Icons.shopping_bag), findsWidgets);
      expect(find.text('Ventilateur'), findsOneWidget);
      expect(find.text('Chaise'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
