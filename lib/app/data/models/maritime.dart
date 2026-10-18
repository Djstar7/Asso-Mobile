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

  String get fullAddress => '$name, $address, $city';
}

/// Départ maritime d'un partenaire entre deux QG.
class MaritimeDeparture {
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
  final String? notes;

  MaritimeDeparture({
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
    this.notes,
  });

  bool get isPricedPerCbm => (pricePerCbm ?? 0) > 0 && (kgPerCbm ?? 0) > 0;

  /// Volume (m³) correspondant à des kilos, pour un départ tarifé au m³.
  double? volumeForKg(double kg) => isPricedPerCbm ? kg / kgPerCbm! : null;

  factory MaritimeDeparture.fromJson(Map<String, dynamic> json) {
    final partner = json['partner'] as Map?;
    return MaritimeDeparture(
      id: json['id'] as int,
      partnerName: partner?['name']?.toString() ?? '',
      partnerLogo: partner?['logo']?.toString(),
      originHub: json['origin_hub'] is Map
          ? MaritimeHub.fromJson(Map<String, dynamic>.from(json['origin_hub']))
          : null,
      destinationHub: json['destination_hub'] is Map
          ? MaritimeHub.fromJson(Map<String, dynamic>.from(json['destination_hub']))
          : null,
      departureDate: _date(json['departure_date']) ?? DateTime.now(),
      estimatedArrivalDate: _date(json['estimated_arrival_date']),
      bookingClosesOn: _date(json['booking_closes_on']) ?? DateTime.now(),
      dropoffDeadline: _date(json['dropoff_deadline']) ?? DateTime.now(),
      daysLeftToBook: (json['days_left_to_book'] as num?)?.toInt() ?? -1,
      isBookable: json['is_bookable'] == true,
      remainingKg: _d(json['remaining_kg']),
      pricePerKg: _d(json['price_per_kg']),
      pricePerCbm: json['price_per_cbm'] == null ? null : _d(json['price_per_cbm']),
      kgPerCbm: json['kg_per_cbm'] == null ? null : _d(json['kg_per_cbm']),
      currency: json['currency']?.toString() ?? 'EUR',
      status: json['status']?.toString() ?? 'open',
      notes: json['notes']?.toString(),
    );
  }
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
  final double freightTotal;
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

  factory MaritimeBooking.fromJson(Map<String, dynamic> json) => MaritimeBooking(
        id: json['id'] as int,
        departure: json['departure'] is Map
            ? MaritimeDeparture.fromJson(Map<String, dynamic>.from(json['departure']))
            : null,
        kgBooked: _d(json['kg_booked']),
        parcelsCount: (json['parcels_count'] as num?)?.toInt() ?? 1,
        recipientName:
            '${json['recipient_first_name'] ?? ''} ${json['recipient_last_name'] ?? ''}'.trim(),
        recipientPhone: json['recipient_phone']?.toString() ?? '',
        parcelNature: json['parcel_nature'] is Map
            ? ParcelNature.fromJson(Map<String, dynamic>.from(json['parcel_nature']))
            : null,
        declaredValue: _d(json['declared_value']),
        freightTotal: _d(json['freight_total']),
        insuranceAmount: _d(json['insurance_amount']),
        totalPrice: _d(json['total_price']),
        currency: json['currency']?.toString() ?? 'EUR',
        dropoffDeadline: _date(json['dropoff_deadline']),
        confirmationCode: json['confirmation_code']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        statusLabel: json['status_label']?.toString() ?? '',
        refundedAmount: json['refunded_amount'] == null ? null : _d(json['refunded_amount']),
        cancelReason: json['cancel_reason']?.toString(),
      );

  /// Annulable par l'expéditeur tant que le colis n'est pas déposé.
  bool get canCancel => status == 'paid';
}
