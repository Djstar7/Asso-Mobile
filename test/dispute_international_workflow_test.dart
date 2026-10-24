import 'package:asso/app/modules/disputes/controllers/dispute_detail_controller.dart';
import 'package:asso/app/modules/disputes/models/dispute_models.dart';
import 'package:asso/app/modules/disputes/views/dispute_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _VendorController extends DisputeDetailController {
  @override
  // ignore: must_call_super
  void onInit() {
    isVendor = true;
    disputeId = 1;
  }

  @override
  String formatPrice(double value) => '$value FCFA';
}

void main() {
  tearDown(Get.reset);
  for (final exchange in [true, false]) {
    testWidgets('receipt dialog distinguishes exchange from refund ($exchange)', (tester) async {
      final controller = Get.put<DisputeDetailController>(_VendorController());
      controller.isLoading.value = false;
      controller.dispute.value = Dispute.fromMap({
        'id': 1, 'number': 'LIT1', 'status': exchange ? 'replacement' : 'return',
        'product': {'name': 'Produit', 'quantity': 1, 'total_price': 158},
        'actions': {'confirm_return_received': true, 'receipt_shipment_id': 10},
        exchange ? 'collection' : 'return': {
          'id': 10, 'type': exchange ? 'collection' : 'return',
          'international': true, 'status': 'delivered_to_vendor', 'payment_status': 'paid',
        },
      });
      await tester.pumpWidget(const GetMaterialApp(home: DisputeDetailView()));
      await tester.pumpAndSettle();
      final label = exchange ? 'disputes.vendor.confirm_exchange_received' : 'disputes.vendor.confirm_received';
      await tester.tap(find.text(label.tr));
      await tester.pumpAndSettle();
      expect(find.text((exchange ? 'disputes.vendor.received_exchange_confirm' : 'disputes.vendor.received_confirm').tr), findsOneWidget);
      expect(find.text((exchange ? 'disputes.vendor.received_confirm' : 'disputes.vendor.received_exchange_confirm').tr), findsNothing);
      await tester.tap(find.text('common.cancel'.tr));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final receipt in [true, false]) {
    testWidgets('international seller has the correct receipt or preparation action ($receipt)', (tester) async {
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = Get.put<DisputeDetailController>(_VendorController());
      controller.isLoading.value = false;
      controller.dispute.value = Dispute.fromMap({
        'id': 1, 'number': 'LIT1', 'status': 'replacement', 'decision': 'founded',
        'product': {'name': 'Produit international', 'quantity': 1, 'total_price': 1100},
        'actions': {
          'confirm_return_received': receipt,
          'receipt_shipment_id': receipt ? 10 : null,
          'prepare_replacement': !receipt,
          'pay_shipment': false,
        },
        receipt ? 'collection' : 'replacement': {
          'id': 10, 'type': receipt ? 'collection' : 'replacement',
          'international': true, 'company_name': 'DHL Express',
          'status': receipt ? 'delivered_to_vendor' : 'awaiting_preparation',
          'payer': 'vendor', 'payment_status': receipt ? 'paid' : 'pending',
          'status_label': receipt ? 'Produit remis au vendeur' : 'Remplacement à préparer',
          'price': 6000,
          'breakdown': {
            'legs': [
              {'label': 'DHL Express → Solex', 'price': 5000},
              {'label': 'Solex → vendeur', 'price': 1000},
            ],
          },
        },
      });
      await tester.pumpWidget(const GetMaterialApp(home: DisputeDetailView()));
      await tester.pumpAndSettle();
      expect(find.text((receipt ? 'disputes.vendor.confirm_exchange_received' : 'disputes.vendor.prepare_replacement').tr), findsOneWidget);
      expect(find.text((receipt ? 'disputes.vendor.prepare_replacement' : 'disputes.vendor.confirm_exchange_received').tr), findsNothing);
      expect(find.text('disputes.vendor.pay_shipment'.tr), findsNothing);
      expect(find.text('DHL Express → Solex'), findsOneWidget);
      expect(find.text('Solex → vendeur'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
