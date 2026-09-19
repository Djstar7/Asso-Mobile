/// Modèles partagés de la livraison (lot P4) : devis d'un partenaire, détail
/// du prix, grille tarifaire et suivi daté d'une commande.
library;

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}

String? _toText(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty || text == 'null') ? null : text;
}

/// Ligne de la grille tarifaire d'une route / zone.
class DeliveryPriceGridRow {
  final String label;
  final double price;

  const DeliveryPriceGridRow({required this.label, required this.price});

  static List<DeliveryPriceGridRow> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (row) => DeliveryPriceGridRow(
            label: row['label']?.toString() ?? '',
            price: _toDouble(row['price']) ?? 0,
          ),
        )
        .where((row) => row.label.isNotEmpty)
        .toList();
  }
}

/// Détail du calcul du prix de livraison renvoyé par l'API.
class DeliveryBreakdown {
  /// Volets du prix HT (ex. transport d'agence à agence + livraison à domicile).
  final List<DeliveryPriceGridRow> legs;
  final double? weightKg;
  final String? rangeLabel;
  final double? rangePrice;
  final double extraKg;
  final double? extraPerKg;
  final double extraPrice;
  final double? carrierPriceHt;
  final bool pricesExcludeVat;
  final double? vatRate;
  final double vatAmount;
  final double? carrierPrice;
  final double assoCommission;
  final double? total;

  const DeliveryBreakdown({
    this.legs = const [],
    this.weightKg,
    this.rangeLabel,
    this.rangePrice,
    this.extraKg = 0,
    this.extraPerKg,
    this.extraPrice = 0,
    this.carrierPriceHt,
    this.pricesExcludeVat = false,
    this.vatRate,
    this.vatAmount = 0,
    this.carrierPrice,
    this.assoCommission = 0,
    this.total,
  });

  static DeliveryBreakdown? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    return DeliveryBreakdown(
      legs: DeliveryPriceGridRow.listFrom(raw['legs']),
      weightKg: _toDouble(raw['weight_kg']),
      rangeLabel: _toText(raw['range_label']),
      rangePrice: _toDouble(raw['range_price']),
      extraKg: _toDouble(raw['extra_kg']) ?? 0,
      extraPerKg: _toDouble(raw['extra_per_kg']),
      extraPrice: _toDouble(raw['extra_price']) ?? 0,
      carrierPriceHt: _toDouble(raw['carrier_price_ht']),
      pricesExcludeVat: raw['prices_exclude_vat'] == true,
      vatRate: _toDouble(raw['vat_rate']),
      vatAmount: _toDouble(raw['vat_amount']) ?? 0,
      carrierPrice: _toDouble(raw['carrier_price']),
      assoCommission: _toDouble(raw['asso_commission']) ?? 0,
      total: _toDouble(raw['total']),
    );
  }
}

/// Étape datée du suivi d'une commande.
class DeliveryTimelineStep {
  final String step;
  final String label;
  final String? location;
  final String? note;
  final String? actorType;
  final DateTime? occurredAt;

  const DeliveryTimelineStep({
    required this.step,
    required this.label,
    this.location,
    this.note,
    this.actorType,
    this.occurredAt,
  });

  static List<DeliveryTimelineStep> listFrom(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      final step = e['step']?.toString() ?? '';
      return DeliveryTimelineStep(
        step: step,
        label: _toText(e['label']) ?? DeliveryInfo.stepLabel(step),
        location: _toText(e['location']),
        note: _toText(e['note']),
        actorType: _toText(e['actor_type']),
        occurredAt: DateTime.tryParse(e['occurred_at']?.toString() ?? '')
            ?.toLocal(),
      );
    }).toList();
  }
}

/// Bloc `delivery` des commandes (acheteur et vendeur).
class DeliveryInfo {
  final String mode; // local | carrier
  final bool isCarrier;
  final String? companyName;
  final String? serviceTypeLabel;
  final String? serviceModeLabel;
  final String? routeLabel;
  final String? leadTime;
  final String? conditions;
  final List<DeliveryPriceGridRow> priceGrid;
  final double? weightKg;
  final DeliveryBreakdown? breakdown;
  final String? carrierTrackingNumber;
  final String? carrierTrackingUrl;
  final String? trackingStatus;
  final String? trackingStatusLabel;
  final bool canConfirmReception;
  final List<DeliveryTimelineStep> timeline;

  const DeliveryInfo({
    this.mode = 'local',
    this.isCarrier = false,
    this.companyName,
    this.serviceTypeLabel,
    this.serviceModeLabel,
    this.routeLabel,
    this.leadTime,
    this.conditions,
    this.priceGrid = const [],
    this.weightKg,
    this.breakdown,
    this.carrierTrackingNumber,
    this.carrierTrackingUrl,
    this.trackingStatus,
    this.trackingStatusLabel,
    this.canConfirmReception = false,
    this.timeline = const [],
  });

  static DeliveryInfo? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final mode = raw['mode']?.toString() ?? 'local';
    return DeliveryInfo(
      mode: mode,
      isCarrier: raw['is_carrier'] == true || mode == 'carrier',
      companyName: _toText(raw['company_name']),
      serviceTypeLabel: _toText(raw['service_type_label']),
      serviceModeLabel: _toText(raw['service_mode_label']),
      routeLabel: _toText(raw['route_label']),
      leadTime: _toText(raw['lead_time']),
      conditions: _toText(raw['conditions']),
      priceGrid: DeliveryPriceGridRow.listFrom(raw['price_grid']),
      weightKg: _toDouble(raw['weight_kg']),
      breakdown: DeliveryBreakdown.fromMap(raw['breakdown']),
      carrierTrackingNumber: _toText(raw['carrier_tracking_number']),
      carrierTrackingUrl: _toText(raw['carrier_tracking_url']),
      trackingStatus: _toText(raw['tracking_status']),
      trackingStatusLabel: _toText(raw['tracking_status_label']),
      canConfirmReception: raw['can_confirm_reception'] == true,
      timeline: DeliveryTimelineStep.listFrom(raw['timeline']),
    );
  }

  /// Étapes que le vendeur peut ajouter pour une commande transporteur.
  static const vendorTrackingSteps = <String, String>{
    'in_transit': 'En transit',
    'customs': 'En dédouanement',
    'arrived': 'Arrivé dans la ville de destination',
    'ready_for_pickup': 'Disponible au retrait en agence',
  };

  static String stepLabel(String step) {
    switch (step) {
      case 'pending':
        return 'Commande passée';
      case 'confirmed':
        return 'Validée par le vendeur';
      case 'preparing':
        return 'En préparation';
      case 'out_for_delivery':
        return 'En cours de livraison';
      case 'handed_to_carrier':
        return 'Remis au transporteur';
      case 'in_transit':
        return 'En transit';
      case 'customs':
        return 'En dédouanement';
      case 'arrived':
        return 'Arrivé dans la ville de destination';
      case 'ready_for_pickup':
        return 'Disponible au retrait en agence';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return step;
    }
  }
}

/// Devis d'un partenaire de livraison (GET /v1/delivery/partners).
class DeliveryPartnerQuote {
  final Map<String, dynamic> raw;

  const DeliveryPartnerQuote(this.raw);

  String get deliveryMode => raw['delivery_mode']?.toString() ?? 'local';
  bool get isCarrier => deliveryMode == 'carrier';
  String get serviceType => raw['service_type']?.toString() ?? 'local';
  String get serviceMode => raw['service_mode']?.toString() ?? 'door_to_door';
  bool get isAgencyToAgency => serviceMode == 'agency_to_agency';
  String get companyName => _toText(raw['company_name']) ?? 'Partenaire';
  String? get companyLogo => _toText(raw['company_logo']);
  String? get zoneName => _toText(raw['zone_name']);
  String? get routeLabel => _toText(raw['route_label']);
  String? get city => _toText(raw['city']);
  String? get leadTime => _toText(raw['lead_time']);
  String? get conditions => _toText(raw['conditions']);
  double? get distanceKm => _toDouble(raw['distance_km']);
  double? get maxWeightKg => _toDouble(raw['max_weight_kg']);
  int? get companyId => int.tryParse(raw['company_id']?.toString() ?? '');
  int? get zoneId => int.tryParse(raw['zone_id']?.toString() ?? '');
  int? get routeId => int.tryParse(raw['route_id']?.toString() ?? '');
  int? get gridId => int.tryParse(raw['grid_id']?.toString() ?? '');
  String? get vehicle => _toText(raw['vehicle']);
  String? get vehicleLabel => _toText(raw['vehicle_label']);
  double get price => _toDouble(raw['delivery_price']) ?? 0;
  double get assoCommission => _toDouble(raw['asso_commission']) ?? 0;
  List<DeliveryPriceGridRow> get priceGrid =>
      DeliveryPriceGridRow.listFrom(raw['price_grid']);
  DeliveryBreakdown? get breakdown => DeliveryBreakdown.fromMap(raw['breakdown']);

  /// Catégorie courte affichée en puce : Urbain / Interurbain / International.
  String get categoryLabel {
    switch (serviceType) {
      case 'intercity':
        return 'Interurbain';
      case 'international':
        return 'International';
      default:
        return 'Urbain';
    }
  }

  String get serviceTypeLabel =>
      _toText(raw['service_type_label']) ?? categoryLabel;

  String get serviceModeLabel =>
      _toText(raw['service_mode_label']) ??
      (isAgencyToAgency
          ? "D'agence en agence (dépôt et retrait en agence)"
          : 'Livraison à domicile');

  /// Libellé du trajet : route transporteur, sinon zone urbaine.
  String? get routeOrZone => routeLabel ?? zoneName;

  /// Option choisie : retrait en agence ou livraison à domicile.
  bool get isAgencyPickup => raw['delivery_option']?.toString() == 'agency_pickup';
  String get deliveryOptionLabel =>
      _toText(raw['delivery_option_label']) ??
      (isAgencyPickup ? 'Retrait en agence' : 'Livraison à domicile');

  /// Avis explicite quand le colis est à retirer en agence.
  String? get pickupNotice {
    if (!isAgencyPickup) return null;
    final where = city != null ? ' de $city' : '';
    return 'Vous retirerez votre colis à l’agence $companyName$where.';
  }

  /// Identifie un devis (même partenaire + même zone/route).
  String get key =>
      '${raw['company_id']}-${raw['zone_id']}-${raw['route_id']}-${raw['grid_id']}-${raw['vehicle']}';
}

/// Formatage commun du poids (« 6 kg », « 2,5 kg »).
String formatKg(double? kg) {
  if (kg == null) return '—';
  final rounded = kg == kg.roundToDouble()
      ? kg.toStringAsFixed(0)
      : kg.toStringAsFixed(kg * 10 == (kg * 10).roundToDouble() ? 1 : 2);
  return '${rounded.replaceAll('.', ',')} kg';
}

/// Formatage du taux de TVA (« 19,25 % »).
String formatRate(double? rate) {
  if (rate == null) return '';
  final text = rate == rate.roundToDouble()
      ? rate.toStringAsFixed(0)
      : rate.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  return '${text.replaceAll('.', ',')} %';
}
