import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:asso/app/core/widgets/map_search_results.dart';

void main() {
  final results = List.generate(
    8,
    (i) => <String, dynamic>{
      'display_name': 'Lieu $i, Akwa, Douala I, Littoral, Cameroun',
      'lat': 4.05,
      'lon': 9.7,
    },
  );

  Future<void> pump(
    WidgetTester tester, {
    required double keyboard,
    ValueChanged<Map<String, dynamic>>? onSelected,
    bool isSearching = false,
    List<Map<String, dynamic>>? items,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: Colors.green)),
              MapSearchResults(
                top: 76,
                isSearching: isSearching,
                results: items ?? results,
                onSelected: onSelected ?? (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('la liste s\'arrête au-dessus du clavier', (tester) async {
    await pump(tester, keyboard: 350);

    final panel = tester.getRect(find.byType(Material).last);
    // Clavier de 350 px sur un écran de 800 : rien ne passe dessous.
    expect(panel.bottom, lessThanOrEqualTo(800 - 350));
    expect(tester.takeException(), isNull);
  });

  testWidgets('un résultat reste sélectionnable clavier ouvert', (
    tester,
  ) async {
    Map<String, dynamic>? picked;
    await pump(tester, keyboard: 350, onSelected: (r) => picked = r);

    await tester.tap(find.text('Lieu 0'));
    expect(picked, same(results[0]));
  });

  testWidgets('sépare le lieu du reste de l\'adresse', (tester) async {
    await pump(tester, keyboard: 0);

    expect(find.text('Lieu 0'), findsOneWidget);
    expect(find.text('Akwa, Douala I, Littoral, Cameroun'), findsWidgets);
  });

  testWidgets('annonce l\'absence de résultat', (tester) async {
    await pump(tester, keyboard: 350, items: const []);

    expect(find.textContaining('Aucune adresse trouvée'), findsOneWidget);
  });
}
