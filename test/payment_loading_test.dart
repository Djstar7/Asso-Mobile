import 'dart:async';
import 'dart:io';

import 'package:asso/app/data/providers/currency_service.dart';
import 'package:asso/app/data/services/stripe_native_service.dart';
import 'package:asso/app/modules/payment/widgets/mobile_money_waiting.dart';
import 'package:asso/app/modules/payment/widgets/payment_preparation.dart';
import 'package:asso/app/modules/wallet/widgets/kpay_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'helpers/themed_app.dart';

class _StripePlatform extends StripePlatform {
  Completer<void>? settings;
  Completer<PaymentSheetPaymentOption?>? sheet;
  SetupPaymentSheetParameters? parameters;
  VoidCallback? onPresent;
  int presentations = 0;

  @override
  Future<void> initialise({
    required String publishableKey,
    String? stripeAccountId,
    ThreeDSecureConfigurationParams? threeDSecureParams,
    String? merchantIdentifier,
    String? urlScheme,
    bool? setReturnUrlSchemeOnAndroid,
  }) async {
    await settings?.future;
  }

  @override
  Future<PaymentSheetPaymentOption?> initPaymentSheet(
    SetupPaymentSheetParameters params,
  ) async {
    parameters = params;
    return sheet?.future;
  }

  @override
  Future<PaymentSheetPaymentOption?> presentPaymentSheet({
    PaymentSheetPresentOptions? options,
  }) async {
    presentations++;
    onPresent?.call();
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final stripe = _StripePlatform();
  late Directory storage;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    StripePlatform.instance = stripe;
    storage = await Directory.systemTemp.createTemp('asso-payment-loading-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    await GetStorage.init();
  });
  tearDownAll(() => storage.delete(recursive: true));
  setUp(() {
    stripe.settings = null;
    stripe.sheet = null;
    stripe.parameters = null;
    stripe.onPresent = null;
    stripe.presentations = 0;
  });
  tearDown(Get.reset);

  Future<void> openApp(WidgetTester tester) =>
      tester.pumpWidget(themedApp(const Scaffold(body: Text('Commande'))));

  testWidgets(
    'préparation KPay visible, retour bloqué, puis fermeture exacte',
    (tester) async {
      await openApp(tester);
      final response = Completer<int>();
      final task = PaymentPreparation.run(
        method: 'kpay_direct',
        action: () => response.future,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.text('payment.preparation.mobile_money_title'.tr),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(PaymentPreparationDialog), findsOneWidget);
      response.complete(42);
      await tester.pumpAndSettle();
      expect(await task, 42);
      expect(find.byType(PaymentPreparationDialog), findsNothing);
      expect(find.text('Commande'), findsOneWidget);
    },
  );

  testWidgets('un échec immédiat ferme la modale avant son premier rendu', (
    tester,
  ) async {
    await openApp(tester);
    final task = PaymentPreparation.run<void>(
      method: 'stripe_direct',
      action: () async => throw StateError('Erreur serveur'),
    );
    final expectation = expectLater(task, throwsStateError);
    await tester.pumpAndSettle();
    await expectation;
    expect(find.byType(PaymentPreparationDialog), findsNothing);
    expect(find.text('Commande'), findsOneWidget);
  });

  testWidgets('la fermeture préserve une page ouverte au-dessus de la modale', (
    tester,
  ) async {
    await openApp(tester);
    final response = Completer<void>();
    final task = PaymentPreparation.run(
      method: 'kpay',
      action: () => response.future,
    );
    await tester.pump();
    Get.key.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Autre page')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    response.complete();
    await tester.pumpAndSettle();
    await task;
    expect(find.text('Autre page'), findsOneWidget);
    expect(find.byType(PaymentPreparationDialog), findsNothing);
  });

  testWidgets('le paiement Wallet affiche une attente jusqu’à confirmation', (
    tester,
  ) async {
    await openApp(tester);
    final response = Completer<int>();
    final task = PaymentPreparation.run(
      method: 'wallet',
      action: () => response.future,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('payment.preparation.wallet_title'.tr), findsOneWidget);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(PaymentPreparationDialog), findsOneWidget);
    response.complete(7);
    await tester.pumpAndSettle();
    expect(await task, 7);
    expect(find.byType(PaymentPreparationDialog), findsNothing);
  });

  testWidgets(
    'attente KPay identique au produit jusqu’au statut serveur payé',
    (tester) async {
      await openApp(tester);
      var checks = 0;
      final task = MobileMoneyWaiting.run(
        amount: 4900,
        provider: 'MTN_MOMO_CMR',
        phone: '237670000001',
        check: () async {
          checks++;
          return (status: 'paid', failure: null);
        },
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(checks, 0);
      expect(
        find.text('payment.mobile_money.waiting_title'.tr),
        findsOneWidget,
      );
      expect(find.textContaining('+237670000001'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect((await task).status, 'paid');
      expect(checks, 1);
      expect(find.text('Commande'), findsOneWidget);
    },
  );

  testWidgets('Stripe affiche la préparation SDK et la retire avant la carte', (
    tester,
  ) async {
    await openApp(tester);
    stripe.settings = Completer<void>();
    stripe.sheet = Completer<PaymentSheetPaymentOption?>();
    var preparationVisibleAtPresentation = true;
    stripe.onPresent = () {
      preparationVisibleAtPresentation = find
          .byType(PaymentPreparationDialog)
          .evaluate()
          .isNotEmpty;
    };
    final task = StripeNativeService().payWithCard(
      publishableKey: 'pk_test_asso',
      clientSecret: 'pi_test_secret',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('payment.preparation.card_title'.tr), findsOneWidget);
    expect(stripe.presentations, 0);
    stripe.settings!.complete();
    await tester.pump();
    expect(find.byType(PaymentPreparationDialog), findsOneWidget);
    stripe.sheet!.complete();
    await tester.pumpAndSettle();
    expect(await task, isTrue);
    expect(stripe.presentations, 1);
    expect(preparationVisibleAtPresentation, isFalse);
    expect(
      stripe.parameters!.appearance!.colors!.primary,
      const Color(0xFFFC9141),
    );
    expect(
      stripe.parameters!.appearance!.primaryButton!.colors!.light!.text,
      Colors.white,
    );
  });

  testWidgets('une initialisation Stripe bloquée ferme la modale au délai', (
    tester,
  ) async {
    await openApp(tester);
    stripe.settings = Completer<void>();
    final task = StripeNativeService().payWithCard(
      publishableKey: 'pk_test_asso',
      clientSecret: 'pi_test_secret',
    );
    final expectation = expectLater(task, throwsException);
    await tester.pump();
    await tester.pump(const Duration(seconds: 26));
    await tester.pumpAndSettle();
    await expectation;
    expect(find.byType(PaymentPreparationDialog), findsNothing);
    expect(stripe.presentations, 0);
    stripe.settings!.complete();
    await tester.pump();
  });

  testWidgets('feuille KPay : orange commun, textes et sélection blancs', (
    tester,
  ) async {
    Get.put(CurrencyService());
    await tester.pumpWidget(
      themedApp(const Scaffold(body: KpayDirectPaymentSheet(amount: 4900))),
    );
    await tester.pumpAndSettle();
    final amount = tester.widget<Text>(find.textContaining('4 900').first);
    expect(amount.style!.color, Colors.white);
    final selected = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .singleWhere((c) => c.selected);
    expect(selected.selectedColor, const Color(0xFFFC9141));
    expect(selected.labelStyle!.color, Colors.white);
    expect(selected.checkmarkColor, Colors.white);
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
    await tester.enterText(find.byType(TextFormField), '670000001');
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
