import 'package:asso/app/data/models/category_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Liste telle que `GET /categories` la renvoie.
  final catalog = CategoryCatalog.fromApi([
    {
      'id': 7,
      'name': 'Électronique',
      'subcategories': [
        {'id': 31, 'name': 'Smartphones'},
        {'id': 32, 'name': 'Ordinateurs portables'},
      ],
    },
    {
      'id': 8,
      'name': 'Mode',
      'subcategories': [
        {'id': 2, 'name': 'Chaussures'},
      ],
    },
    {'id': 9, 'name': 'Services', 'subcategories': []},
  ]);

  test('sélection valide : identifiants gardés', () {
    final selection = catalog.resolve(
      categoryId: '7',
      subcategoryId: '32',
      categoryName: 'Électronique',
      subcategoryName: 'Ordinateurs portables',
    );
    expect(selection?.categoryId, '7');
    expect(selection?.subcategoryId, '32');
  });

  test('fiche de l\'ancienne liste de secours : rattrapée par le nom', () {
    // category_id = nom, subcategory_id = numéro inventé qui désigne en base
    // une autre sous-catégorie (« Chaussures »).
    final selection = catalog.resolve(
      categoryId: 'Électronique',
      subcategoryId: '2',
    );
    expect(selection?.categoryId, '7');
    expect(selection?.subcategoryId, '32');
  });

  test('identifiant périmé : le nom prime', () {
    final selection = catalog.resolve(
      categoryId: '8',
      subcategoryId: '2',
      categoryName: 'electronique',
      subcategoryName: 'ORDINATEURS PORTABLES',
    );
    expect(selection?.subcategoryId, '32');
  });

  test('identifiant qui ne correspond plus au libellé : refusé', () {
    expect(
      catalog.resolve(subcategoryId: '2', subcategoryName: 'Tablettes'),
      isNull,
    );
  });

  test('sous-catégorie d\'une autre catégorie : refusée', () {
    expect(catalog.resolve(categoryId: '7', subcategoryId: '2'), isNull);
  });

  test('catégorie sans sous-catégorie', () {
    final selection = catalog.resolve(categoryId: '9');
    expect(selection?.categoryId, '9');
    expect(selection?.subcategoryId, isNull);
  });

  test('catégorie inconnue : refusée', () {
    expect(catalog.resolve(categoryId: 'Jouets', subcategoryId: '99'), isNull);
    expect(catalog.resolve(categoryId: '404'), isNull);
  });
}
