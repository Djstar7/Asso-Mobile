import 'package:asso/app/core/widgets/order_progress_timeline.dart';
import 'package:asso/app/data/models/order_progress.dart';
import 'package:asso/app/modules/myOrder/models/customer_order_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retail and local orders follow the admin stages', () {
    for (final local in [false, true]) {
      for (final (status, payment, stage) in [
        ('pending', 'pending', 'awaiting_payment'),
        ('pending', 'paid', 'to_confirm'),
        ('confirmed', 'paid', 'preparing'),
        ('preparing', 'paid', 'preparing'),
        ('shipped', 'paid', 'shipped'),
        ('delivered', 'paid', 'delivered'),
        ('cancelled', 'paid', 'cancelled'),
      ]) {
        final order = CustomerOrder.fromMap({
          'status': status,
          'payment_status': payment,
          'has_local_products': local,
        });
        expect(order.progress!.stage, stage);
        expect(order.progress!.steps, isNot(contains('to_validate')));
        if (stage == 'to_confirm') {
          expect(
            order.statusLabel,
            local ? 'À confirmer par le vendeur' : 'À confirmer',
          );
        }
      }
    }
  });

  test('wholesale orders use the backend business stage', () {
    for (final stage in [...OrderProgress.wholesaleSteps, 'cancelled']) {
      final order = CustomerOrder.fromMap({
        'status': 'shipped',
        'is_wholesale': true,
        'wholesale_stage': stage,
      });
      expect(order.progress!.stage, stage);
      expect(order.statusLabel, OrderProgress.labelFor(stage));
      expect(order.statusLabel, isNot(contains('Douala')));
      expect(order.statusLabel, isNot(contains('SOLEX')));
    }
  });

  test(
    'agency pickup has its own arrival and handover stages for every order kind',
    () {
      for (final wholesale in [false, true]) {
        for (final (status, tracking, stage, label) in [
          (
            'shipped',
            'arrived_hub',
            'in_transit',
            'En acheminement vers l’agence',
          ),
          ('shipped', 'arrived', 'in_transit', 'En acheminement vers l’agence'),
          (
            'shipped',
            'ready_for_pickup',
            'ready_for_pickup',
            'Disponible au retrait en agence',
          ),
          (
            'delivered',
            'collected_at_agency',
            'delivered',
            'Retirée en agence',
          ),
        ]) {
          final progress = OrderProgress.fromOrder({
            'status': status,
            'is_wholesale': wholesale,
            'payment_status': 'paid',
            'delivery': {
              'is_carrier': true,
              'mode': 'carrier',
              'delivery_option': 'agency_pickup',
              'tracking_status': tracking,
            },
          });
          expect(progress.stage, stage);
          expect(progress.label, label);
          expect(progress.steps, contains('ready_for_pickup'));
          expect(progress.steps, isNot(contains('last_mile')));
          expect(progress.steps, isNot(contains('shipped')));
        }
      }
    },
  );

  test(
    'API progress is authoritative and uses the same labels in customer orders',
    () {
      final order = CustomerOrder.fromMap({
        'status': 'shipped',
        'progress': {
          'kind': 'wholesale',
          'delivery_option': 'agency_pickup',
          'stage': 'ready_for_pickup',
          'steps': [
            'awaiting_payment',
            'to_validate',
            'to_ship',
            'in_transit',
            'ready_for_pickup',
            'delivered',
          ],
        },
      });
      expect(order.statusLabel, 'Disponible au retrait en agence');
      expect(order.statusIcon, Icons.storefront_outlined);
    },
  );

  testWidgets('agency timeline shows collection instead of home delivery', (
    tester,
  ) async {
    const progress = OrderProgress(
      stage: 'ready_for_pickup',
      kind: 'retail',
      isAgencyPickup: true,
      steps: [
        'awaiting_payment',
        'to_confirm',
        'preparing',
        'in_transit',
        'ready_for_pickup',
        'delivered',
      ],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OrderProgressTimeline(progress: progress)),
      ),
    );
    expect(find.text('Disponible au retrait en agence'), findsOneWidget);
    expect(find.text('Retirée en agence'), findsOneWidget);
    expect(find.text('Livraison locale'), findsNothing);
    expect(find.text('En livraison'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
    expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
  });

  testWidgets('cancelled orders do not show future delivery stages', (
    tester,
  ) async {
    final progress = OrderProgress.fromOrder({'status': 'cancelled'});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OrderProgressTimeline(progress: progress)),
      ),
    );
    expect(find.text('Annulée'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });
}
