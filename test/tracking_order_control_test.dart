import 'package:asso/app/data/models/delivery_info.dart';
import 'package:asso/app/modules/myOrder/controllers/my_order_controller.dart';
import 'package:asso/app/modules/myOrder/models/customer_order_models.dart';
import 'package:asso/app/modules/tracking/controllers/tracking_controller.dart';
import 'package:asso/app/modules/tracking/views/tracking_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Tracking extends TrackingController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> loadOrders({bool silent = false}) async {}

  @override
  String formatPrice(double amountXaf, {bool showSymbol = true}) =>
      '$amountXaf';
}

class _Orders extends MyOrderController {
  bool conformPressed = false;
  bool reportPressed = false;
  bool replacementConformPressed = false;
  bool replacementReportPressed = false;
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  String formatPrice(double amountXaf, {bool showSymbol = true}) =>
      '$amountXaf';

  @override
  Future<void> confirmConformity(CustomerOrder order) async {
    conformPressed = true;
  }

  @override
  Future<void> reportProblem(
    CustomerOrder order,
    CustomerOrderItem item,
  ) async {
    reportPressed = true;
  }

  @override
  Future<void> confirmReplacement(
    CustomerOrder order,
    CustomerOrderItem item,
  ) async {
    replacementConformPressed = true;
  }

  @override
  Future<void> reportReplacement(
    CustomerOrder order,
    CustomerOrderItem item,
  ) async {
    replacementReportPressed = true;
  }
}

void main() {
  testWidgets(
    'tracking sheet uses existing conformity and dispute actions after carrier handover',
    (tester) async {
      addTearDown(Get.reset);
      tester.view.physicalSize = const Size(530, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final tracking = Get.put<TrackingController>(_Tracking());
      final orders = _Orders();
      Get.put<MyOrderController>(orders);
      final data = <String, dynamic>{
        'id': 38,
        'status': 'delivered',
        'is_wholesale': true,
        'items': [
          {
            'id': 10,
            'product_id': 74,
            'product_name': 'Produit importé',
            'can_report': true,
          },
        ],
        'control': {'window_open': true, 'until': '2026-10-24T10:00:00Z'},
        'delivery': {
          'mode': 'carrier',
          'company_name': 'SOLEX',
          'tracking_status': 'delivered',
          'can_confirm_reception': true,
        },
      };
      tracking.shipments.add({
        'id': 'CMD805278',
        'orderId': 38,
        'productName': 'Produit importé',
        'productImage': '',
        'status': 'Livrée',
        'statusColor': Colors.green.toARGB32(),
        'rawStatus': 'delivered',
        'price': '1000 FCFA',
        'orderDate': '',
        'trackingSteps': <Map<String, dynamic>>[],
        'deliveryAddress': 'Bafoussam',
        'deliveryCompany': 'SOLEX',
        'delivery': DeliveryInfo.fromMap(data['delivery']),
        'customerOrder': CustomerOrder.fromMap(data),
      });
      await tester.pumpWidget(const GetMaterialApp(home: TrackingView()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('tracking.view_tracking'.tr));
      await tester.pumpAndSettle();
      expect(find.text('tracking.received_parcel'.tr), findsNothing);
      expect(find.text('disputes.control.conform'.tr), findsOneWidget);
      expect(find.text('disputes.control.report_issue'.tr), findsOneWidget);
      expect(find.text('core.delivery.tracking_pending'.tr), findsNothing);
      await tester.ensureVisible(find.text('disputes.control.conform'.tr));
      await tester.tap(find.text('disputes.control.conform'.tr));
      await tester.pump();
      expect(orders.conformPressed, isTrue);
      await tester.ensureVisible(find.text('disputes.control.report_issue'.tr));
      await tester.tap(find.text('disputes.control.report_issue'.tr));
      await tester.pump();
      expect(orders.reportPressed, isTrue);
      // La feuille ouverte doit proposer les mêmes choix après un remplacement,
      // même quand la fenêtre de contrôle de la commande initiale est fermée.
      tracking.shipments[0] = {
        ...tracking.shipments[0],
        'customerOrder': CustomerOrder.fromMap({
          ...data,
          'control': {'window_open': false},
          'items': [
            {
              'id': 10,
              'product_id': 74,
              'product_name': 'Produit remplacé',
              'dispute': {
                'id': 99,
                'number': 'LIT99',
                'status': 'replacement',
                'can_confirm_replacement': true,
                'can_report_replacement': true,
                'replacement_control_until': '2026-10-24T10:00:00Z',
              },
            },
          ],
        }),
      };
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('disputes.control.conform'.tr));
      await tester.tap(find.text('disputes.control.conform'.tr));
      await tester.pump();
      expect(orders.replacementConformPressed, isTrue);
      await tester.ensureVisible(find.text('disputes.control.report_issue'.tr));
      await tester.tap(find.text('disputes.control.report_issue'.tr));
      await tester.pump();
      expect(orders.replacementReportPressed, isTrue);

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
