import 'package:asso/app/data/models/maritime.dart';
import 'package:asso/app/data/providers/maritime_service.dart';
import 'package:asso/app/modules/maritime/controllers/maritime_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(MaritimeService());
  });

  tearDown(Get.reset);

  test('search matches route cities and partner name', () {
    final controller = MaritimeController();
    controller.departures.assignAll([
      _departure(id: 1, partnerName: 'Ocean Cargo', originCity: 'Douala'),
      _departure(id: 2, partnerName: 'Blue Sea', originCity: 'Abidjan'),
    ]);

    controller.departureSearchQuery.value = 'douala';
    expect(controller.filteredDepartures.map((departure) => departure.id), [1]);

    controller.departureSearchQuery.value = 'ocean';
    expect(controller.filteredDepartures.map((departure) => departure.id), [1]);
  });

  test(
    'bookable filter excludes closed departures and composes with search',
    () {
      final controller = MaritimeController();
      controller.departures.assignAll([
        _departure(id: 1, partnerName: 'Ocean Cargo', isBookable: true),
        _departure(id: 2, partnerName: 'Ocean Cargo', isBookable: false),
        _departure(id: 3, partnerName: 'Blue Sea', isBookable: true),
      ]);

      controller.bookableDeparturesOnly.value = true;
      controller.departureSearchQuery.value = 'ocean';

      expect(controller.filteredDepartures.map((departure) => departure.id), [
        1,
      ]);
    },
  );
}

MaritimeDeparture _departure({
  required int id,
  required String partnerName,
  String originCity = 'Paris',
  bool isBookable = true,
}) {
  return MaritimeDeparture(
    id: id,
    partnerName: partnerName,
    originHub: MaritimeHub(
      id: id,
      name: 'Port',
      country: 'FR',
      countryName: 'France',
      city: originCity,
      address: 'Quai 1',
    ),
    departureDate: DateTime(2026, 11),
    bookingClosesOn: DateTime(2026, 10),
    dropoffDeadline: DateTime(2026, 10, 30),
    daysLeftToBook: 10,
    isBookable: isBookable,
    remainingKg: 100,
    pricePerKg: 12,
    currency: 'EUR',
    status: isBookable ? 'open' : 'closed',
  );
}
