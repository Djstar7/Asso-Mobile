import 'package:asso/app/modules/landlord/views/landlord_verification_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('missing identity files show errors beside their upload fields', (
    tester,
  ) async {
    addTearDown(Get.reset);
    await tester.pumpWidget(
      const GetMaterialApp(home: LandlordVerificationView()),
    );
    await tester.tap(find.text('landlord.verify.send'.tr));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('landlord_upload.id_front'.tr), findsOneWidget);
    expect(find.text('landlord_upload.id_back'.tr), findsOneWidget);
    expect(find.text('landlord.verify.error'.tr), findsNothing);

    await tester.ensureVisible(find.text('landlord.verify.id_passport'.tr));
    await tester.tap(find.text('landlord.verify.id_passport'.tr));
    await tester.pump();
    expect(find.text('landlord_upload.id_back'.tr), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
