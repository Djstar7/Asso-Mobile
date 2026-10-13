import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/data/models/currency_model.dart';
import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/data/providers/storage_service.dart';

/// Conversion des prix dans la devise du pays choisi : le backend renvoie des
/// montants en XAF (`price_xaf`), l'app les affiche dans la devise de
/// l'utilisateur — ou en FCFA tant qu'aucun taux n'est connu.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    await GetStorage.init();
  });

  tearDown(() {
    StorageService.clearCurrency();
    StorageService.clearCountry();
    Get.reset();
  });

  group('formatAmountInCurrency', () {
    test('0 décimale en FCFA, 2 pour les autres devises', () {
      expect(CurrencyService.formatAmountInCurrency(1500, 'XAF'), '1 500 FCFA');
      expect(CurrencyService.formatAmountInCurrency(15, 'EUR'), '15,00 €');
      expect(CurrencyService.formatAmountInCurrency(15.244, 'EUR'), '15,24 €');
      expect(CurrencyService.formatAmountInCurrency(1234.5, 'XOF'), '1 235 FCFA');
    });
  });

  group('prix produit', () {
    test('utilise price_xaf quand il est fourni', () {
      expect(
        CurrencyService.productPriceXaf({'price': 20, 'price_xaf': 13119, 'currency': 'EUR'}),
        13119,
      );
    });

    test('un produit en FCFA sans price_xaf garde son prix', () {
      expect(CurrencyService.productPriceXaf({'price': 5000, 'currency': 'XAF'}), 5000);
      expect(CurrencyService.productPriceXaf({'price': 5000}), 5000);
    });

    test("un prix en euros n'est jamais lu comme du FCFA", () {
      final product = {'price': 20, 'currency': 'EUR'};
      expect(CurrencyService.productPriceXaf(product), isNull);
      expect(CurrencyService.formatProductPrice(product), '20,00 €');
    });
  });

  group('sans service', () {
    test('affiche le montant pivot en FCFA', () {
      expect(CurrencyService.formatFromPivot(10000), '10 000 FCFA');
    });
  });

  group('utilisateur en euros', () {
    setUp(() {
      StorageService.saveCountry('France');
      StorageService.saveCurrency(CurrencyModel(
        id: 2,
        code: 'EUR',
        name: 'Euro',
        symbol: '€',
        countries: const ['France'],
      ).toJson());
      // Taux récent : aucun appel réseau au démarrage.
      StorageService.saveExchangeRate('EUR', 655.957);
      Get.put(CurrencyService());
    });

    test('convertit le montant XAF avec le taux enregistré', () {
      expect(CurrencyService.to.displayCurrencyCode, 'EUR');
      expect(CurrencyService.formatFromPivot(655.957), '1,00 €');
      expect(CurrencyService.formatFromPivot(100), '0,15 €');
      expect(CurrencyService.to.currencySymbol, '€');
    });

    test('reconvertit une saisie en XAF (filtre de prix)', () {
      expect(CurrencyService.to.convertToPivot(10), closeTo(6559.57, 0.001));
    });

    test('formatPrice suit le même arrondi que formatFromPivot', () {
      expect(CurrencyService.to.formatPrice(10000), CurrencyService.formatFromPivot(10000));
    });
  });
}
