/// User model matching backend structure
class UserModel {
  final int id;
  final String firstName;
  final String lastName;
  final String name;
  final String email;
  final String phone;
  final String role;
  final List<String>? roles;
  final String? gender;
  final String? birthDate;
  final String? avatar;
  final String? country;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool isProfileComplete;
  final Map<String, dynamic>? preferences;
  final String? referralCode;
  final String? companyName;
  final String? companyLogo;
  final double? totalEarnings;
  final double? pendingEarnings;
  final String? deliverySerialNumber;
  final String createdAt;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.roles,
    this.gender,
    this.birthDate,
    this.avatar,
    this.country,
    this.address,
    this.latitude,
    this.longitude,
    this.isProfileComplete = false,
    this.preferences,
    this.referralCode,
    this.companyName,
    this.companyLogo,
    this.totalEarnings,
    this.pendingEarnings,
    this.deliverySerialNumber,
    required this.createdAt,
  });

  /// Parse une valeur numérique pouvant arriver en num, String (colonnes
  /// `decimal` de Laravel renvoyées en chaîne) ou null.
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      name: json['name'] as String? ?? '${json['first_name']} ${json['last_name']}',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'client',
      roles: json['roles'] != null ? List<String>.from(json['roles'] as List) : null,
      gender: json['gender'] as String?,
      birthDate: json['birth_date'] as String?,
      avatar: json['avatar'] as String?,
      country: json['country'] as String?,
      address: json['address'] as String?,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      isProfileComplete: json['is_profile_complete'] == true,
      preferences: json['preferences'] as Map<String, dynamic>?,
      referralCode: json['referral_code'] as String?,
      companyName: json['company_name'] as String?,
      companyLogo: json['company_logo'] as String?,
      totalEarnings: _parseDouble(json['total_earnings']),
      pendingEarnings: _parseDouble(json['pending_earnings']),
      deliverySerialNumber: json['delivery_serial_number'] as String?,
      createdAt: json['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'roles': roles,
      'gender': gender,
      'birth_date': birthDate,
      'avatar': avatar,
      'country': country,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'is_profile_complete': isProfileComplete,
      'preferences': preferences,
      'referral_code': referralCode,
      'company_name': companyName,
      'company_logo': companyLogo,
      'total_earnings': totalEarnings,
      'pending_earnings': pendingEarnings,
      'delivery_serial_number': deliverySerialNumber,
      'created_at': createdAt,
    };
  }

  /// Create a copy with updated fields
  UserModel copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? name,
    String? email,
    String? phone,
    String? role,
    List<String>? roles,
    String? gender,
    String? birthDate,
    String? avatar,
    String? country,
    String? address,
    double? latitude,
    double? longitude,
    bool? isProfileComplete,
    Map<String, dynamic>? preferences,
    String? referralCode,
    String? companyName,
    String? companyLogo,
    double? totalEarnings,
    double? pendingEarnings,
    String? deliverySerialNumber,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      roles: roles ?? this.roles,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      avatar: avatar ?? this.avatar,
      country: country ?? this.country,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      preferences: preferences ?? this.preferences,
      referralCode: referralCode ?? this.referralCode,
      companyName: companyName ?? this.companyName,
      companyLogo: companyLogo ?? this.companyLogo,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      pendingEarnings: pendingEarnings ?? this.pendingEarnings,
      deliverySerialNumber: deliverySerialNumber ?? this.deliverySerialNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if user has a specific role
  bool hasRole(String roleToCheck) {
    if (roles != null && roles!.isNotEmpty) {
      return roles!.contains(roleToCheck);
    }
    // Fallback to old role column
    return role == roleToCheck;
  }

  /// Check if user is a vendor
  bool get isVendor => hasRole('vendor') || hasRole('vendeur');

  /// Check if user is a delivery person
  bool get isDelivery => hasRole('delivery') || hasRole('livreur');

  /// Check if user is a client
  bool get isClient => role == 'client';

  /// Get full name
  String get fullName => name.isNotEmpty ? name : '$firstName $lastName';

  @override
  String toString() {
    return 'UserModel(id: $id, name: $fullName, phone: $phone, role: $role, isProfileComplete: $isProfileComplete)';
  }
}
