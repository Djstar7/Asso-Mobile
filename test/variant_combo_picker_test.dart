import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/core/widgets/product_variant_selector.dart';
import 'package:asso/app/core/widgets/variant_combo_picker.dart';

/// Polo en Bleu / Rouge et M / L ; Rouge · L est épuisé.
VariantCatalog _catalog() => VariantCatalog.fromApi(
  [
    {'id': 1, 'attributes': {'Couleur': 'Bleu', 'Taille': 'M'}, 'stock': 10},
    {'id': 2, 'attributes': {'Couleur': 'Bleu', 'Taille': 'L'}, 'stock': 10},
    {'id': 3, 'attributes': {'Couleur': 'Rouge', 'Taille': 'M'}, 'stock': 10},
    {'id': 4, 'attributes': {'Couleur': 'Rouge', 'Taille': 'L'}, 'stock': 0},
  ],
  [
    {
      'name': 'Couleur',
      'type': 'color',
      'values': [
        {'value': 'Bleu'},
        {'value': 'Rouge'},
      ],
    },
    {
      'name': 'Taille',
      'type': 'text',
      'values': [
        {'value': 'M'},
        {'value': 'L'},
      ],
    },
  ],
);

void main() {
  Future<Map<int, int> Function()> pumpPicker(
    WidgetTester tester, {
    bool limitToStock = true,
  }) async {
    var quantities = <int, int>{};
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return VariantComboPicker(
                  catalog: _catalog(),
                  quantities: quantities,
                  limitToStock: limitToStock,
                  onChanged: (next) => rebuild(() => quantities = next),
                );
              },
            ),
          ),
        ),
      ),
    );
    return () => quantities;
  }

  Finder field() => find.byWidgetPredicate(
    (w) => w is TextField && w.keyboardType == TextInputType.number,
  );

  testWidgets('une saisie par combinaison, plusieurs combinaisons', (
    tester,
  ) async {
    final read = await pumpPicker(tester);
    await tester.pump();

    // Rien de choisi : pas encore de champ.
    expect(field(), findsNothing);
    expect(find.textContaining('Choisissez : Couleur, Taille'), findsOneWidget);

    await tester.tap(find.text('Bleu'));
    await tester.tap(find.text('M'));
    await tester.pump();
    await tester.enterText(field(), '3');
    await tester.pump();

    await tester.tap(find.text('Rouge'));
    await tester.pump();
    await tester.enterText(field(), '2');
    await tester.pump();

    expect(read(), {1: 3, 3: 2});
    expect(find.text('Bleu · M × 3'), findsOneWidget);
    expect(find.text('Rouge · M × 2'), findsOneWidget);
    expect(find.textContaining('5 au total'), findsOneWidget);

    // Toucher une ligne la rouvre ; la croix la retire.
    await tester.tap(find.text('Bleu · M × 3'));
    await tester.pump();
    expect(tester.widget<TextField>(field()).controller!.text, '3');
    await tester.tap(find.byTooltip('Retirer').last);
    await tester.pump();
    expect(read(), {1: 3});
  });

  testWidgets('au détail, une combinaison épuisée ne se commande pas', (
    tester,
  ) async {
    await pumpPicker(tester);
    await tester.pump();

    await tester.tap(find.text('Rouge'));
    await tester.tap(find.text('L'));
    await tester.pump();

    // Rouge · L est épuisé : le choix de L retire Rouge.
    expect(find.textContaining('Choisissez : Couleur'), findsOneWidget);
  });

  testWidgets('en gros, le stock ne limite pas la combinaison', (
    tester,
  ) async {
    final read = await pumpPicker(tester, limitToStock: false);
    await tester.pump();

    await tester.tap(find.text('Rouge'));
    await tester.tap(find.text('L'));
    await tester.pump();
    await tester.enterText(field(), '500');
    await tester.pump();

    expect(read(), {4: 500});
  });
}
