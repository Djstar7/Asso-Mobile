import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:asso/app/modules/packageSubscription/widgets/package_details_sheet.dart';

/// Récapitulatif d'un forfait avant paiement : l'acheteur voit tout ce qu'il
/// paie, et seul « Continuer » mène au paiement.
void main() {
  Future<Future<bool>> open(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    final result = PackageDetailsSheet.show(
      typeLabel: 'Stockage',
      name: 'Stockage Business',
      priceXaf: 3500,
      durationLabel: '30 jours',
      description: 'Pour les boutiques qui publient beaucoup de vidéos.',
      facts: const [
        PackageDetailFact(Icons.storage_outlined, 'Espace', '1 Go'),
        PackageDetailFact(Icons.event_outlined, 'Valable jusqu\'au', '14 nov. 2026'),
      ],
      benefits: const ['Avantage 1', 'Avantage 2', 'Avantage 3', 'Avantage 4', 'Avantage 5'],
      notes: const ['S\'ajoute à votre espace actuel.'],
      salesCode: 'ASSO42',
    );
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('affiche description, faits, tous les avantages et le code', (tester) async {
    await open(tester);

    expect(find.text('Stockage Business'), findsOneWidget);
    expect(find.text('Pour les boutiques qui publient beaucoup de vidéos.'), findsOneWidget);
    expect(find.text('1 Go'), findsOneWidget);
    expect(find.text('14 nov. 2026'), findsOneWidget);
    expect(find.text('S\'ajoute à votre espace actuel.'), findsOneWidget);
    expect(find.text('ASSO42'), findsOneWidget);
    for (var i = 1; i <= 5; i++) {
      await tester.scrollUntilVisible(find.text('Avantage $i'), 50, scrollable: find.byType(Scrollable).first);
      expect(find.text('Avantage $i'), findsOneWidget);
    }
  });

  testWidgets('continuer renvoie true, annuler renvoie false', (tester) async {
    var result = await open(tester);
    await tester.tap(find.text('Continuer vers le paiement'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);

    result = await open(tester);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });

  test('avantages : textes non vides uniquement', () {
    expect(PackageDetailsSheet.benefitsOf([' A ', '', 'B']), ['A', 'B']);
    expect(PackageDetailsSheet.benefitsOf(null), isEmpty);
  });
}
