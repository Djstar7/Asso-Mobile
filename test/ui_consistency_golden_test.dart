@Tags(['golden'])
library;

import 'package:asso/app/modules/deliveryDashboard/controllers/delivery_dashboard_controller.dart';
import 'package:asso/app/modules/deliveryDashboard/models/delivery_models.dart';
import 'package:asso/app/modules/deliveryDashboard/views/delivery_dashboard_view.dart';
import 'package:asso/app/modules/orderManagement/controllers/order_management_controller.dart';
import 'package:asso/app/modules/orderManagement/models/order_model.dart';
import 'package:asso/app/modules/orderManagement/widgets/order_card.dart';
import 'package:asso/app/modules/wallet/widgets/confirm_code_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import 'helpers/themed_app.dart';

class _Delivery extends DeliveryDashboardController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Orders extends OrderManagementController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'SF-Pro',
    )..addFont(rootBundle.load('assets/fonts/SF-Pro/SF-Pro.ttf'))).load();
  });
  tearDown(Get.reset);

  Future<void> render(
    WidgetTester tester,
    Widget screen,
    String name, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(themedApp(screen, textScale: scale));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }

  for (final width in [320.0, 390.0]) {
    testWidgets('seller card at $width', (tester) async {
      Get.put<OrderManagementController>(_Orders());
      final order = OrderModel(
        id: '42',
        clientId: '8',
        clientName: 'Marie Jeanne Nguema',
        clientPhone: '+237 690 000 000',
        totalAmount: 125000,
        vendorAmount: 120000,
        status: OrderStatus.pending,
        city: 'Douala',
        address: 'Bonapriso, immeuble des Palmiers, deuxième étage',
        orderDate: DateTime(2026, 10, 25, 10),
        items: [
          OrderItem(
            productId: '1',
            productName: 'Ensemble de cuisine avec accessoires de préparation',
            quantity: 2,
            unitPrice: 62500,
            totalPrice: 125000,
          ),
        ],
      );
      await render(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('Commandes')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: OrderCard(
              order: order,
              onValidate: () {},
              onCancel: () {},
              onChat: () {},
              onContactDelivery: () {},
              onTap: () {},
            ),
          ),
        ),
        'seller_card_${width.toInt()}',
        width: width,
        scale: width == 320 ? 2 : 1,
      );
    });
  }

  testWidgets('courier work list', (tester) async {
    final c = Get.put<DeliveryDashboardController>(_Delivery());
    final request = DeliveryRequest(
      id: '12',
      orderId: '42',
      status: DeliveryStatus.inProgress,
      customerName: 'Marie Jeanne Nguema',
      customerPhone: '+237 690 000 000',
      pickupAddress: 'Boutique ASSO, Akwa',
      pickupLocation: const LatLng(4.04, 9.70),
      deliveryAddress: 'Bonapriso, immeuble des Palmiers, deuxième étage',
      deliveryLocation: const LatLng(4.02, 9.70),
      distance: 4.2,
      commission: 1500,
      requestDate: DateTime(2026, 10, 25, 10),
    );
    c.allRequests.add(request);
    c.filteredRequests.add(request);
    await render(tester, const DeliveryDashboardView(), 'courier_390');
  });

  testWidgets('confirmation success on a narrow screen with enlarged text', (
    tester,
  ) async {
    await render(
      tester,
      Scaffold(
        body: Center(
          child: ConfirmCodeSuccessDialog(
            amountLabel: '125 000 FCFA',
            onClose: () {},
          ),
        ),
      ),
      'confirmation_success_320',
      width: 320,
      scale: 2,
    );
  });
}
