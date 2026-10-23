import 'package:asso/app/core/i18n/app_translations.dart';
import 'package:asso/app/data/providers/maritime_service.dart';
import 'package:asso/app/modules/maritime/views/freight_inquiries_view.dart';
import 'package:asso/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _Quotes extends MaritimeService {
  bool reject = false;
  int accepted = 0;
  Map<String, dynamic>? submitted;

  @override
  void onInit() {}

  final quote = <String, dynamic>{
    'id': 7,
    'conversation_id': 21,
    'destination_country': 'FR',
    'kg': 10,
    'status': 'quoted',
    'description': 'Vêtements pour Paris',
    'freight_amount': 15000,
    'currency': 'XAF',
    'expires_at': '2099-01-01T12:00:00Z',
    'departure': {
      'id': 3,
      'requires_quote': true,
      'currency': 'XAF',
      'remaining_kg': 100,
      'is_bookable': true,
    },
  };

  @override
  Future<List<Map<String, dynamic>>> getInquiries() async => [quote];

  @override
  Future<Map<String, dynamic>> acceptInquiry(
    Map<String, dynamic> inquiry,
  ) async {
    accepted++;
    submitted = Map.of(inquiry);
    if (reject) throw Exception('Le devis a changé');
    return {...quote, 'status': 'accepted'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Quotes service;
  Map<String, dynamic>? navigation;

  setUp(() {
    Get.testMode = true;
    service = _Quotes();
    Get.put<MaritimeService>(service);
    navigation = null;
  });
  tearDown(Get.reset);

  Future<void> show(WidgetTester tester) async {
    final translations = await tester.runAsync(AppTranslations.load);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: translations,
        locale: const Locale('fr', 'FR'),
        home: const Scaffold(body: FreightInquiriesView()),
        getPages: [
          for (final route in [Routes.CHATDETAIL, Routes.MARITIME_BOOKING])
            GetPage(
              name: route,
              page: () {
                navigation = Map<String, dynamic>.from(Get.arguments);
                return const Scaffold(body: Text('Destination ouverte'));
              },
            ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('quote opens the existing ASSO conversation', (tester) async {
    await show(tester);
    expect(find.text('Vêtements pour Paris'), findsOneWidget);
    await tester.tap(find.text('Discuter avec ASSO'));
    await tester.pumpAndSettle();
    expect(navigation?['id'], '21');
    expect(navigation?['is_support'], true);
    expect(navigation?['default_message'], contains('#7'));
  });

  testWidgets(
    'cancel preserves quote; confirmation passes the agreed quote to booking',
    (tester) async {
      await show(tester);
      await tester.tap(find.text('Accepter et réserver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(service.accepted, 0);
      await tester.tap(find.text('Accepter et réserver'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Accepter et réserver').last,
      );
      await tester.pumpAndSettle();
      expect(service.accepted, 1);
      expect(service.submitted?['freight_amount'], 15000);
      expect(navigation?['freight_inquiry']['kg'], 10);
      expect(navigation?['freight_inquiry']['freight_amount'], 15000);
    },
  );

  testWidgets('changed quote error prevents navigation to payment', (
    tester,
  ) async {
    service.reject = true;
    await show(tester);
    await tester.tap(find.text('Accepter et réserver'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Accepter et réserver').last,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Le devis a changé'), findsOneWidget);
    expect(navigation, isNull);
  });
}
