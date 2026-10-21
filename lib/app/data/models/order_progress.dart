import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'delivery_info.dart';

/// Parcours acheteur calculé avec les étapes métier de l'administration.
class OrderProgress {
  static const wholesaleSteps = [
    'awaiting_payment',
    'to_validate',
    'to_ship',
    'in_transit',
    'last_mile',
    'delivered',
  ];
  static const retailSteps = [
    'awaiting_payment',
    'to_confirm',
    'preparing',
    'shipped',
    'delivered',
  ];
  static const filters = [
    'awaiting_payment',
    'to_confirm',
    'to_validate',
    'to_ship',
    'preparing',
    'shipped',
    'in_transit',
    'last_mile',
    'ready_for_pickup',
    'delivered',
    'cancelled',
  ];

  final String stage;
  final String kind;
  final bool isAgencyPickup;
  final List<String> steps;

  const OrderProgress({
    required this.stage,
    required this.kind,
    required this.isAgencyPickup,
    required this.steps,
  });

  factory OrderProgress.fromOrder(Map<String, dynamic> order) {
    final raw = order['progress'];
    if (raw is Map && raw['stage'] is String && raw['steps'] is List) {
      final steps = (raw['steps'] as List).whereType<String>().toList();
      final stage = raw['stage'] as String;
      if (steps.contains(stage)) {
        return OrderProgress(
          stage: stage,
          kind: raw['kind']?.toString() ?? 'retail',
          isAgencyPickup: raw['delivery_option'] == 'agency_pickup',
          steps: steps,
        );
      }
    }

    // Compatibilité avec les versions de l'API sans bloc progress.
    final wholesale = order['is_wholesale'] == true;
    final agency =
        DeliveryInfo.fromMap(order['delivery'])?.deliveryOption ==
        'agency_pickup';
    final status = order['status']?.toString() ?? 'pending';
    final paid = order['payment_status'] == 'paid';
    var stage = switch (status) {
      'cancelled' || 'delivered' => status,
      'pending' =>
        paid ? (wholesale ? 'to_validate' : 'to_confirm') : 'awaiting_payment',
      'confirmed' || 'preparing' => wholesale ? 'to_ship' : 'preparing',
      _ => wholesale ? 'in_transit' : 'shipped',
    };
    if (wholesale && filters.contains(order['wholesale_stage'])) {
      stage = order['wholesale_stage'] as String;
    }
    if (agency && status == 'shipped') {
      stage = order['delivery']?['tracking_status'] == 'ready_for_pickup'
          ? 'ready_for_pickup'
          : 'in_transit';
    }
    final steps = agency
        ? [
            'awaiting_payment',
            if (wholesale) ...[
              'to_validate',
              'to_ship',
            ] else ...[
              'to_confirm',
              'preparing',
            ],
            'in_transit',
            'ready_for_pickup',
            'delivered',
          ]
        : wholesale
        ? wholesaleSteps
        : retailSteps;
    return OrderProgress(
      stage: stage,
      kind: wholesale
          ? 'wholesale'
          : order['has_local_products'] == true
          ? 'local'
          : 'retail',
      isAgencyPickup: agency,
      steps: stage == 'cancelled' ? const ['cancelled'] : steps,
    );
  }

  static String labelFor(String stage) => 'order_progress.$stage'.tr;

  String labelForStep(String step) {
    if (step == 'to_confirm' && kind == 'local') {
      return 'order_progress.to_confirm_seller'.tr;
    }
    if (isAgencyPickup && step == 'in_transit') {
      return 'order_progress.to_agency'.tr;
    }
    if (isAgencyPickup && step == 'delivered') {
      return 'order_progress.collected_at_agency'.tr;
    }
    return labelFor(step);
  }

  String get label => labelForStep(stage);
  bool get isCancelled => stage == 'cancelled';
  int get index => steps.indexOf(stage);

  IconData get icon => switch (stage) {
    'awaiting_payment' => Icons.payments_outlined,
    'to_validate' || 'to_confirm' => Icons.hourglass_top_rounded,
    'to_ship' || 'preparing' => Icons.inventory_2_outlined,
    'in_transit' || 'shipped' => Icons.local_shipping_outlined,
    'last_mile' => Icons.delivery_dining_outlined,
    'ready_for_pickup' => Icons.storefront_outlined,
    'delivered' =>
      isAgencyPickup ? Icons.inventory_2_outlined : Icons.task_alt_rounded,
    _ => Icons.cancel_outlined,
  };
}
