import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:asso/app/core/widgets/app_ui.dart';
import 'package:asso/app/data/models/sales_program.dart';
import 'package:asso/app/data/models/wallet_model.dart';
import 'package:asso/app/data/providers/api_provider.dart';
import 'package:asso/app/modules/packageSubscription/widgets/sales_code_field.dart';
import 'package:asso/app/modules/salesProgram/controllers/sales_program_controller.dart';
import 'package:asso/app/modules/salesProgram/views/sales_program_success_view.dart';
import 'package:asso/app/modules/salesProgram/views/sales_program_view.dart';
import 'package:asso/app/routes/app_pages.dart';

ApiResponse _ok(Map<String, dynamic> data) =>
    ApiResponse(success: true, message: '', statusCode: 200, data: {'success': true, 'data': data});

/// Programme « Devenir un commercial ASSO » : modalités acceptées avant
/// d'obtenir son code, commission lisible dans le wallet.
void main() {
  group('taux de commission', () {
    test('sans décimale inutile, virgule en français', () {
      expect(SalesProgram.formatRate(10.0, locale: 'fr'), '10');
      expect(SalesProgram.formatRate(7.5, locale: 'fr'), '7,5');
      expect(SalesProgram.formatRate(12.25, locale: 'fr'), '12,25');
      expect(SalesProgram.formatRate(7.5, locale: 'en'), '7.5');
    });

    test('accepte un nombre ou un texte du serveur', () {
      expect(SalesProgram.parseRate(10), 10.0);
      expect(SalesProgram.parseRate('7.50'), 7.5);
      expect(SalesProgram.parseRate(null), 0);
    });

    test('lit le statut commercial', () {
      final program = SalesProgram.fromJson({
        'terms': 'Article 1',
        'commission_rate': 10.0,
        'is_agent': true,
        'is_active': false,
        'code': 'ASSO-AB3CD',
      });
      expect(program.isAgent, isTrue);
      expect(program.isActive, isFalse);
      expect(program.code, 'ASSO-AB3CD');
    });
  });

  group('wallet', () {
    Map<String, dynamic> tx(Object? metadata) => {
          'id': 1,
          'user_id': 2,
          'type': 'credit',
          'amount': '1500.00',
          'status': 'completed',
          'description': 'Commission commercial : forfait Pro',
          'metadata': metadata,
          'created_at': '2026-10-15T10:00:00Z',
        };

    test('une commission commerciale a son libellé et reste un crédit', () {
      final t = WalletTransactionModel.fromJson(tx({
        'kind': 'sales_commission',
        'label': 'wallet.transactions.sales_commission',
      }));
      expect(t.isCredit, isTrue);
      expect(t.typeLabel, 'Commission commercial');
      expect(t.typeIcon, Icons.handshake_outlined);
    });

    test('métadonnées absentes ou en tableau : recharge ordinaire', () {
      for (final metadata in [null, <dynamic>[]]) {
        final t = WalletTransactionModel.fromJson(tx(metadata));
        expect(t.metadata, isNull);
        expect(t.typeLabel, 'Recharge');
      }
    });
  });

  group('code commercial réservé au premier abonnement', () {
    test('masqué : le code saisi est effacé et ne bloque pas le paiement', () async {
      final input = SalesCodeInput();
      input.textController.text = 'ASSO-AB3CD';
      input.onChanged('ASSO-AB3CD');

      input.applyEligibility({'can_use_sales_code': false});

      expect(input.available.value, isFalse);
      expect(input.code, isNull);
      expect(await input.ensureReady(), isTrue);
      input.dispose();
    });

    test('champ absent de la réponse : toujours proposé', () {
      final input = SalesCodeInput();
      input.applyEligibility({'packages': []});
      expect(input.available.value, isTrue);
      input.dispose();
    });
  });

  group('modalités', () {
    late int enrollCalls;

    Future<void> pumpView(WidgetTester tester, Map<String, dynamic> program) async {
      enrollCalls = 0;
      Get.put(SalesProgramController(
        fetchProgram: () async => _ok(program),
        enrollRequest: () async {
          enrollCalls++;
          return _ok({'code': 'ASSO-AB3CD', 'commission_rate': 10.0});
        },
      ));
      await tester.pumpWidget(GetMaterialApp(
        initialRoute: '/terms',
        getPages: [
          GetPage(name: '/terms', page: () => const SalesProgramView()),
          GetPage(
            name: Routes.SALES_PROGRAM_SUCCESS,
            page: () => Scaffold(body: Text('success ${Get.arguments['code']}')),
          ),
        ],
      ));
      await tester.pumpAndSettle();
    }

    tearDown(Get.reset);

    AppButton submitButton(WidgetTester tester) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, 'Obtenir mon code'));

    testWidgets('cocher la case active « Obtenir mon code »', (tester) async {
      await pumpView(tester, {
        'terms': 'Article 1\nArticle 2',
        'commission_rate': 10.0,
        'is_agent': false,
        'is_active': false,
        'code': null,
      });

      expect(find.text('Article 1\nArticle 2'), findsOneWidget);
      expect(
        find.text('Commission : 10 % du premier abonnement de chaque vendeur que vous recommandez'),
        findsOneWidget,
      );
      expect(submitButton(tester).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('sales-program-accept')));
      await tester.pump();
      expect(submitButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Obtenir mon code'));
      await tester.pumpAndSettle();
      expect(enrollCalls, 1);
      expect(find.text('success ASSO-AB3CD'), findsOneWidget);
    });

    testWidgets('déjà commercial : le code sans les modalités', (tester) async {
      await pumpView(tester, {
        'terms': 'Article 1',
        'commission_rate': 10,
        'is_agent': true,
        'is_active': false,
        'code': 'ASSO-AB3CD',
      });

      expect(find.text('ASSO-AB3CD'), findsOneWidget);
      expect(find.text('Votre compte commercial est désactivé. Contactez ASSO.'), findsOneWidget);
      expect(find.text('Obtenir mon code'), findsNothing);
      expect(find.text('Article 1'), findsNothing);
    });

    testWidgets('modalités vides : message de remplacement', (tester) async {
      await pumpView(tester, {'terms': '  ', 'commission_rate': 7.5});
      expect(find.textContaining('ne sont pas disponibles'), findsOneWidget);
      expect(find.textContaining('7,5'), findsOneWidget);
    });
  });

  testWidgets('félicitations : le code et la commission reçue', (tester) async {
    await tester.pumpWidget(GetMaterialApp(
      home: const Scaffold(),
      getPages: [
        GetPage(
          name: Routes.SALES_PROGRAM_SUCCESS,
          page: () => const SalesProgramSuccessView(),
        ),
      ],
    ));
    Get.toNamed(
      Routes.SALES_PROGRAM_SUCCESS,
      arguments: {'code': 'ASSO-AB3CD', 'commission_rate': 7.5},
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Félicitations !'), findsWidgets);
    expect(find.text('ASSO-AB3CD'), findsOneWidget);
    expect(find.textContaining('vous recevez 7,5\u00a0% du montant'), findsOneWidget);
    expect(find.text('Terminer'), findsOneWidget);
    Get.reset();
  });
}
