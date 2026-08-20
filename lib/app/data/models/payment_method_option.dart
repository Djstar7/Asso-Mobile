/// Un moyen de paiement entrant proposé par le backend (`/v1/payments/methods`).
///
/// Le backend renvoie TOUS les moyens (jamais masqués selon le pays). Un moyen
/// est simplement `available = false` (à griser côté UI) quand il est désactivé
/// ou que le montant est inférieur à son minimum. `convertedAmount`/`targetCurrency`
/// donnent le montant recalculé dans la devise du rail (via les taux stockés).
class PaymentMethodOption {
  final String code; // kpay | paypal | stripe
  final String label;
  final String subtitle;
  final String flow; // phone | redirect
  final bool enabled;
  final bool available;
  final String? unavailableReason; // disabled | below_min | null
  final double? minAmount; // dans minCurrency
  final String minCurrency;
  final String? targetCurrency; // devise d'encaissement du rail (null pour kpay)
  final double? convertedAmount; // montant converti dans targetCurrency (null pour kpay)

  const PaymentMethodOption({
    required this.code,
    required this.label,
    required this.subtitle,
    required this.flow,
    required this.enabled,
    required this.available,
    required this.minCurrency,
    this.unavailableReason,
    this.minAmount,
    this.targetCurrency,
    this.convertedAmount,
  });

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    double? toD(dynamic v) => v == null ? null : (v as num).toDouble();
    return PaymentMethodOption(
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      flow: json['flow']?.toString() ?? 'phone',
      enabled: json['enabled'] == true,
      available: json['available'] == true,
      unavailableReason: json['unavailable_reason']?.toString(),
      minAmount: toD(json['min_amount']),
      minCurrency: json['min_currency']?.toString() ?? 'XAF',
      targetCurrency: json['target_currency']?.toString(),
      convertedAmount: toD(json['converted_amount']),
    );
  }
}
