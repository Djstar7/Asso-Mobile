class PushPreferences {
  static const categoryKeys = [
    'orders',
    'payments',
    'messages',
    'disputes',
    'real_estate',
    'marketing',
    'system',
  ];
  final bool enabled;
  final Map<String, bool> categories;
  PushPreferences({
    this.enabled = true,
    Map<String, bool> categories = const {},
  }) : categories = {
         for (final key in categoryKeys) key: categories[key] ?? true,
       };

  factory PushPreferences.fromMap(Map<String, dynamic> data) => PushPreferences(
    enabled: data['enabled'] != false,
    categories: {
      for (final entry in (data['categories'] as Map? ?? {}).entries)
        if (categoryKeys.contains(entry.key))
          '${entry.key}': entry.value == true,
    },
  );
  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'categories': categories,
  };
  PushPreferences copyWith({bool? enabled, String? category, bool? allowed}) =>
      PushPreferences(
        enabled: enabled ?? this.enabled,
        categories: {
          ...categories,
          if (category != null && allowed != null) category: allowed,
        },
      );
  bool allows(String category) => enabled && (categories[category] ?? false);
  static String categoryFor(String type) {
    if (type.contains('dispute')) {
      return 'disputes';
    }
    if ([
      'new_product',
      'sponsored_product',
      'new_diaspo_offer',
      'announcement',
      'marketing_digest',
    ].contains(type)) {
      return 'marketing';
    }
    if (type.startsWith('real_estate_') || type == 'new_real_estate_listing') {
      return 'real_estate';
    }
    if (RegExp(r'^(wallet_|payment_|stripe_)').hasMatch(type)) {
      return 'payments';
    }
    if (RegExp(
          r'^(order$|new_order_|wholesale_order_|order_|vendor_order_|delivery_|new_delivery_|shipment_|maritime_|agency_)',
        ).hasMatch(type) ||
        type == 'vendor_funds_released') {
      return 'orders';
    }
    if (type == 'new_message' ||
        RegExp(r'^(chat_|conversation_)').hasMatch(type)) {
      return 'messages';
    }
    return 'system';
  }
}
