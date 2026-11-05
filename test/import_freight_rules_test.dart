import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/data/models/wholesale_models.dart';

ShippingOption _option(String mode, String rateType, double rate) =>
    ShippingOption(
      id: mode.hashCode,
      mode: mode,
      modeLabel: mode,
      rateType: rateType,
      rateAmount: rate,
      rateAmountXaf: rate,
      currency: 'XAF',
      destinations: const [],
      formattedRate: '',
    );

const _rules = FreightRules(airMaxWeightKg: 100, pickupThresholdKg: 300);

/// Même calcul que le serveur (ImportFreightService), mêmes exemples que ses tests.
void main() {
  final air = _option('air', 'per_kg', 12000);
  final sea = _option('sea', 'per_cbm', 330000);

  test('boxes with dimensions: air by real weight, sea by CBM', () {
    final m = FreightMeasure.of([
      const FreightLine(
        quantity: 3,
        unitWeightKg: 8,
        dimensionsCm: [60, 40, 50],
      ),
    ]);

    expect(air.costFor(m), closeTo(288000, 0.01));
    expect(sea.costFor(m), closeTo(118800, 0.01));
  });

  test('without dimensions only weight counts, 1000 kg for 1 CBM', () {
    final m = FreightMeasure.of([
      const FreightLine(quantity: 3, unitWeightKg: 8),
    ]);

    expect(air.costFor(m), closeTo(288000, 0.01));
    expect(sea.costFor(m), closeTo(7920, 0.01));
  });

  test('a car is billed by volume and only by sea', () {
    final m = FreightMeasure.of([
      const FreightLine(
        quantity: 1,
        unitWeightKg: 1200,
        dimensionsCm: [450, 180, 150],
      ),
    ]);

    expect(sea.costFor(m), closeTo(4009500, 0.01));
    expect(air.isAvailableFor(m, _rules), isFalse);
    expect(sea.isAvailableFor(m, _rules), isTrue);
  });

  test('air stays available up to the limit', () {
    FreightMeasure weight(double kg) =>
        FreightMeasure.of([FreightLine(quantity: 1, unitWeightKg: kg)]);

    expect(air.isAvailableFor(weight(100), _rules), isTrue);
    expect(air.isAvailableFor(weight(100.5), _rules), isFalse);
    // Ancienne API : aucun seuil.
    expect(air.isAvailableFor(weight(5000), null), isTrue);
  });

  test('legacy sea rate by kg bills the real weight and needs it', () {
    final legacy = _option('sea', 'per_kg', 1500);
    final m = FreightMeasure.of([
      const FreightLine(
        quantity: 3,
        unitWeightKg: 8,
        dimensionsCm: [60, 40, 50],
      ),
    ]);
    final noWeight = FreightMeasure.of([
      const FreightLine(quantity: 1, dimensionsCm: [100, 100, 100]),
    ]);

    expect(legacy.costFor(m), closeTo(36000, 0.01));
    expect(legacy.canPrice(noWeight), isFalse);
    expect(air.canPrice(noWeight), isFalse);
    expect(sea.canPrice(noWeight), isTrue);
    expect(
      sea.canPrice(FreightMeasure.of(const [FreightLine(quantity: 1)])),
      isFalse,
    );
  });

  test('reads the dimensions option like the server', () {
    expect(
      packageDimensionsFromAttributes({'Dimensions': '120 × 80 × 100 cm'}),
      [120, 80, 100],
    );
    expect(packageDimensionsFromAttributes({'dimensions': '1,5x2x3'}), [
      1.5,
      2,
      3,
    ]);
    expect(packageDimensionsFromAttributes({'Dimensions': 'Grande'}), isNull);
    expect(packageDimensionsFromAttributes({'Taille': '1 × 2 × 3'}), isNull);
  });

  test('tier dimensions win over complete product dimensions', () {
    final product = WholesaleProduct.fromJson({
      'id': 1,
      'name': 'Carton',
      'length_cm': 10,
      'width_cm': 10,
      'height_cm': 10,
      'freight_rules': {
        'air_max_weight_kg': 100,
        'pickup_threshold_kg': 300,
        'warehouse': {'name': 'ASSO Import Douala', 'address': 'Akwa'},
      },
    });
    PriceTier tier(Map<String, dynamic> extra) => PriceTier.fromJson({
      'id': 1,
      'label': 'Unité',
      'unit_price': 1000,
      'min_quantity': 1,
      ...extra,
    });

    expect(
      product.dimensionsFor(
        tier({'length_cm': 20, 'width_cm': 30, 'height_cm': 40}),
      ),
      [20, 30, 40],
    );
    expect(product.dimensionsFor(tier({'length_cm': 20})), [10, 10, 10]);
    expect(product.freightRules?.warehouseName, 'ASSO Import Douala');
  });
}
