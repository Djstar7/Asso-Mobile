class DiaspoOffer {
  final int id;
  final int userId;
  final String status;
  final String verificationStatus;
  final DateTime? verifiedAt;
  final int? verifiedBy;
  final String? rejectionReason;

  // Trip information
  final String departureCountry;
  final String departureCity;
  final DateTime departureDateTime;
  final String arrivalCountry;
  final String arrivalCity;
  final DateTime arrivalDateTime;

  // Commercial information
  final double pricePerKg;
  final double availableKg;
  final double remainingKg;
  final String currency;

  // Metadata
  final int viewsCount;
  final int bookingsCount;

  // Computed
  final String formattedPrice;
  final bool isAvailable;
  final double? tripDurationHours;

  // Relations
  final DiaspoUser? user;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiaspoOffer({
    required this.id,
    required this.userId,
    required this.status,
    required this.verificationStatus,
    this.verifiedAt,
    this.verifiedBy,
    this.rejectionReason,
    required this.departureCountry,
    required this.departureCity,
    required this.departureDateTime,
    required this.arrivalCountry,
    required this.arrivalCity,
    required this.arrivalDateTime,
    required this.pricePerKg,
    required this.availableKg,
    required this.remainingKg,
    required this.currency,
    required this.viewsCount,
    required this.bookingsCount,
    required this.formattedPrice,
    required this.isAvailable,
    this.tripDurationHours,
    this.user,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiaspoOffer.fromJson(Map<String, dynamic> json) {
    return DiaspoOffer(
      id: json['id'],
      userId: json['user_id'],
      status: json['status'] ?? 'pending',
      verificationStatus: json['verification_status'] ?? 'pending',
      verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at']) : null,
      verifiedBy: json['verified_by'],
      rejectionReason: json['rejection_reason'],
      departureCountry: json['departure_country'] ?? '',
      departureCity: json['departure_city'] ?? '',
      departureDateTime: DateTime.parse(json['departure_datetime']),
      arrivalCountry: json['arrival_country'] ?? '',
      arrivalCity: json['arrival_city'] ?? '',
      arrivalDateTime: DateTime.parse(json['arrival_datetime']),
      pricePerKg: double.parse(json['price_per_kg'].toString()),
      availableKg: double.parse(json['available_kg'].toString()),
      remainingKg: double.parse(json['remaining_kg'].toString()),
      currency: json['currency'] ?? 'EUR',
      viewsCount: json['views_count'] ?? 0,
      bookingsCount: json['bookings_count'] ?? 0,
      formattedPrice: json['formatted_price'] ?? '',
      isAvailable: json['is_available'] ?? false,
      tripDurationHours: json['trip_duration_hours'] != null
          ? double.parse(json['trip_duration_hours'].toString())
          : null,
      user: json['user'] != null ? DiaspoUser.fromJson(json['user']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'status': status,
      'verification_status': verificationStatus,
      'verified_at': verifiedAt?.toIso8601String(),
      'verified_by': verifiedBy,
      'rejection_reason': rejectionReason,
      'departure_country': departureCountry,
      'departure_city': departureCity,
      'departure_datetime': departureDateTime.toIso8601String(),
      'arrival_country': arrivalCountry,
      'arrival_city': arrivalCity,
      'arrival_datetime': arrivalDateTime.toIso8601String(),
      'price_per_kg': pricePerKg,
      'available_kg': availableKg,
      'remaining_kg': remainingKg,
      'currency': currency,
      'views_count': viewsCount,
      'bookings_count': bookingsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DiaspoOffer copyWith({
    int? id,
    int? userId,
    String? status,
    String? verificationStatus,
    DateTime? verifiedAt,
    int? verifiedBy,
    String? rejectionReason,
    String? departureCountry,
    String? departureCity,
    DateTime? departureDateTime,
    String? arrivalCountry,
    String? arrivalCity,
    DateTime? arrivalDateTime,
    double? pricePerKg,
    double? availableKg,
    double? remainingKg,
    String? currency,
    int? viewsCount,
    int? bookingsCount,
    String? formattedPrice,
    bool? isAvailable,
    double? tripDurationHours,
    DiaspoUser? user,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaspoOffer(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      departureCountry: departureCountry ?? this.departureCountry,
      departureCity: departureCity ?? this.departureCity,
      departureDateTime: departureDateTime ?? this.departureDateTime,
      arrivalCountry: arrivalCountry ?? this.arrivalCountry,
      arrivalCity: arrivalCity ?? this.arrivalCity,
      arrivalDateTime: arrivalDateTime ?? this.arrivalDateTime,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      availableKg: availableKg ?? this.availableKg,
      remainingKg: remainingKg ?? this.remainingKg,
      currency: currency ?? this.currency,
      viewsCount: viewsCount ?? this.viewsCount,
      bookingsCount: bookingsCount ?? this.bookingsCount,
      formattedPrice: formattedPrice ?? this.formattedPrice,
      isAvailable: isAvailable ?? this.isAvailable,
      tripDurationHours: tripDurationHours ?? this.tripDurationHours,
      user: user ?? this.user,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DiaspoUser {
  final int id;
  final String firstName;
  final String lastName;
  final String? avatar;
  final String? phone;

  DiaspoUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.avatar,
    this.phone,
  });

  factory DiaspoUser.fromJson(Map<String, dynamic> json) {
    return DiaspoUser(
      id: json['id'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatar: json['avatar'],
      phone: json['phone'],
    );
  }

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'avatar': avatar,
      'phone': phone,
    };
  }
}
