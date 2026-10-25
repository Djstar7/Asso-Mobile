import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:asso/app/data/models/real_estate_models.dart';
import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/modules/immo/immo_payment.dart';
import 'package:asso/app/modules/payment/widgets/payment_preparation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/themed_app.dart';

void main() {
  late Directory storage;
  late Completer<http.Response> response;
  var submissions = 0;
  Map<String, dynamic>? payload;
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/payments/methods')) {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'methods': [
              {
                'code': 'wallet',
                'label': 'Wallet ASSO',
                'flow': 'wallet',
                'enabled': true,
                'available': true,
                'balance': 200000,
              },
            ],
          },
        }),
        200,
      );
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/reservations')) {
      submissions++;
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return response.future;
    }
    throw StateError(
      'Requête inattendue : ${request.method} ${request.url.path}',
    );
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storage = await Directory.systemTemp.createTemp('asso-immo-wallet-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    await GetStorage.init();
  });
  setUp(() {
    submissions = 0;
    payload = null;
    Get.put(CurrencyService());
  });
  tearDown(Get.reset);
  tearDownAll(() => storage.delete(recursive: true));

  for (final succeeds in [true, false]) {
    testWidgets(
      'réservation Wallet : attente puis ${succeeds ? 'confirmation serveur' : 'erreur récupérable'}',
      (tester) async {
        response = Completer<http.Response>();
        await http.runWithClient(() async {
          await tester.pumpWidget(
            themedApp(const Scaffold(body: Text('Récapitulatif'))),
          );
          var finished = false;
          RealEstateReservation? reservation;
          final payment =
              ImmoPayment.pay(
                listingId: 42,
                total: 155250,
                label: 'Chambre simple',
                body: {'contract_accepted': true, 'expected_total': 155250},
              ).then((value) {
                reservation = value;
                finished = true;
              });
          await tester.pumpAndSettle();
          await tester.tap(find.text('Wallet ASSO'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('wallet.recharge.confirm_payment'.tr));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.text('payment.preparation.wallet_title'.tr),
            findsOneWidget,
          );
          expect(finished, isFalse);
          expect(submissions, 1);
          expect(payload!['payment_mode'], 'wallet');
          expect(payload!['expected_total'], 155250);

          response.complete(
            http.Response(
              jsonEncode(
                succeeds
                    ? {
                        'success': true,
                        'data': {
                          'id': 12,
                          'reference': 'IMMO-12',
                          'status': 'paid',
                        },
                      }
                    : {'success': false, 'message': 'Solde insuffisant'},
              ),
              succeeds ? 200 : 422,
            ),
          );
          // Laisse le flux HTTP simulé traiter sa réponse avant de faire
          // avancer les animations (et le délai réseau) de l'horloge de test.
          await tester.runAsync(() async {
            await Future<void>.delayed(Duration.zero);
          });
          await tester.pumpAndSettle();
          await payment;
          expect(find.byType(PaymentPreparationDialog), findsNothing);
          expect(find.text('Récapitulatif'), findsOneWidget);
          expect(finished, isTrue);
          expect(
            reservation?.status,
            succeeds ? 'paid' : isNull,
            reason: tester
                .widgetList<Text>(find.byType(Text))
                .map((text) => text.data)
                .join(' | '),
          );
          expect(tester.takeException(), isNull);
          Get.closeAllSnackbars();
          await tester.pumpAndSettle();
        }, () => client);
      },
    );
  }
}
