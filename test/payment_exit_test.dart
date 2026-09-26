import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:asso/app/data/models/payment_method_option.dart';
import 'package:asso/app/modules/payment/widgets/payment_method_selector.dart';
import 'package:asso/app/modules/payment/widgets/wallet_payment_confirm_dialog.dart';

/// Parcours de paiement : un choix ou une confirmation doit fermer la
/// feuille / le dialogue même quand une bannière est affichée.
///
/// Avec GetX 4.7.3, `Get.back()` ne ferme que la bannière ouverte : le client
/// tapait « Mobile Money » ou « Confirmer » sans que rien ne se passe et
/// restait bloqué au paiement.
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

  tearDown(Get.reset);

  const kpay = PaymentMethodOption(
    code: 'kpay',
    label: 'Mobile Money',
    subtitle: 'MTN, Orange',
    flow: 'phone',
    enabled: true,
    available: true,
    minCurrency: 'XAF',
  );

  Future<void> openWithSnackbar(
    WidgetTester tester,
    Future<void> Function() open,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) =>
                  TextButton(onPressed: open, child: const Text('Ouvrir')),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    // La bannière typique du parcours, affichée juste avant le tap.
    Get.snackbar(
      'Solde Wallet insuffisant',
      'Rechargez votre Wallet',
      duration: const Duration(seconds: 5),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(Get.isSnackbarOpen, isTrue);
  }

  testWidgets('choisir un moyen ferme le sélecteur malgré une bannière', (
    tester,
  ) async {
    PaymentMethodOption? chosen;
    var closed = false;

    await openWithSnackbar(tester, () async {
      chosen = await PaymentMethodSelector.show(
        amount: 1000,
        currency: 'XAF',
        options: const [kpay],
      );
      closed = true;
    });

    await tester.tap(find.text('Mobile Money'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(closed, isTrue);
    expect(chosen?.code, 'kpay');
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('confirmer le paiement Wallet ferme le dialogue malgré une '
      'bannière', (tester) async {
    bool? confirmed;

    await openWithSnackbar(tester, () async {
      confirmed = await WalletPaymentConfirmDialog.show(
        itemLabel: 'Montre',
        amount: 1000,
        balance: 5000,
      );
    });

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(confirmed, isFalse);
    expect(find.text('Montre'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });
}
