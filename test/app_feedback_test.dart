import 'package:asso/app/core/utils/app_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets(
    'duplicate failures share one notification and can be retried after dismissal',
    (tester) async {
      await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
      final first = AppFeedback.show('Erreur', 'Échec de la réservation');
      final duplicate = AppFeedback.show('Erreur', 'Échec de la réservation');
      expect(identical(first, duplicate), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Échec de la réservation'), findsOneWidget);
      first.close();
      await tester.pumpAndSettle();
      final retry = AppFeedback.show('Erreur', 'Échec de la réservation');
      expect(identical(first, retry), isFalse);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Échec de la réservation'), findsOneWidget);
      retry.close();
      await tester.pumpAndSettle();
    },
  );
}
