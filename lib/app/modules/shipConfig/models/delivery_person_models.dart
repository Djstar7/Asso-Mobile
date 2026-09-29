import 'package:get/get.dart';
/// Type de livreur
enum DeliveryPersonType {
  personal,
  company,
}

extension DeliveryPersonTypeExtension on DeliveryPersonType {
  String get label {
    switch (this) {
      case DeliveryPersonType.personal:
        return 'ship_config.person_type.personal'.tr;
      case DeliveryPersonType.company:
        return 'ship_config.person_type.company'.tr;
    }
  }

  String get description {
    switch (this) {
      case DeliveryPersonType.personal:
        return 'ship_config.person_type.personal_desc'.tr;
      case DeliveryPersonType.company:
        return 'ship_config.person_type.company_desc'.tr;
    }
  }
}

/// Configuration du livreur
class DeliveryPersonConfig {
  final DeliveryPersonType type;
  final bool termsAccepted;
  final bool locationSharingAccepted;
  final String? companyName;
  final String? companyDescription;
  final String? companyLogo;
  final String? companyAddress;
  final double? companyLatitude;
  final double? companyLongitude;

  DeliveryPersonConfig({
    required this.type,
    required this.termsAccepted,
    required this.locationSharingAccepted,
    this.companyName,
    this.companyDescription,
    this.companyLogo,
    this.companyAddress,
    this.companyLatitude,
    this.companyLongitude,
  });

  factory DeliveryPersonConfig.fromJson(Map<String, dynamic> json) {
    return DeliveryPersonConfig(
      type: DeliveryPersonType.values.firstWhere(
        (e) => e.toString() == 'DeliveryPersonType.${json['type']}',
      ),
      termsAccepted: json['termsAccepted'] as bool,
      locationSharingAccepted: json['locationSharingAccepted'] as bool,
      companyName: json['companyName'] as String?,
      companyDescription: json['companyDescription'] as String?,
      companyLogo: json['companyLogo'] as String?,
      companyAddress: json['companyAddress'] as String?,
      companyLatitude: json['companyLatitude'] as double?,
      companyLongitude: json['companyLongitude'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'termsAccepted': termsAccepted,
      'locationSharingAccepted': locationSharingAccepted,
      'companyName': companyName,
      'companyDescription': companyDescription,
      'companyLogo': companyLogo,
      'companyAddress': companyAddress,
      'companyLatitude': companyLatitude,
      'companyLongitude': companyLongitude,
    };
  }
}
