import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/core/widgets/passcolis_card.dart';
import 'package:asso/app/data/models/diaspo_offer.dart';
import 'package:asso/app/modules/search/controllers/search_controller.dart'
    as search_ctrl;

DiaspoOffer _offer({
  int id = 1,
  String departureCity = 'Paris',
  String departureCountry = 'France',
  String arrivalCity = 'Douala',
  String arrivalCountry = 'Cameroun',
  double remainingKg = 8,
  double pricePerKg = 12,
  bool profileVerified = true,
}) {
  return DiaspoOffer.fromJson({
    'id': id,
    'user_id': 2,
    'status': 'approved',
    'verification_status': profileVerified ? 'verified' : 'pending',
    'departure_country': departureCountry,
    'departure_city': departureCity,
    'departure_datetime': '2026-10-01T10:00:00Z',
    'arrival_country': arrivalCountry,
    'arrival_city': arrivalCity,
    'arrival_datetime': '2026-10-02T10:00:00Z',
    'price_per_kg': pricePerKg,
    'available_kg': 20,
    'remaining_kg': remainingKg,
    'currency': 'EUR',
    'created_at': '2026-09-18T10:00:00Z',
    'updated_at': '2026-09-18T10:00:00Z',
  });
}

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

  tearDown(Get.reset);

  group('Filtrage des passcolis', () {
    late search_ctrl.SearchController controller;

    setUp(() {
      controller = search_ctrl.SearchController();
      controller.passcolisOffers.assignAll([
        _offer(id: 1, arrivalCity: 'Douala', arrivalCountry: 'Cameroun'),
        _offer(
          id: 2,
          departureCity: 'Lyon',
          arrivalCity: 'Abidjan',
          arrivalCountry: "Côte d'Ivoire",
        ),
      ]);
    });

    test('sans requête, tous les trajets restent affichés', () {
      expect(controller.filteredPasscolis, hasLength(2));
    });

    test('la recherche porte aussi sur le pays, pas seulement la ville', () {
      // « Cameroun » n'est le nom d'aucune ville de la liste : sans filtrage
      // sur le pays, ce trajet serait introuvable.
      controller.searchQuery.value = 'cameroun';
      expect(controller.filteredPasscolis.single.arrivalCity, 'Douala');
    });

    test('la recherche ignore la casse et les espaces autour', () {
      controller.searchQuery.value = '  LYON ';
      expect(controller.filteredPasscolis.single.departureCity, 'Lyon');
    });

    test('une destination non desservie ne renvoie rien', () {
      controller.searchQuery.value = 'Tokyo';
      expect(controller.filteredPasscolis, isEmpty);
    });
  });

  group('Onglets de recherche', () {
    test('la recherche démarre sur les produits', () {
      expect(
        search_ctrl.SearchController().scope.value,
        search_ctrl.SearchScope.products,
      );
    });

    test('rebasculer sur l’onglet courant ne relance rien', () {
      final controller = search_ctrl.SearchController();
      controller.changeScope(search_ctrl.SearchScope.products);
      expect(controller.isLoadingPasscolis.value, isFalse);
      expect(controller.scope.value, search_ctrl.SearchScope.products);
    });
  });

  group('Carte Passcolis', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 280, child: child))),
    );

    testWidgets('affiche le trajet, le prix et les kilos restants', (
      tester,
    ) async {
      await tester.pumpWidget(host(PasscolisCard(offer: _offer())));

      expect(find.textContaining('Paris'), findsOneWidget);
      expect(find.textContaining('Douala'), findsOneWidget);
      expect(find.textContaining('12'), findsWidgets);
      expect(find.text('8 kg dispo'), findsOneWidget);
    });

    testWidgets('signale un voyageur dont le profil n’est pas vérifié', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(PasscolisCard(offer: _offer(profileVerified: false))),
      );

      expect(find.text('Profil non vérifié'), findsOneWidget);
    });

    testWidgets('la version compacte tient dans sa hauteur annoncée', (
      tester,
    ) async {
      // Le carrousel de l'accueil impose une hauteur fixe : si la carte la
      // dépasse, Flutter affiche le bandeau de débordement.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: PasscolisCard.compactHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  SizedBox(
                    width: 260,
                    child: PasscolisCard.compact(
                      offer: _offer(
                        departureCity: 'Bruxelles',
                        arrivalCity: 'Ouagadougou',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
