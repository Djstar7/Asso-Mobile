import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/data/models/real_estate_models.dart';
import 'package:asso/app/modules/immo/widgets/immo_lot_payment.dart';
import 'package:asso/app/modules/immo/widgets/immo_widgets.dart';

/// Terrain vendu au morceau : N morceaux d'un lot, ou tout le terrain.
void main() {
  test('la surface totale du terrain se lit dans son morcellement', () {
    RealEstateListing land(Map<String, dynamic> subdivision) =>
        RealEstateListing.fromJson({
          'id': 1,
          'type': 'land',
          'title': 'Terrain',
          'subdivision': subdivision,
        });

    expect(immoTotalSurface(land({'total_surface_m2': 900})), '900 m²');
    expect(immoTotalSurface(land({})), isNull);
  });

  test('reads the whole-land payment exposed by the subdivision', () {
    final sub = RealEstateSubdivision.fromJson({
      'is_subdivided': true,
      'sale_mode': 'per_lot',
      'lots_total': 2,
      'lots_available': 2,
      'can_buy_whole': true,
      'whole_payment': {
        'lot_price': 5500000,
        'deposit_percent': 10,
        'deposit_amount': 550000,
        'fees': 82500,
        'total_to_pay': 632500,
        'balance_due': 4950000,
      },
    });

    expect(sub.canBuyWhole, isTrue);
    expect(sub.wholePayment?.lotPrice, 5500000);
    expect(sub.wholePayment?.totalToPay, 632500);

    // Ancienne API : pas d'achat en bloc.
    final legacy = RealEstateSubdivision.fromJson({'sale_mode': 'per_lot'});
    expect(legacy.canBuyWhole, isFalse);
    expect(legacy.wholePayment, isNull);
  });

  test('quote and reservation carry the number of lots', () {
    final q = RealEstateQuote.fromJson({
      'unit_price': 60000000,
      'base_amount': 6000000,
      'commission': 300000,
      'total': 6900000,
      'quantity': 3,
    });
    expect(q.quantity, 3);
    expect(q.whole, isFalse);
    expect(RealEstateLotPayment.fromQuote(q).balanceDue, 54000000);

    expect(RealEstateQuote.fromJson({'total': 1}).quantity, 1);
    expect(RealEstateReservation.fromJson({'id': 1}).quantity, 1);
  });

  test('sends quantity or whole only when buying several lots', () {
    expect(ImmoLotChoice.single.apiFields, isEmpty);
    expect(const ImmoLotChoice(quantity: 3).apiFields, {'quantity': 3});
    expect(const ImmoLotChoice(quantity: 3, whole: true).apiFields, {
      'whole': true,
    });
    expect(const ImmoLotChoice(quantity: 2).isMultiple, isTrue);
    expect(ImmoLotChoice.single.isMultiple, isFalse);
  });

  test('previews the payment of several identical lots', () {
    const one = RealEstateLotPayment(
      lotPrice: 20000000,
      depositPercent: 10,
      depositAmount: 2000000,
      fees: 300000,
      totalToPay: 2300000,
      balanceDue: 18000000,
    );

    expect(identical(immoLotPaymentTimes(one, 1), one), isTrue);
    final three = immoLotPaymentTimes(one, 3);
    expect(three.lotPrice, 60000000);
    expect(three.totalToPay, 6900000);
    expect(three.balanceDue, 54000000);
    expect(three.depositPercent, 10);
  });
}
