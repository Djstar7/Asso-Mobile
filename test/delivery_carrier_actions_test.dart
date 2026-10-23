import 'package:asso/app/modules/deliveryDashboard/controllers/delivery_dashboard_controller.dart';
import 'package:asso/app/modules/deliveryDashboard/models/delivery_models.dart';
import 'package:asso/app/modules/deliveryDashboard/views/delivery_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

class _CarrierDashboard extends DeliveryDashboardController {
  String? recordedStep;

  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Future<void> advanceCarrier(DeliveryRequest request, String step) async {
    recordedStep = step;
  }
}

void main() {
  for (final distance in <double?>[178.2, null]) {
    testWidgets('carrier mission actions and distance display ($distance)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(530, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(Get.reset);
      final controller = _CarrierDashboard();
      Get.put<DeliveryDashboardController>(controller);
      final request = DeliveryRequest(
        id: '12',
        orderId: '12',
        status: DeliveryStatus.inProgress,
        customerName: 'Client',
        customerPhone: '',
        pickupAddress: 'ASSO Import Douala',
        pickupLocation: const LatLng(4.04, 9.70),
        deliveryAddress: 'Bafoussam',
        deliveryLocation: const LatLng(5.48, 10.40),
        distance: distance,
        distanceType: 'straight_line',
        commission: 0,
        requestDate: DateTime.now(),
        carrierManaged: true,
        canComplete: false,
        carrierSteps: const [
          {
            'key': 'collected_by_carrier',
            'label': 'Récupérer le colis chez ASSO',
          },
        ],
      );
      controller.allRequests.add(request);
      controller.filteredRequests.add(request);
      await tester.pumpWidget(
        const GetMaterialApp(home: DeliveryDashboardView()),
      );
      expect(
        find.textContaining(
          distance == null
              ? 'delivery_dashboard.distance_unavailable'.tr
              : '178.2 km',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('0.0 km'), findsNothing);
      final action = find.text('Récupérer le colis chez ASSO');
      await tester.scrollUntilVisible(
        action,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(action);
      await tester.pump();
      expect(controller.recordedStep, 'collected_by_carrier');
      final complete = find.widgetWithText(
        ElevatedButton,
        'delivery_dashboard.actions.delivered'.tr,
      );
      expect(complete, findsOneWidget);
      expect(tester.widget<ElevatedButton>(complete).onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
