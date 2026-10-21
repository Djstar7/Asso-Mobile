import 'package:asso/app/data/models/currency_model.dart';
import 'package:asso/app/data/models/diaspo_booking.dart';
import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/data/providers/diaspo_service.dart';
import 'package:asso/app/modules/diaspoList/controllers/diaspo_list_controller.dart';
import 'package:asso/app/modules/diaspoList/views/diaspo_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _SalesController extends DiaspoListController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

class _Currencies extends CurrencyService {
  @override
  // ignore: must_call_super
  Future<void> onInit() async {}

  @override
  String get displayCurrencyCode => userCurrencyRx.value?.code ?? 'XAF';

  @override
  double convertFromPivot(double amountXaf) =>
      displayCurrencyCode == 'EUR' ? amountXaf / 655.957 : amountXaf;
}

DiaspoBooking _booking(
  int id, {
  String status = 'cancelled',
  String? currency,
}) => DiaspoBooking.fromJson({
  'id': id,
  'diaspo_offer_id': id,
  'buyer_user_id': 1,
  'seller_user_id': 2,
  'kg_booked': 10,
  'price_per_kg': 10,
  'subtotal': 100,
  'commission_amount': 5,
  'total_price': 105,
  'status': status,
  'payment_status': status == 'paid' ? 'completed' : 'refunded',
  'formatted_total': '105 FCFA',
  'currency': ?currency,
  'created_at': '2026-10-01T10:00:00Z',
  'updated_at': '2026-10-01T10:00:00Z',
});

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(DiaspoService());
  });
  tearDown(Get.reset);

  for (final tab in [2, 3]) {
    testWidgets(
      'Legacy cancelled booking renders in tab $tab without a GetX error',
      (tester) async {
        Get.put<CurrencyService>(_Currencies());
        final controller = Get.put<DiaspoListController>(_SalesController());
        controller.selectedTab.value = tab;
        controller.verificationStatus.value = 'verified';
        final list = tab == 3
            ? controller.myBookingsAsSeller
            : controller.myBookingsAsBuyer;
        list.assignAll([
          _booking(1, status: 'paid', currency: 'XAF'),
          _booking(2),
        ]);

        await tester.pumpWidget(const GetMaterialApp(home: DiaspoListView()));
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.text('105 FCFA'), findsNWidgets(2));
        if (tab == 3) {
          expect(
            find.text('diaspo_list.booking.validate_code'.tr),
            findsOneWidget,
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Sales also render before the currency service is registered', (
    tester,
  ) async {
    final controller = Get.put<DiaspoListController>(_SalesController());
    controller.selectedTab.value = 3;
    controller.verificationStatus.value = 'verified';
    controller.myBookingsAsSeller.assignAll([
      _booking(1, currency: 'XAF'),
      _booking(2),
    ]);
    await tester.pumpWidget(const GetMaterialApp(home: DiaspoListView()));
    expect(find.text('105 FCFA'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Known booking currency stays reactive when the display currency changes',
    (tester) async {
      final currency = Get.put<CurrencyService>(_Currencies());
      final controller = Get.put<DiaspoListController>(_SalesController());
      controller.selectedTab.value = 3;
      controller.verificationStatus.value = 'verified';
      controller.myBookingsAsSeller.add(_booking(1, currency: 'XAF'));
      currency.userCurrencyRx.value = CurrencyModel(
        id: 1,
        code: 'EUR',
        name: 'Euro',
        symbol: '€',
        countries: const [],
      );

      await tester.pumpWidget(const GetMaterialApp(home: DiaspoListView()));
      expect(find.text('0,16 €'), findsOneWidget);
      currency.userCurrencyRx.value = CurrencyModel(
        id: 2,
        code: 'XAF',
        name: 'Franc CFA',
        symbol: 'FCFA',
        countries: const [],
      );
      await tester.pump();
      expect(find.text('105 FCFA'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
