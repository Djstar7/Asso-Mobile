import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:asso/app/data/providers/api_provider.dart';
import 'package:asso/app/modules/packageSubscription/widgets/sales_code_field.dart';

const _warning = 'Ce code est le vôtre : vous ne percevrez aucune commission.';

ApiResponse _check({required bool own, String? warning}) => ApiResponse(
      success: true,
      message: '',
      statusCode: 200,
      data: {
        'success': true,
        'data': {
          'code': 'ASSO-AB3CD',
          'agent_display_name': 'Amina K.',
          'is_own_code': own,
          'warning': ?warning,
        },
      },
    );

/// Son propre code commercial n'est plus refusé : le vendeur confirme qu'il
/// continue sans commission, et l'abonnement l'indique au serveur.
void main() {
  late List<String> asked;

  SalesCodeInput input({required bool own, String? warning, Future<bool> Function()? answer}) {
    asked = [];
    final field = SalesCodeInput(
      checkCode: (_) async => _check(own: own, warning: warning),
      confirmOwnCode: (message) async {
        asked.add(message);
        return answer == null ? true : answer();
      },
    );
    field.textController.text = 'ASSO-AB3CD';
    field.onChanged('ASSO-AB3CD');
    return field;
  }

  test('son propre code : confirmation en attente, puis code envoyé avec le drapeau', () async {
    final decision = Completer<bool>();
    final field = input(own: true, warning: _warning, answer: () => decision.future);

    final verifying = field.verify();
    await Future<void>.delayed(Duration.zero);
    expect(field.pendingOwnCodeWarning.value, _warning);
    expect(field.code, isNull);

    decision.complete(true);
    expect(await verifying, isTrue);
    expect(asked, [_warning]);
    expect(field.pendingOwnCodeWarning.value, isEmpty);
    expect(field.status.value, SalesCodeStatus.valid);
    expect(field.ownCodeAccepted.value, isTrue);
    expect(field.code, 'ASSO-AB3CD');
    expect(field.acceptOwnCode, isTrue);
    field.dispose();
  });

  test('sans avertissement du serveur : texte traduit', () async {
    final field = input(own: true);
    await field.verify();
    expect(asked.single, contains('aucune commission'));
    field.dispose();
  });

  test('modifier le code : rien n\'est envoyé, le champ reste à vérifier', () async {
    final field = input(own: true, warning: _warning, answer: () async => false);

    expect(await field.ensureReady(), isFalse);
    expect(asked, hasLength(1));
    expect(field.status.value, SalesCodeStatus.unverified);
    expect(field.code, isNull);
    expect(field.acceptOwnCode, isFalse);
    field.dispose();
  });

  test('ensureReady demande la confirmation d\'un code non vérifié', () async {
    final field = input(own: true, warning: _warning);
    expect(await field.ensureReady(), isTrue);
    expect(asked, hasLength(1));
    expect(field.acceptOwnCode, isTrue);
    field.dispose();
  });

  test('changer le texte annule la confirmation', () async {
    final field = input(own: true, warning: _warning);
    await field.verify();
    expect(field.acceptOwnCode, isTrue);

    field.textController.text = 'ASSO-ZZZZZ';
    field.onChanged('ASSO-ZZZZZ');
    expect(field.ownCodeAccepted.value, isFalse);
    expect(field.acceptOwnCode, isFalse);
    expect(field.code, isNull);
    field.dispose();
  });

  test('le code d\'un autre commercial ne demande rien', () async {
    final field = input(own: false);
    expect(await field.verify(), isTrue);
    expect(asked, isEmpty);
    expect(field.acceptOwnCode, isFalse);
    expect(field.code, 'ASSO-AB3CD');
    field.dispose();
  });

  testWidgets('refus own_sales_code du serveur : confirmation puis drapeau pour relancer', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    final field = input(own: false);
    await tester.runAsync(field.verify);
    expect(field.acceptOwnCode, isFalse);

    final handled = field.handleServerRejection(ApiResponse(
      success: false,
      message: _warning,
      statusCode: 422,
      data: {'success': false, 'code': 'own_sales_code', 'message': _warning},
    ));
    expect(handled, isTrue);
    await tester.pump();

    expect(asked, [_warning]);
    expect(field.status.value, SalesCodeStatus.valid);
    expect(field.acceptOwnCode, isTrue);

    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    field.dispose();
  });

  testWidgets('la vraie boîte de dialogue : « Continuer sans commission »', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));
    final result = showOwnSalesCodeDialog(_warning);
    await tester.pumpAndSettle();

    expect(find.text('C\'est votre propre code'), findsOneWidget);
    expect(find.text(_warning), findsOneWidget);
    expect(find.text('Modifier le code'), findsOneWidget);

    await tester.tap(find.text('Continuer sans commission'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });
}
