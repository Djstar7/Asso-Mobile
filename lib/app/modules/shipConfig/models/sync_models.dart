import 'dart:convert';
import 'dart:math';

/// Modèles pour la synchronisation du profil livreur

/// `zone_data` arrive tantôt décodé, tantôt en chaîne JSON selon l'endpoint :
/// on normalise pour ne jamais casser la synchronisation du livreur.
Map<String, dynamic>? _decodeJsonMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    if (value.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Type de tarification
enum PricingType {
  fixed,
  weightCategory,
  volumetricWeight,
}

extension PricingTypeExtension on PricingType {
  String get value {
    switch (this) {
      case PricingType.fixed:
        return 'fixed';
      case PricingType.weightCategory:
        return 'weight_category';
      case PricingType.volumetricWeight:
        return 'volumetric_weight';
    }
  }

  static PricingType fromString(String value) {
    switch (value) {
      case 'fixed':
        return PricingType.fixed;
      case 'weight_category':
        return PricingType.weightCategory;
      case 'volumetric_weight':
        return PricingType.volumetricWeight;
      default:
        return PricingType.fixed;
    }
  }

  String get label {
    switch (this) {
      case PricingType.fixed:
        return 'Prix fixe';
      case PricingType.weightCategory:
        return 'Par catégorie de poids';
      case PricingType.volumetricWeight:
        return 'Poids volumétrique';
    }
  }
}

/// Entreprise de livraison
class DelivererCompany {
  final int id;
  final int? userId;
  final String name;
  final String? phone;
  final String? email;
  final String? description;
  final String? logo;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DelivererCompany({
    required this.id,
    this.userId,
    required this.name,
    this.phone,
    this.email,
    this.description,
    this.logo,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory DelivererCompany.fromJson(Map<String, dynamic> json) {
    return DelivererCompany(
      id: json['id'] as int,
      userId: json['user_id'] as int?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      description: json['description'] as String?,
      logo: json['logo'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'description': description,
      'logo': logo,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Grille tarifaire de livraison
class DeliveryPricelist {
  final int id;
  final int? deliveryZoneId;
  final PricingType pricingType;
  final Map<String, dynamic> pricingData;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeliveryPricelist({
    required this.id,
    this.deliveryZoneId,
    required this.pricingType,
    required this.pricingData,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryPricelist.fromJson(Map<String, dynamic> json) {
    return DeliveryPricelist(
      id: json['id'] as int,
      deliveryZoneId: json['delivery_zone_id'] as int?,
      pricingType: PricingTypeExtension.fromString(json['pricing_type'] as String),
      pricingData: json['pricing_data'] as Map<String, dynamic>,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_zone_id': deliveryZoneId,
      'pricing_type': pricingType.value,
      'pricing_data': pricingData,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Calcule le prix en fonction du type de tarification
  double calculatePrice({
    String? category,
    double? length,
    double? width,
    double? height,
  }) {
    switch (pricingType) {
      case PricingType.fixed:
        return (pricingData['price'] ?? 0).toDouble();

      case PricingType.weightCategory:
        if (category == null) return 0;
        return (pricingData[category] ?? 0).toDouble();

      case PricingType.volumetricWeight:
        if (length == null || width == null || height == null) return 0;
        final volumetricWeight = (length * width * height) / 139;
        final ranges = pricingData['ranges'] as List<dynamic>? ?? [];

        for (var range in ranges) {
          final min = (range['min'] ?? 0).toDouble();
          final max = (range['max'] ?? 0).toDouble();
          if (volumetricWeight >= min && volumetricWeight <= max) {
            return (range['price'] ?? 0).toDouble();
          }
        }
        return 0;
    }
  }

  /// Obtient la description de la tarification
  String get description {
    switch (pricingType) {
      case PricingType.fixed:
        final price = pricingData['price'] ?? 0;
        return 'Prix fixe: ${price} FCFA';

      case PricingType.weightCategory:
        final categories = pricingData.entries
            .map((e) => '${e.key}: ${e.value} FCFA')
            .join(', ');
        return 'Par catégorie: $categories';

      case PricingType.volumetricWeight:
        return 'Poids volumétrique (L × l × h) / 139';
    }
  }
}

/// Zone de livraison
class DeliveryZone {
  final int id;
  final int? delivererCompanyId;
  final String name;
  final Map<String, dynamic>? zoneData;
  final double centerLatitude;
  final double centerLongitude;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DeliveryPricelist? activePricelist;

  DeliveryZone({
    required this.id,
    this.delivererCompanyId,
    required this.name,
    this.zoneData,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.activePricelist,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'] as int,
      delivererCompanyId: json['deliverer_company_id'] as int?,
      name: json['name'] as String,
      zoneData: _decodeJsonMap(json['zone_data']),
      centerLatitude: double.parse(json['center_latitude'].toString()),
      centerLongitude: double.parse(json['center_longitude'].toString()),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      activePricelist: json['active_pricelist'] != null
          ? DeliveryPricelist.fromJson(json['active_pricelist'] as Map<String, dynamic>)
          : json['pricelist'] != null
              ? DeliveryPricelist.fromJson(json['pricelist'] as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deliverer_company_id': delivererCompanyId,
      'name': name,
      'zone_data': zoneData,
      'center_latitude': centerLatitude,
      'center_longitude': centerLongitude,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'active_pricelist': activePricelist?.toJson(),
    };
  }

  /// Calcule la distance entre un point et le centre de la zone (en km)
  double distanceFrom(double latitude, double longitude) {
    const earthRadius = 6371; // Rayon de la Terre en km

    final dLat = _degreesToRadians(latitude - centerLatitude);
    final dLon = _degreesToRadians(longitude - centerLongitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(centerLatitude)) *
            cos(_degreesToRadians(latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Vérifie si un point est dans la zone (rayon de 10km)
  bool containsPoint(double latitude, double longitude) {
    return distanceFrom(latitude, longitude) <= 10;
  }
}

/// Réponse de la synchronisation du profil
class SyncProfileResponse {
  final bool success;
  final String message;
  final DelivererCompany? company;
  final List<DeliveryZone>? zones;

  SyncProfileResponse({
    required this.success,
    required this.message,
    this.company,
    this.zones,
  });

  factory SyncProfileResponse.fromJson(Map<String, dynamic> json) {
    // Extraire le contenu de 'data' si présent
    final data = json['data'] as Map<String, dynamic>?;

    return SyncProfileResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      company: data?['company'] != null
          ? DelivererCompany.fromJson(data!['company'] as Map<String, dynamic>)
          : null,
      zones: data?['delivery_zones'] != null
          ? (data!['delivery_zones'] as List<dynamic>)
              .map((zone) => DeliveryZone.fromJson(zone as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'company': company?.toJson(),
      'zones': zones?.map((zone) => zone.toJson()).toList(),
    };
  }
}
