import 'package:asso/app/core/widgets/app_network_image.dart';
import 'package:asso/app/core/widgets/product_image_viewer.dart';
import 'package:asso/app/modules/disputes/controllers/dispute_detail_controller.dart';
import 'package:asso/app/modules/disputes/models/dispute_models.dart';
import 'package:asso/app/modules/disputes/views/dispute_detail_view.dart';
import 'package:asso/app/modules/myOrder/controllers/my_order_controller.dart';
import 'package:asso/app/modules/myOrder/models/customer_order_models.dart';
import 'package:asso/app/modules/myOrder/views/order_control_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _DisputeController extends DisputeDetailController {
  @override
  // ignore: must_call_super
  void onInit() {
    isVendor = false;
    disputeId = 1;
  }

  @override
  String formatPrice(double value) => '$value FCFA';
}

class _Orders extends MyOrderController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  tearDown(Get.reset);
  testWidgets(
    'seller photo is below the seller reply and opens the zoom viewer',
    (tester) async {
      tester.view.physicalSize = const Size(530, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _DisputeController();
      Get.put<DisputeDetailController>(controller);
      controller.isLoading.value = false;
      controller.dispute.value = Dispute.fromMap({
        'id': 1,
        'number': 'LIT1',
        'status': 'new',
        'reason': 'damaged',
        'description': 'Réclamation client',
        'product': {'name': 'Test', 'total_price': 500},
        'attachments': [
          {'url': 'https://example.com/client.png'},
        ],
        'events': [
          {
            'label': 'Réponse du vendeur',
            'note': 'Justification vendeur',
            'actor_type': 'vendor',
            'attachments': [
              {'url': 'https://example.com/vendor.png'},
            ],
          },
        ],
      });
      await tester.pumpWidget(const GetMaterialApp(home: DisputeDetailView()));
      await tester.pump();
      final client = find.byWidgetPredicate(
        (w) => w is AppNetworkImage && w.url.endsWith('client.png'),
      );
      final vendor = find.byWidgetPredicate(
        (w) => w is AppNetworkImage && w.url.endsWith('vendor.png'),
      );
      expect(client, findsOneWidget);
      expect(vendor, findsOneWidget);
      expect(
        tester.getTopLeft(vendor).dy,
        greaterThan(
          tester.getBottomLeft(find.text('Justification vendeur')).dy,
        ),
      );
      expect(
        tester.getTopLeft(vendor).dy,
        greaterThan(tester.getTopLeft(client).dy),
      );
      await tester.tap(vendor);
      await tester.pumpAndSettle();
      expect(find.byType(ProductImageViewer), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final status in [
    'new',
    'in_review',
    'vendor_contacted',
    'replacement',
    'return',
    'refunded',
  ]) {
    testWidgets('order conformity is hidden while dispute is $status', (
      tester,
    ) async {
      Get.put<MyOrderController>(_Orders());
      final order = CustomerOrder.fromMap({
        'id': 38,
        'status': 'delivered',
        'control': {'window_open': true},
        'items': [
          {
            'id': 10,
            'product_id': 74,
            'product_name': 'Test',
            'dispute': {
              'id': 99,
              'number': 'LIT99',
              'status': status,
              'can_confirm_replacement': false,
              'can_report_replacement': false,
            },
          },
        ],
      });
      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(body: CustomerOrderControlSection(order: order)),
        ),
      );
      expect(find.text('disputes.control.conform'.tr), findsNothing);
      expect(find.text('disputes.control.title'.tr), findsNothing);
      expect(find.textContaining('LIT99'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
