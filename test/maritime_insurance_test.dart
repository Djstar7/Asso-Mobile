import 'dart:async';

import 'package:asso/app/data/models/maritime.dart';
import 'package:asso/app/data/models/parcel_nature.dart';
import 'package:asso/app/data/providers/api_provider.dart';
import 'package:asso/app/data/providers/diaspo_service.dart';
import 'package:asso/app/data/providers/maritime_service.dart';
import 'package:asso/app/modules/chatdetail/controllers/chatdetail_controller.dart';
import 'package:asso/app/modules/diaspoBooking/widgets/parcel_insurance_form.dart';
import 'package:asso/app/modules/maritime/controllers/maritime_booking_controller.dart';
import 'package:asso/app/modules/maritime/controllers/maritime_controller.dart';
import 'package:asso/app/modules/maritime/views/maritime_contact_button.dart';
import 'package:asso/app/modules/maritime/views/maritime_insurance_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(DiaspoService());
    Get.put(MaritimeService());
  });

  tearDown(Get.reset);

  test('booking response parses insurance and explicit loss eligibility', () {
    final booking = MaritimeBooking.fromJson({
      'id': 12,
      'insurance_opt_in': true,
      'insurance_rate_applied': '0.04',
      'insurance_quote_amount': '850',
      'insurance_amount': '850',
      'insurance_status': 'active',
      'declared_value_currency': 'EUR',
      'claim_summary': {'status': 'under_review', 'payout_amount': 400},
      'claim_history': [
        {'status': 'submitted', 'created_at': '2026-10-18'},
      ],
      'insurance_history': [
        {'event': 'purchased', 'created_at': '2026-10-17'},
      ],
      'can_report_loss': true,
    });

    expect(booking.insuranceOptIn, isTrue);
    expect(booking.insuranceRateApplied, 0.04);
    expect(booking.insuranceQuoteAmount, 850);
    expect(booking.insuranceAmount, 850);
    expect(booking.insuranceStatus, 'active');
    expect(booking.claimSummary?['payout_amount'], 400);
    expect(booking.claimHistory, hasLength(1));
    expect(booking.insuranceHistory.single['event'], 'purchased');
    expect(booking.canReportLoss, isTrue);
  });

  test('requested French maritime insurance copy remains exact', () {
    const optIn = 'Je souhaite assurer mon colis contre les risques de perte.';
    const disclosure =
        'Cette assurance permet de prendre en charge le dédommagement du client en cas de perte du colis, conformément aux conditions d’assurance de la plateforme.';
    expect(Get.translations['fr_FR']?['maritime.form.insurance_opt_in'], optIn);
    expect(
      Get.translations['fr_FR']?['maritime.form.insurance_legal_disclosure'],
      disclosure,
    );
  });

  test(
    'maritime booking defaults insurance off and totals only charge opt-in',
    () {
      final controller = MaritimeBookingController();
      controller.departure.value = MaritimeDeparture(
        id: 1,
        partnerName: 'Maritime partner',
        departureDate: DateTime(2026, 11),
        bookingClosesOn: DateTime(2026, 10),
        dropoffDeadline: DateTime(2026, 10, 30),
        daysLeftToBook: 10,
        isBookable: true,
        remainingKg: 100,
        pricePerKg: 12,
        currency: 'EUR',
        status: 'open',
      );
      controller.kg.value = 2;
      controller.insurance.selectedNature.value = ParcelNature(
        id: 8,
        name: 'Documents',
        insuranceRate: 4,
        minInsuranceAmount: 0,
      );
      controller.insurance.valueController.text = '500';
      controller.insurance.insuranceAmount.value = 5.5;

      expect(controller.insuranceOptIn.value, isFalse);
      expect(controller.grandTotal, 24);
      expect(controller.bookingPayload('wallet')['insurance_opt_in'], isFalse);
      expect(controller.bookingPayload('wallet')['declared_value'], 500);
      expect(controller.bookingPayload('wallet')['parcel_nature_id'], 8);

      controller.insuranceOptIn.value = true;
      expect(controller.grandTotal, 29.5);
      expect(controller.bookingPayload('wallet')['insurance_opt_in'], isTrue);
      controller.onClose();
    },
  );

  testWidgets('insurance checkbox leaves parcel nature and value visible', (
    tester,
  ) async {
    final form = ParcelInsuranceForm(currency: () => 'EUR');
    form.natures.add(
      ParcelNature(
        id: 1,
        name: 'Téléphone',
        insuranceRate: 4,
        minInsuranceAmount: 0,
      ),
    );
    form.selectedNature.value = form.natures.first;
    form.valueController.text = '125.50';
    final optIn = false.obs;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MaritimeInsuranceSection(
              form: form,
              optIn: optIn,
              formatAmount: (amount) => '$amount EUR',
              decoration: const BoxDecoration(color: Colors.white),
              mutedColor: Colors.black54,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('125.50'), findsOneWidget);
    await tester.tap(
      find.text('Je souhaite assurer mon colis contre les risques de perte.'),
    );
    await tester.pump();

    expect(optIn.value, isTrue);
    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('125.50'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '125.50',
    );
    form.dispose();
  });

  testWidgets('shipped contact button exposes loading and error accessibly', (
    tester,
  ) async {
    final pending = Completer<ApiResponse>();
    final controller = MaritimeController(
      contactRequest: (_) => pending.future,
      conversationNavigator: (_) {},
    );
    final booking = _booking(status: 'shipped');
    await tester.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: MaritimeContactButton(booking: booking, controller: controller),
        ),
      ),
    );

    expect(find.byTooltip('Contacter la plateforme'), findsOneWidget);
    expect(find.bySemanticsLabel('Contacter la plateforme'), findsOneWidget);
    await tester.tap(find.byTooltip('Contacter la plateforme'));
    await tester.pump();
    expect(controller.contactingBookingIds, contains(booking.id));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(
      ApiResponse(
        success: false,
        message: 'Réseau indisponible',
        statusCode: 503,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Réseau indisponible'), findsOneWidget);
    expect(controller.contactingBookingIds, isNot(contains(booking.id)));
  });

  test(
    'contact opens returned conversation with editable draft only',
    () async {
      Map<String, dynamic>? openedConversation;
      var requests = 0;
      final controller = MaritimeController(
        contactRequest: (_) async {
          requests++;
          return ApiResponse(
            success: true,
            message: 'OK',
            statusCode: 200,
            data: {
              'data': {
                'conversation': {
                  'id': 44,
                  'other_user': {'id': 2, 'name': 'Compte officiel ASSO'},
                },
                'prefill_message': 'Bonjour, je vous contacte pour mon colis.',
              },
            },
          );
        },
        conversationNavigator: (conversation) {
          openedConversation = conversation;
        },
      );

      await controller.contactPlatform(_booking(status: 'shipped'));

      expect(requests, 1);
      expect(openedConversation?['id'], 44);
      expect(openedConversation?['name'], 'Compte officiel ASSO');
      expect(
        openedConversation?['default_message'],
        'Bonjour, je vous contacte pour mon colis.',
      );
      expect(openedConversation?['is_support'], isTrue);
      expect(
        ChatdetailController.draftFromConversation(openedConversation!),
        'Bonjour, je vous contacte pour mon colis.',
      );
    },
  );
}

MaritimeBooking _booking({required String status}) => MaritimeBooking(
  id: 20,
  kgBooked: 2,
  parcelsCount: 1,
  recipientName: 'Recipient',
  recipientPhone: '+33123456789',
  declaredValue: 100,
  freightTotal: 24,
  insuranceAmount: 0,
  totalPrice: 24,
  currency: 'EUR',
  confirmationCode: 'ABCD',
  status: status,
  statusLabel: status,
);
