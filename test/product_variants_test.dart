import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:asso/app/core/widgets/product_variant_selector.dart';
import 'package:asso/app/modules/addProduct/controllers/variant_editor_state.dart';
import 'package:asso/app/modules/addProduct/views/variant_editor_page.dart';

final _variants = [
  {
    'id': 1,
    'attributes': {'Couleur': 'Noir', 'Pointure': '41'},
    'stock': 3,
    'price_adjustment_xaf': 0,
  },
  {
    'id': 2,
    'attributes': {'Couleur': 'Noir', 'Pointure': '42'},
    'stock': 0,
  },
  {
    'id': 3,
    'attributes': {'Couleur': 'Bleu', 'Pointure': '42'},
    'stock': 5,
    'price_adjustment_xaf': 1500,
  },
];

final _options = [
  {
    'name': 'Couleur',
    'type': 'color',
    'values': [
      {'value': 'Noir', 'hex': '#111111'},
      {'value': 'Bleu', 'hex': '#123456'},
    ],
  },
  {
    'name': 'Pointure',
    'type': 'text',
    'values': [
      {'value': '41'},
      {'value': '42'},
    ],
  },
];

void main() {
  group('VariantCatalog', () {
    final catalog = VariantCatalog.fromApi(_variants, _options);

    test('reads groups with their colors', () {
      expect(catalog.groups.map((g) => g.name), ['Couleur', 'Pointure']);
      expect(catalog.groups.first.isColor, isTrue);
      expect(catalog.groups.first.values.last.color, const Color(0xFF123456));
    });

    test('marks values unavailable according to stock and other choices', () {
      expect(
        catalog.isAvailable('Pointure', '42', {'Couleur': 'Noir'}),
        isFalse,
      );
      expect(
        catalog.isAvailable('Pointure', '42', {'Couleur': 'Bleu'}),
        isTrue,
      );
      expect(
        catalog.isAvailable('Couleur', 'Bleu', {'Pointure': '41'}),
        isFalse,
      );
    });

    test('finds the variant only once every option is chosen', () {
      expect(catalog.find({'Couleur': 'Bleu'}), isNull);
      expect(catalog.find({'Couleur': 'Bleu', 'Pointure': '42'})?['id'], 3);
      expect(catalog.missing({'Couleur': 'Bleu'}), ['Pointure']);
    });

    test('derives groups from legacy variants without options', () {
      final legacy = VariantCatalog.fromApi(_variants, null);
      expect(legacy.groups.first.name, 'Couleur');
      expect(legacy.groups.first.isColor, isTrue);
    });
  });

  testWidgets('selector reports the chosen in-stock variant', (tester) async {
    Map<String, dynamic>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProductVariantSelector(
              catalog: VariantCatalog.fromApi(_variants, _options),
              onChanged: (v) => selected = v,
              formatAdjustment: (amount) => '${amount.toInt()} FCFA',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sélectionnez : Couleur, Pointure'), findsOneWidget);

    await tester.tap(find.text('Bleu'));
    await tester.pump();
    await tester.tap(find.text('42'));
    await tester.pumpAndSettle();

    expect(selected?['id'], 3);
    expect(find.text('+1500 FCFA'), findsOneWidget);
  });

  group('VariantEditorState', () {
    test('builds every combination and serializes API fields', () {
      final state = VariantEditorState();
      final color = state.addGroup('couleur');
      state.addValues(color, 'Noir, Rouge');
      final size = state.addGroup('Pointure');
      state.addValues(size, '41,42');

      expect(state.combinations, hasLength(4));
      state.applyStockToAll(2);
      expect(state.totalStock, 8);

      final fields = state.toFields();
      expect(fields['variants[0][attributes][Couleur]'], 'Noir');
      expect(fields['variants[3][attributes][Pointure]'], '42');
      expect(fields['variants[3][stock]'], '2');
      expect(fields['variant_options'], contains('"type":"color"'));
    });

    test('keeps quantities when an option is renamed', () {
      final state = VariantEditorState();
      final index = state.addGroup('Taille');
      state.addValues(index, 'M');
      state.rowFor({'Taille': 'M'}).stock = 7;

      state.renameGroup(index, 'Format');
      expect(state.rowFor({'Format': 'M'}).stock, 7);
    });

    test('loads existing variants for editing', () {
      final state = VariantEditorState()..loadFromApi(_variants, _options);
      expect(state.groups, hasLength(2));
      expect(state.rowFor({'Couleur': 'Bleu', 'Pointure': '42'}).stock, 5);
      expect(state.groups.first.values.first.hex, '#111111');
    });
  });

  testWidgets('vendor editor builds combinations from quick actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = VariantEditorState();
    await tester.pumpWidget(MaterialApp(home: VariantEditorPage(state: state)));

    await tester.tap(find.widgetWithText(ActionChip, 'Couleur'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Noir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Blanc'));
    await tester.pumpAndSettle();

    expect(state.combinations, hasLength(2));
    await tester.scrollUntilVisible(
      find.text('Quantité par combinaison'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Quantité par combinaison'), findsOneWidget);
    expect(find.text('Valider · 2 choix · 0 en stock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
