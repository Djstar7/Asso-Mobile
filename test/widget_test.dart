import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asso/app/core/utils/app_design.dart';
import 'package:asso/app/core/widgets/app_ui.dart';
import 'package:asso/app/core/widgets/product_card.dart';

/// Tests du socle de design.
///
/// L'ancien test cherchait le texte « HomeView is working », resté du
/// gabarit de génération GetX : il échouait depuis que la page d'accueil a
/// son vrai contenu. On vérifie désormais les garanties que les vues
/// attendent réellement du design system.

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))),
    );

void main() {
  group('ProductCard', () {
    testWidgets('affiche nom, prix et lieu', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProductCard(
            name: 'Chemise en pagne',
            price: '12 000 FCFA',
            location: 'Cotonou, Bénin',
          ),
        ),
      );

      expect(find.text('Chemise en pagne'), findsOneWidget);
      expect(find.text('12 000 FCFA'), findsOneWidget);
      expect(find.text('Cotonou, Bénin'), findsOneWidget);
    });

    testWidgets('garde la même hauteur quelle que soit la longueur du titre',
        (tester) async {
      // C'est la garantie qui tient l'alignement des grilles : deux cartes
      // voisines doivent mesurer pareil même si l'une a un titre d'une ligne
      // et l'autre de deux.
      Future<Size> measure(String name) async {
        await tester.pumpWidget(
          _wrap(ProductCard(name: name, price: '1 000 FCFA')),
        );
        return tester.getSize(find.byType(ProductCard));
      }

      final short = await measure('Sac');
      final long = await measure(
        'Ensemble complet trois pièces en tissu imprimé pour homme',
      );

      expect(short.height, equals(long.height));
    });

    testWidgets('tronque un titre trop long au lieu de déborder',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ProductCard(
            name: 'Un nom de produit délibérément très long qui dépasse '
                'largement les deux lignes autorisées par la carte',
            price: '99 000 FCFA',
          ),
        ),
      );

      final title = tester.widget<Text>(
        find.textContaining('Un nom de produit délibérément'),
      );
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);

      expect(tester.takeException(), isNull);
    });
  });

  group('AppButton', () {
    testWidgets('déclenche son action', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Commander', onPressed: () => tapped++)),
      );

      await tester.tap(find.byType(AppButton));
      expect(tapped, 1);
    });

    testWidgets('est inactif pendant le chargement', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          AppButton(
            label: 'Commander',
            isLoading: true,
            onPressed: () => tapped++,
          ),
        ),
      );

      await tester.tap(find.byType(AppButton));
      expect(tapped, 0, reason: 'un double envoi doit être impossible');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('respecte la cible tactile minimale', (tester) async {
      await tester.pumpWidget(
        _wrap(AppButton(label: 'Valider', onPressed: () {})),
      );

      final size = tester.getSize(find.byType(AppButton));
      expect(size.height, greaterThanOrEqualTo(AppDesign.minTapTarget));
    });
  });

  group('AppTextField', () {
    testWidgets('affiche le libellé et le message d\'erreur', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppTextField(
            label: 'Adresse e-mail',
            errorText: 'Format invalide',
          ),
        ),
      );

      expect(find.text('Adresse e-mail'), findsOneWidget);
      expect(find.text('Format invalide'), findsOneWidget);
    });
  });

  group('AppEmptyState', () {
    testWidgets('propose son action quand elle est fournie', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Aucune commande',
            message: 'Vos commandes apparaîtront ici.',
            actionLabel: 'Actualiser',
            onAction: () => tapped++,
          ),
        ),
      );

      expect(find.text('Aucune commande'), findsOneWidget);
      await tester.tap(find.text('Actualiser'));
      expect(tapped, 1);
    });
  });
}
