import 'package:asso/app/data/providers/diaspo_service.dart';
import 'package:asso/app/modules/diaspoEdit/controllers/diaspo_edit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(DiaspoService());
  });
  tearDown(Get.reset);

  Future<void> showPicker(
    WidgetTester tester,
    Future<void> Function(BuildContext) open,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: TextButton(
            onPressed: () => open(context),
            child: const Text('Choose date'),
          ),
        );
      }),
    ));
    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  }

  testWidgets('A past departure can be replaced by a current date', (tester) async {
    final controller = DiaspoEditController();
    addTearDown(controller.onClose);
    controller.departureDateTime.value = DateTime.now().subtract(
      const Duration(days: 60),
    );

    await showPicker(tester, controller.pickDepartureDate);
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.initialDate, DateUtils.dateOnly(DateTime.now()));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      DateUtils.dateOnly(controller.departureDateTime.value!),
      DateUtils.dateOnly(DateTime.now()),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arrival calendar opens after rescheduling departure', (tester) async {
    final controller = DiaspoEditController();
    addTearDown(controller.onClose);
    final departure = DateTime.now().add(const Duration(days: 10));
    final oldArrival = DateTime.now().subtract(const Duration(days: 30));
    controller.departureDateTime.value = departure;
    controller.arrivalDateTime.value = oldArrival;

    await showPicker(tester, controller.pickArrivalDate);
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.initialDate, DateUtils.dateOnly(departure));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.arrivalDateTime.value, oldArrival);
  });

  testWidgets('Past arrival and departure do not open a past calendar', (tester) async {
    final controller = DiaspoEditController();
    addTearDown(controller.onClose);
    controller.departureDateTime.value = DateTime.now().subtract(
      const Duration(days: 60),
    );
    controller.arrivalDateTime.value = DateTime.now().subtract(
      const Duration(days: 59),
    );

    await showPicker(tester, controller.pickArrivalDate);
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.firstDate, DateUtils.dateOnly(DateTime.now()));
    expect(picker.initialDate, picker.firstDate);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Arrival beyond the calendar range still opens', (tester) async {
    final controller = DiaspoEditController();
    addTearDown(controller.onClose);
    controller.departureDateTime.value = DateTime.now().add(
      const Duration(days: 1),
    );
    controller.arrivalDateTime.value = DateTime.now().add(
      const Duration(days: 90),
    );

    await showPicker(tester, controller.pickArrivalDate);
    final picker = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(picker.initialDate, picker.lastDate);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
