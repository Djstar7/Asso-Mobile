import 'package:asso/app/core/widgets/segmented_tabs.dart';
import 'package:asso/app/data/models/diaspo_offer.dart';
import 'package:asso/app/data/models/maritime.dart';
import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/data/providers/diaspo_service.dart';
import 'package:asso/app/data/providers/maritime_service.dart';
import 'package:asso/app/modules/diaspoList/controllers/diaspo_list_controller.dart';
import 'package:asso/app/modules/diaspoList/views/diaspo_list_view.dart';
import 'package:asso/app/modules/maritime/controllers/maritime_controller.dart';
import 'package:asso/app/modules/maritime/views/maritime_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class _DiaspoController extends DiaspoListController {
  int refreshes = 0;
  int paginations = 0;
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> refresh() async {
    refreshes++;
  }

  @override
  void loadMore() {
    paginations++;
  }

  @override
  Future<void> loadMyBookingsAsBuyer() async {}
}

class _FreightController extends MaritimeController {
  int bookingLoads = 0;
  @override
  Future<void> loadMyBookings() async {
    bookingLoads++;
  }

  String? requestedMode;
  MaritimeDeparture? openedDeparture;
  int refreshes = 0;
  int paginations = 0;
  @override
  void ensureLoaded({String transportMode = 'sea'}) {
    requestedMode = transportMode;
  }

  @override
  void openDeparture(MaritimeDeparture departure) {
    openedDeparture = departure;
  }

  @override
  Future<void> loadDepartures() async {
    refreshes++;
  }

  @override
  Future<void> loadMore() async {
    paginations++;
  }
}

MaritimeDeparture _departure(int id, String mode, String city) =>
    MaritimeDeparture.fromJson({
      'id': id,
      'transport_mode': mode,
      'departure_date': '2026-12-01',
      'booking_closes_on': '2026-11-24',
      'dropoff_deadline': '2026-11-27',
      'days_left_to_book': 30,
      'is_bookable': true,
      'remaining_kg': 100,
      'price_per_kg': 20000,
      'currency': 'XAF',
      'partner_name': 'PRIVATE PARTNER',
      'origin_hub': {
        'id': id,
        'country': mode == 'air' ? 'CN' : 'FR',
        'city': city,
      },
      'destination_hub': {'id': id + 10, 'country': 'CM', 'city': 'Douala'},
    });

DiaspoOffer _offer() => DiaspoOffer.fromJson({
  'id': 10,
  'user_id': 20,
  'status': 'approved',
  'verification_status': 'verified',
  'departure_country': 'FR',
  'departure_city': 'Lyon',
  'departure_datetime': '2026-11-01T10:00:00Z',
  'arrival_country': 'CM',
  'arrival_city': 'Yaoundé',
  'arrival_datetime': '2026-11-02T10:00:00Z',
  'price_per_kg': 10000,
  'available_kg': 20,
  'remaining_kg': 20,
  'currency': 'XAF',
  'created_at': '2026-10-01T10:00:00Z',
  'updated_at': '2026-10-01T10:00:00Z',
});

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    await GetStorage.init();
  });

  testWidgets('Fully booked offers are not labelled published', (tester) async {
    Get.testMode = true;
    addTearDown(Get.reset);
    Get.put(DiaspoService());
    Get.put(CurrencyService());
    final diaspo = Get.put<DiaspoListController>(_DiaspoController());
    diaspo.selectedTab.value = 1;
    diaspo.verificationStatus.value = 'verified';
    final fullOffer = _offer().copyWith(
      departureDateTime: DateTime.now().add(const Duration(days: 7)),
      remainingKg: 0,
    );
    diaspo.myOffers.add(fullOffer);
    await tester.pumpWidget(const GetMaterialApp(home: DiaspoListView()));
    expect(find.text('diaspo_list.status_badge.full'.tr), findsOneWidget);
    expect(find.text('diaspo_list.status_badge.published'.tr), findsNothing);

    diaspo.myOffers.assignAll([fullOffer.copyWith(remainingKg: 5)]);
    await tester.pump();
    expect(find.text('diaspo_list.status_badge.full'.tr), findsNothing);
    expect(find.text('diaspo_list.status_badge.published'.tr), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Past departures are explained in My Offers', (tester) async {
    Get.testMode = true;
    addTearDown(Get.reset);
    Get.put(DiaspoService());
    Get.put(CurrencyService());
    final diaspo = Get.put<DiaspoListController>(_DiaspoController());
    diaspo.selectedTab.value = 1;
    diaspo.verificationStatus.value = 'verified';
    diaspo.myOffers.add(
      _offer().copyWith(
        departureDateTime: DateTime.now().subtract(const Duration(days: 1)),
      ),
    );
    await tester.pumpWidget(const GetMaterialApp(home: DiaspoListView()));
    expect(find.text('diaspo_list.status_badge.expired'.tr), findsOneWidget);
    expect(find.text('diaspo_list.status_badge.published'.tr), findsNothing);
    diaspo.myOffers.assignAll([
      _offer().copyWith(
        verificationStatus: 'pending',
        departureDateTime: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
    await tester.pump();
    expect(find.text('diaspo_list.status_badge.expired'.tr), findsOneWidget);
    expect(find.text('diaspo_list.status_badge.unverified'.tr), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Avion mixes both offers in the existing list without a source selector',
    (tester) async {
      Get.testMode = true;
      addTearDown(Get.reset);
      Get.put(DiaspoService());
      Get.put(MaritimeService());
      Get.put(CurrencyService());
      final diaspo =
          Get.put<DiaspoListController>(_DiaspoController())
              as _DiaspoController;
      diaspo.verificationStatus.value = 'verified';
      diaspo.offers.add(_offer());
      final freight = _FreightController();
      freight.departures.assignAll([
        _departure(1, 'air', 'Guangzhou'),
        _departure(2, 'sea', 'Paris'),
      ]);
      Get.put<MaritimeController>(freight);
      await tester.pumpWidget(const GetMaterialApp(home: DiaspoListView()));
      final topTabs = tester.widget<SegmentedTabs>(
        find.byType(SegmentedTabs).first,
      );
      expect(topTabs.tabs.map((tab) => tab.label), [
        'diaspo_list.mode.air'.tr,
        'diaspo_list.mode.sea'.tr,
      ]);
      expect(find.text('partner_freight.air_travellers'.tr), findsNothing);
      expect(find.text('partner_freight.air_partners'.tr), findsNothing);
      expect(find.byType(MaritimeSection), findsNothing);
      expect(freight.requestedMode, 'air');
      expect(find.textContaining('Lyon'), findsOneWidget);
      expect(find.textContaining('Guangzhou'), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining('Lyon')).dy,
        lessThan(tester.getTopLeft(find.textContaining('Guangzhou')).dy),
      );
      expect(find.textContaining('Paris'), findsNothing);
      expect(find.textContaining('PRIVATE PARTNER'), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.tap(find.textContaining('Guangzhou'));
      expect(freight.openedDeparture?.id, 1);
      await tester.enterText(find.byType(TextField), 'Guangzhou');
      await tester.pump();
      expect(find.textContaining('Lyon'), findsNothing);
      expect(
        find.textContaining('Guangzhou', findRichText: true),
        findsNWidgets(2),
      );
      await tester.enterText(find.byType(TextField), 'Lyon');
      await tester.pump();
      expect(find.textContaining('Guangzhou'), findsNothing);
      expect(find.textContaining('Lyon'), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      expect(diaspo.refreshes, 1);
      expect(freight.refreshes, 1);
      await tester.drag(find.byType(ListView).last, const Offset(0, -300));
      await tester.pump();
      expect(diaspo.paginations, greaterThan(0));
      expect(freight.paginations, greaterThan(0));
      await tester.tap(find.text('diaspo_list.mode.sea'.tr));
      await tester.pump();
      expect(freight.requestedMode, 'sea');
      expect(find.text('Paris → Douala'), findsOneWidget);
      expect(find.textContaining('Lyon'), findsNothing);
      await tester.tap(find.text('diaspo_list.mode.air'.tr));
      await tester.pump();
      expect(freight.requestedMode, 'air');
      expect(find.byType(MaritimeSection), findsNothing);
      diaspo.offers.clear();
      freight.isLoading.value = true;
      await tester.pump();
      expect(find.textContaining('Guangzhou'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      freight.isLoading.value = false;
      diaspo.offers.add(_offer());
      freight.departures.clear();
      freight.error.value = 'offline';
      await tester.pump();
      expect(find.textContaining('Lyon'), findsOneWidget);
      expect(find.text('offline'), findsNothing);
      diaspo.changeTab(2);
      freight.isLoadingBookings.value = true;
      await tester.pump();
      expect(freight.bookingLoads, 1);
      expect(find.text('diaspo_list.empty.no_purchases'.tr), findsNothing);
      freight.isLoadingBookings.value = false;
      freight.myBookings.assignAll([
        for (final mode in ['air', 'sea'])
          MaritimeBooking.fromJson({
            'id': mode == 'air' ? 1 : 2,
            'status': 'completed',
            'departure': {
              'id': mode == 'air' ? 1 : 2,
              'transport_mode': mode,
              'departure_date': '2026-12-01',
              'origin_hub': {
                'id': 1,
                'city': mode == 'air' ? 'Guangzhou' : 'Paris',
              },
              'destination_hub': {'id': 2, 'city': 'Douala'},
            },
          }),
      ]);
      await tester.pump();
      expect(find.text('Guangzhou → Douala'), findsOneWidget);
      expect(find.text('Paris → Douala'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
