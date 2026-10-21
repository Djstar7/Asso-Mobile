import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/modules/immo/views/immo_reserve_view.dart';

void main() {
  final today = DateTime(2026, 10, 21);

  test('clamps an out-of-range prefilled date to the picker range', () {
    expect(
      immoMoveInPickerInitialDate(DateTime(2025, 1, 1), today),
      DateTime(2026, 10, 21),
    );
    expect(
      immoMoveInPickerInitialDate(DateTime(2030, 1, 1), today),
      DateTime(2027, 10, 21),
    );
  });

  test('keeps an in-range date and leaves the move-in date optional', () {
    final selected = DateTime(2026, 12, 5);

    expect(immoMoveInPickerInitialDate(selected, today), selected);
    expect(immoMoveInSummary(null), '-');
    expect(immoMoveInApiValue(null), isNull);
  });

  test('formats the selected move-in date for the recap and API', () {
    final selected = DateTime(2026, 12, 5);

    expect(immoMoveInSummary(selected), '5 déc. 2026');
    expect(immoMoveInApiValue(selected), '2026-12-05');
  });
}
