import 'package:asso/app/modules/disputes/models/dispute_models.dart';
import 'package:asso/app/modules/myOrder/models/customer_order_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('independent receipt carries the objection deadline and evidence', () {
    final dispute = Dispute.fromMap({
      'id': 7,
      'status': 'return',
      'product': {'name': 'Sac', 'quantity': 1, 'total_price': 1100},
      'receipts': [
        {
          'id': 4,
          'shipment_id': 3,
          'evidence_id': 12,
          'evidence_url': 'https://example.com/proof.jpg',
          'location': 'Agence Solex',
          'contest_until': '2026-10-26T12:00:00Z',
          'contested_at': null,
          'accepted_at': null,
        },
      ],
      'actions': {'prepare_replacement': true},
    });
    expect(dispute.receipts.single['evidence_id'], 12);
    expect(dispute.receipts.single['location'], 'Agence Solex');
    expect(
      DateTime.parse(dispute.receipts.single['contest_until']),
      DateTime.utc(2026, 10, 26, 12),
    );
    expect(dispute.action('prepare_replacement'), isTrue);
  });

  test(
    'paid undelivered orders expose claim availability and subsequent decision',
    () {
      final order = CustomerOrder.fromMap({
        'id': 9,
        'status': 'confirmed',
        'items': [],
        'can_report_delivery': true,
        'delivery_claim': {'id': 2, 'status': 'open'},
      });
      expect(order.canReportDelivery, isTrue);
      expect(order.deliveryClaim?['status'], 'open');
      final refunded = CustomerOrder.fromMap({
        'id': 9,
        'status': 'cancelled',
        'items': [],
        'can_report_delivery': false,
        'delivery_claim': {
          'id': 2,
          'status': 'refunded',
          'refund_amount': '900.00',
        },
      });
      expect(refunded.canReportDelivery, isFalse);
      expect(refunded.deliveryClaim?['refund_amount'], '900.00');
    },
  );

  test('older payloads remain readable without resolution metadata', () {
    final order = CustomerOrder.fromMap({'id': 9, 'items': []});
    final dispute = Dispute.fromMap({
      'id': 1,
      'product': {'name': 'Test'},
    });
    expect(order.canReportDelivery, isFalse);
    expect(order.deliveryClaim, isNull);
    expect(dispute.receipts, isEmpty);
  });
}
