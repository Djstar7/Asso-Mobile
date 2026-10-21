import 'package:asso/app/modules/deliveryDashboard/controllers/delivery_dashboard_controller.dart';
import 'package:asso/app/modules/deliveryDashboard/models/delivery_models.dart';
import 'package:asso/app/modules/deliveryDashboard/views/delivery_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _DashboardController extends DeliveryDashboardController {
  // Tester la mise en page sans démarrer le GPS ni les appels réseau.
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  for (final (width, scale) in [
    (360.0, 1.0),
    (530.0, 1.0),
    (800.0, 1.0),
    (530.0, 3.0),
  ]) {
    testWidgets(
      'delivery filters remain readable at width $width and text scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(Get.reset);
        final controller = Get.put<DeliveryDashboardController>(
          _DashboardController(),
        );
        await tester.pumpWidget(
          GetMaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const DeliveryDashboardView(),
          ),
        );

        for (final label in [
          'Tout',
          'En attente',
          'En cours',
          'Livrés',
          'Annulés',
        ]) {
          final text = find.text(label);
          expect(text, findsOneWidget);
          expect(tester.getSize(text).height, greaterThanOrEqualTo(12));
        }
        await tester.ensureVisible(find.text('En cours'));
        await tester.tap(find.text('En cours'));
        await tester.pump();
        expect(controller.selectedStatus.value, DeliveryStatus.inProgress);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
