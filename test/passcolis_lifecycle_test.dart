import 'dart:io';

import 'package:asso/app/data/models/maritime.dart';
import 'package:asso/app/data/models/parcel_nature.dart';
import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/data/providers/diaspo_service.dart';
import 'package:asso/app/data/providers/maritime_service.dart';
import 'package:asso/app/modules/diaspoList/controllers/diaspo_list_controller.dart';
import 'package:asso/app/modules/diaspoList/views/diaspo_list_view.dart';
import 'package:asso/app/modules/diaspoList/views/passcolis_section.dart';
import 'package:asso/app/modules/inventoryList/bindings/inventory_list_binding.dart';
import 'package:asso/app/modules/inventoryList/controllers/inventory_list_controller.dart';
import 'package:asso/app/modules/maritime/controllers/maritime_controller.dart';
import 'package:asso/app/modules/maritime/views/maritime_section.dart';
import 'package:asso/app/modules/storeManagement/controllers/store_management_controller.dart';
import 'package:asso/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'helpers/themed_app.dart';

class _DiaspoService extends DiaspoService {
  @override
  Future<Map<String, dynamic>> getVerificationStatus() async => {
    'success': true,
    'data': {'verification_status': 'verified', 'can_create_offers': true},
  };

  @override
  Future<Map<String, dynamic>> getOffers({
    String? departureCountry,
    String? arrivalCountry,
    String? departureCity,
    String? arrivalCity,
    String? minDate,
    String? maxDate,
    double? maxPrice,
    int page = 1,
    int perPage = 20,
  }) async => {
    'success': true,
    'data': {'data': [], 'current_page': 1, 'last_page': 1},
  };

  @override
  Future<({List<ParcelNature> natures, double airMaxKgHint})>
  getParcelNatures() async => (natures: <ParcelNature>[], airMaxKgHint: 23.0);
}

class _MaritimeService extends MaritimeService {
  @override
  Future<({List<MaritimeDeparture> items, int lastPage})> getDepartures({
    int page = 1,
    String? originCountry,
    String? transportMode,
    String? destinationCountry,
  }) async => (items: <MaritimeDeparture>[], lastPage: 1);
}

class _StoreController extends StoreManagementController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  late Directory storage;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storage = await Directory.systemTemp.createTemp(
      'asso-passcolis-lifecycle-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    await GetStorage.init();
  });
  tearDown(Get.reset);
  tearDownAll(() => storage.delete(recursive: true));

  void services() {
    Get.put<DiaspoService>(_DiaspoService());
    Get.put<MaritimeService>(_MaritimeService());
    Get.put(CurrencyService());
  }

  testWidgets(
    'Passcolis reste utilisable après un aller-retour durant le fondu',
    (tester) async {
      services();
      late StateSetter update;
      var show = true;
      await tester.pumpWidget(
        themedApp(
          Scaffold(
            body: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: show
                      ? const PasscolisSection()
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final diaspo = Get.find<DiaspoListController>();
      final maritime = Get.find<MaritimeController>();
      update(() => show = false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      update(() => show = true);
      await tester.pump();
      await tester.pumpAndSettle();

      final currentDiaspo = Get.find<DiaspoListController>();
      final currentMaritime = Get.find<MaritimeController>();
      expect(currentDiaspo.isClosed, isFalse);
      expect(currentMaritime.isClosed, isFalse);
      expect(identical(diaspo, currentDiaspo) || diaspo.isClosed, isTrue);
      expect(identical(maritime, currentMaritime) || maritime.isClosed, isTrue);
      expect(
        tester
            .widget<DiaspoListView>(find.byType(DiaspoListView))
            .pageController,
        same(currentDiaspo),
      );
      currentDiaspo.transportMode.value = 1;
      await tester.pumpAndSettle();
      expect(find.byType(MaritimeSection), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(Get.isRegistered<DiaspoListController>(), isFalse);
      expect(Get.isRegistered<MaritimeController>(), isFalse);
    },
  );

  testWidgets('fermer une recherche garde les contrôleurs de l’autre hôte', (
    tester,
  ) async {
    services();
    late StateSetter update;
    var first = true;
    var second = true;
    await tester.pumpWidget(
      themedApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (first) const PasscolisSection(key: ValueKey('first')),
                  if (second) const PasscolisSection(key: ValueKey('second')),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final diaspo = Get.find<DiaspoListController>();
    update(() => first = false);
    await tester.pumpAndSettle();
    expect(Get.find<DiaspoListController>(), same(diaspo));
    expect(find.byType(DiaspoListView), findsOneWidget);
    expect(diaspo.isClosed, isFalse);
    update(() => second = false);
    await tester.pumpAndSettle();
    expect(Get.isRegistered<DiaspoListController>(), isFalse);
    expect(diaspo.isClosed, isTrue);
    expect(tester.takeException(), isNull);
  });

  test(
    'l’inventaire déclare sa dépendance boutique sur une ouverture directe',
    () {
      expect(Get.isRegistered<StoreManagementController>(), isFalse);
      InventoryListBinding().dependencies();
      expect(Get.isRegistered<StoreManagementController>(), isTrue);
      expect(Get.isRegistered<InventoryListController>(), isTrue);
    },
  );

  testWidgets(
    'ouvrir puis fermer la route Diaspo préserve l’onglet Recherche',
    (tester) async {
      services();
      await tester.pumpWidget(
        GetMaterialApp(
          home: const Scaffold(body: PasscolisSection()),
          getPages: [
            AppPages.routes.firstWhere((page) => page.name == Routes.DIASPO),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final diaspo = Get.find<DiaspoListController>();
      Get.toNamed(Routes.DIASPO);
      await tester.pumpAndSettle();
      expect(Get.find<DiaspoListController>(), same(diaspo));
      Get.back();
      await tester.pumpAndSettle();
      expect(Get.find<DiaspoListController>(), same(diaspo));
      expect(diaspo.isClosed, isFalse);
      diaspo.searchQuery.value = 'Douala';
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(Get.isRegistered<DiaspoListController>(), isFalse);
    },
  );

  test('l’inventaire réutilise la boutique déjà ouverte', () {
    final existing = Get.put<StoreManagementController>(_StoreController());
    InventoryListBinding().dependencies();
    expect(Get.find<InventoryListController>().storeController, same(existing));
  });
}
