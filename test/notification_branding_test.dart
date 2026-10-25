import 'package:asso/app/core/models/notification_model.dart';
import 'package:asso/app/modules/notification/controllers/notification_controller.dart';
import 'package:asso/app/modules/notification/views/notification_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Notifications extends NotificationController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  tearDown(Get.reset);
  testWidgets('inbox rows display the ASSO logo with a category badge', (
    tester,
  ) async {
    final controller = _Notifications();
    Get.put<NotificationController>(controller);
    controller.notifications.add(
      NotificationModel(
        id: 1,
        userId: 1,
        title: 'Résumé ASSO',
        body: 'Nouveautés',
        type: 'marketing_digest',
        isRead: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: NotificationView()));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/images/logo.png',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
  });
}
