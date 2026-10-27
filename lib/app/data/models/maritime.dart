import 'package:get/get.dart';

import 'parcel_nature.dart';

double _d(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

/// QG d'un partenaire maritime : dépôt (départ) ou retrait (arrivée).
class MaritimeHub {
  final int id;
  final String name;
  final String country;
  final String countryName;
  final String city;
  final String address;
  final String? phone;
  final String? openingHours;

  MaritimeHub({
    required this.id,
    required this.name,
    required this.country,
    required this.countryName,
    required this.city,
    required this.address,
    this.phone,
    this.openingHours,
  });

  factory MaritimeHub.fromJson(Map<String, dynamic> json) => MaritimeHub(
    id: json['id'] as int,
    name: json['name']?.toString() ?? '',
    country: json['country']?.toString() ?? '',
    countryName: json['country_name']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    phone: json['phone']?.toString(),
    openingHours: json['opening_hours']?.toString(),
  );

  String get fullAddress => [
    name,
    address,
    city,
    countryName.isNotEmpty ? countryName : country,
  ].where((part) => part.trim().isNotEmpty).join(', ');
}

/// Départ maritime d'un partenaire entre deux QG.
class MaritimeDeparture {
  final bool requiresQuote;
  final int id;
  final String partnerName;
  final String? partnerLogo;
  final MaritimeHub? originHub;
  final MaritimeHub? destinationHub;
  final DateTime departureDate;
  final DateTime? estimatedArrivalDate;
  final DateTime bookingClosesOn;
  final DateTime dropoffDeadline;
  final int daysLeftToBook;
  final bool isBookable;
  final double remainingKg;

  /// Prix public au kilo (commission ASSO incluse), dans [currency].
  final double pricePerKg;

  /// Départ tarifé au m³ : tarif public au m³ et kilos comptés pour 1 m³.
  final double? pricePerCbm;
  final double? kgPerCbm;
  final String currency;
  final String status;
  final String transportMode;
  final String cargoCategory;
  final List<MaritimeCargoOption> cargoOptions;
  final int? transitDaysMin;
  final int? transitDaysMax;
  final int? frequencyDays;
  final bool meetingDetailsAvailable;

  String get commercialSummary => commercialSummaryFor(cargoCategory);

  String commercialSummaryFor(String category) => [
    'partner_freight.$transportMode'.tr,
    'partner_freight.$category'.tr,
    if (transitDaysMin != null && transitDaysMax != null)
      'partner_freight.transit_days'.trParams({
        'min': '$transitDaysMin',
        'max': '$transitDaysMax',
      }),
    frequencyDays == null
        ? 'partner_freight.occasional'.tr
        : 'partner_freight.frequency'.trParams({'days': '$frequencyDays'}),
  ].join(' · ');
  final String? notes;

  MaritimeDeparture({
    this.requiresQuote = false,
    required this.id,
    required this.partnerName,
    this.partnerLogo,
    this.originHub,
    this.destinationHub,
    required this.departureDate,
    this.estimatedArrivalDate,
    required this.bookingClosesOn,
    required this.dropoffDeadline,
    required this.daysLeftToBook,
    required this.isBookable,
    required this.remainingKg,
    required this.pricePerKg,
    this.pricePerCbm,
    this.kgPerCbm,
    required this.currency,
    required this.status,
    this.transportMode = 'sea',
    this.cargoCategory = 'general',
    this.cargoOptions = const [],
    this.transitDaysMin,
    this.transitDaysMax,
    this.frequencyDays,
    this.meetingDetailsAvailable = false,
    this.notes,
  });

  bool get isSea => transportMode == 'sea';
  double get remainingCbm => remainingKg / (kgPerCbm ?? 1000);
  double get publicCbmRate => pricePerCbm ?? pricePerKg * (kgPerCbm ?? 1000);

  bool get isPricedPerCbm => (pricePerCbm ?? 0) > 0 && (kgPerCbm ?? 0) > 0;

  /// Volume (m³) correspondant à des kilos, pour un départ tarifé au m³.
  double? volumeForKg(double kg) => isPricedPerCbm ? kg / kgPerCbm! : null;

  factory MaritimeDeparture.fromJson(Map<String, dynamic> json) {
    final meetingVisible = json['meeting_details_available'] == true;
    MaritimeHub? hub(dynamic value) {
      if (value is! Map) return null;
      final data = Map<String, dynamic>.from(value);
      if (!meetingVisible) {
        for (final field in [
          'name',
          'address',
          'phone',
          'opening_hours',
          'latitude',
          'longitude',
        ]) {
          data[field] = null;
        }
      }
      return MaritimeHub.fromJson(data);
    }

    return MaritimeDeparture(
      id: json['id'] as int,
      partnerName: 'Diaspo Exchange',
      partnerLogo: null,
      originHub: hub(json['origin_hub']),
      destinationHub: hub(json['destination_hub']),
      departureDate: _date(json['departure_date']) ?? DateTime.now(),
      estimatedArrivalDate: _date(json['estimated_arrival_date']),
      bookingClosesOn: _date(json['booking_closes_on']) ?? DateTime.now(),
      dropoffDeadline: _date(json['dropoff_deadline']) ?? DateTime.now(),
      daysLeftToBook: (json['days_left_to_book'] as num?)?.toInt() ?? -1,
      isBookable: json['is_bookable'] == true,
      remainingKg: _d(json['remaining_kg']),
      requiresQuote: json['requires_quote'] == true,
      pricePerKg: _d(json['price_per_kg']),
      pricePerCbm: json['price_per_cbm'] == null
          ? null
          : _d(json['price_per_cbm']),
      kgPerCbm: json['kg_per_cbm'] == null ? null : _d(json['kg_per_cbm']),
      currency: json['currency']?.toString() ?? 'EUR',
      status: json['status']?.toString() ?? 'open',
      transportMode: json['transport_mode']?.toString() ?? 'sea',
      cargoCategory: json['cargo_category']?.toString() ?? 'general',
      cargoOptions: (json['cargo_options'] as List? ?? [])
          .whereType<Map>()
          .map(
            (option) =>
                MaritimeCargoOption.fromJson(Map<String, dynamic>.from(option)),
          )
          .toList(),
      transitDaysMin: int.tryParse('${json['transit_days_min']}'),
      transitDaysMax: int.tryParse('${json['transit_days_max']}'),
      frequencyDays: int.tryParse('${json['frequency_days']}'),
      meetingDetailsAvailable: meetingVisible,
      notes: meetingVisible ? json['notes']?.toString() : null,
    );
  }
}

class MaritimeCargoOption {
  const MaritimeCargoOption({
    required this.category,
    required this.pricePerUnit,
    required this.unit,
    required this.currency,
  });

  final String category;
  final double pricePerUnit;
  final String unit;
  final String currency;

  factory MaritimeCargoOption.fromJson(Map<String, dynamic> json) =>
      MaritimeCargoOption(
        category: json['cargo_category']?.toString() ?? 'general',
        pricePerUnit: _d(json['price_per_unit']),
        unit: json['unit']?.toString() ?? 'CBM',
        currency: json['currency']?.toString() ?? 'EUR',
      );
}

/// Envoi maritime d'un expéditeur.
class MaritimeBooking {
  final int id;
  final MaritimeDeparture? departure;
  final double kgBooked;
  final int parcelsCount;
  final String recipientName;
  final String recipientPhone;
  final ParcelNature? parcelNature;
  final double declaredValue;
  final String declaredValueCurrency;
  final bool insuranceOptIn;
  final double insuranceRateApplied;
  final double insuranceQuoteAmount;
  final String? insuranceStatus;
  final Map<String, dynamic>? claimSummary;
  final List<Map<String, dynamic>> claimHistory;
  final List<Map<String, dynamic>> insuranceHistory;
  final bool canReportLoss;
  final double freightTotal;

  /// Assurance réellement encaissée (et non le devis indicatif).
  final double insuranceAmount;
  final double totalPrice;
  final String currency;
  final DateTime? dropoffDeadline;
  final String confirmationCode;
  final String status;
  final String statusLabel;
  final double? refundedAmount;
  final String? cancelReason;

  MaritimeBooking({
    required this.id,
    this.departure,
    required this.kgBooked,
    required this.parcelsCount,
    required this.recipientName,
    required this.recipientPhone,
    this.parcelNature,
    required this.declaredValue,
    this.declaredValueCurrency = 'EUR',
    this.insuranceOptIn = false,
    this.insuranceRateApplied = 0,
    this.insuranceQuoteAmount = 0,
    this.insuranceStatus,
    this.claimSummary,
    this.claimHistory = const [],
    this.insuranceHistory = const [],
    this.canReportLoss = false,
    required this.freightTotal,
    required this.insuranceAmount,
    required this.totalPrice,
    required this.currency,
    this.dropoffDeadline,
    required this.confirmationCode,
    required this.status,
    required this.statusLabel,
    this.refundedAmount,
    this.cancelReason,
  });

  factory MaritimeBooking.fromJson(Map<String, dynamic> json) {
    final summary =
        json['claim_summary'] ?? json['claim'] ?? json['loss_report_summary'];
    final history = json['claim_history'] ?? json['loss_reports'];
    final insuranceHistory = json['insurance_history'];
    final summaryMap = summary is Map
        ? Map<String, dynamic>.from(summary)
        : null;
    final canReportLoss =
        json['can_report_loss'] == true ||
        json['loss_report_eligible'] == true ||
        json['insurance_claim_eligible'] == true ||
        summaryMap?['can_report_loss'] == true ||
        summaryMap?['eligible'] == true;

    return MaritimeBooking(
      id: (json['id'] as num).toInt(),
      departure: json['departure'] is Map
          ? MaritimeDeparture.fromJson(
              Map<String, dynamic>.from(json['departure']),
            )
          : null,
      kgBooked: _d(json['kg_booked']),
      parcelsCount: (json['parcels_count'] as num?)?.toInt() ?? 1,
      recipientName:
          '${json['recipient_first_name'] ?? ''} ${json['recipient_last_name'] ?? ''}'
              .trim(),
      recipientPhone: json['recipient_phone']?.toString() ?? '',
      parcelNature: json['parcel_nature'] is Map
          ? ParcelNature.fromJson(
              Map<String, dynamic>.from(json['parcel_nature']),
            )
          : null,
      declaredValue: _d(json['declared_value']),
      declaredValueCurrency:
          json['declared_value_currency']?.toString() ?? 'EUR',
      insuranceOptIn: json['insurance_opt_in'] == true,
      insuranceRateApplied: _d(json['insurance_rate_applied']),
      insuranceQuoteAmount: _d(json['insurance_quote_amount']),
      insuranceStatus: json['insurance_status']?.toString(),
      claimSummary: summaryMap,
      claimHistory: history is List
          ? history
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const [],
      insuranceHistory: insuranceHistory is List
          ? insuranceHistory
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const [],
      canReportLoss: canReportLoss,
      freightTotal: _d(json['freight_total']),
      insuranceAmount: _d(json['insurance_amount']),
      totalPrice: _d(json['total_price']),
      currency: json['currency']?.toString() ?? 'EUR',
      dropoffDeadline: _date(json['dropoff_deadline']),
      confirmationCode: json['confirmation_code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      statusLabel: json['status_label']?.toString() ?? '',
      refundedAmount: json['refunded_amount'] == null
          ? null
          : _d(json['refunded_amount']),
      cancelReason: json['cancel_reason']?.toString(),
    );
  }

  /// Annulable par l'expéditeur tant que le colis n'est pas déposé.
  bool get canCancel => status == 'paid';
}
