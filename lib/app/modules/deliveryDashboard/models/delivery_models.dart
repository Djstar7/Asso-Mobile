import 'package:latlong2/latlong.dart';

/// Statut de livraison
enum DeliveryStatus {
  pending, // En attente
  inProgress, // En cours
  delivered, // Livré
  cancelled, // Annulé
}

extension DeliveryStatusExtension on DeliveryStatus {
  String get label {
    switch (this) {
      case DeliveryStatus.pending:
        return 'En attente';
      case DeliveryStatus.inProgress:
        return 'En cours';
      case DeliveryStatus.delivered:
        return 'Livré';
      case DeliveryStatus.cancelled:
        return 'Annulé';
    }
  }

  String get icon {
    switch (this) {
      case DeliveryStatus.pending:
        return '⏳';
      case DeliveryStatus.inProgress:
        return '🚚';
      case DeliveryStatus.delivered:
        return '✅';
      case DeliveryStatus.cancelled:
        return '❌';
    }
  }
}

/// Demande de livraison
/// Un bout de la course : la boutique où retirer, ou le client à livrer.
/// Le coursier doit pouvoir s'y rendre et appeler sur place.
class DeliveryStop {
  const DeliveryStop({
    this.name,
    this.phone,
    this.address,
    this.addressDetails,
    this.city,
    this.latitude,
    this.longitude,
  });

  final String? name;
  final String? phone;
  final String? address;
  final String? addressDetails;
  final String? city;
  final double? latitude;
  final double? longitude;

  bool get isEmpty =>
      (name == null || name!.trim().isEmpty) &&
      (address == null || address!.trim().isEmpty);

  /// Adresse complète, complément inclus.
  String get fullAddress => [
    address,
    addressDetails,
    city,
  ].where((e) => e != null && e.trim().isNotEmpty).toSet().join(' — ');

  static DeliveryStop? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    double? toDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());

    return DeliveryStop(
      name: map['name']?.toString(),
      phone: map['phone']?.toString(),
      address: map['address']?.toString(),
      addressDetails: map['address_details']?.toString(),
      city: map['city']?.toString(),
      latitude: toDouble(map['latitude']),
      longitude: toDouble(map['longitude']),
    );
  }
}

/// Article d'une commande à livrer, tel que montré au livreur.
class DeliveryItem {
  const DeliveryItem({required this.name, required this.quantity});

  final String name;
  final int quantity;

  factory DeliveryItem.fromMap(Map<String, dynamic> map) => DeliveryItem(
    name: (map['product_name'] ?? map['name'] ?? 'Article').toString(),
    quantity: int.tryParse('${map['quantity'] ?? 1}') ?? 1,
  );
}

class DeliveryRequest {
  final String id;
  final String orderId;
  final DeliveryStatus status;
  final String customerName;
  final String customerPhone;
  final String pickupAddress;
  final LatLng pickupLocation;
  final String deliveryAddress;
  final LatLng deliveryLocation;
  final double distance; // en km
  final double commission; // Commission en XAF
  final DateTime requestDate;
  final DateTime? acceptedDate;
  final DateTime? deliveredDate;
  final String? notes;

  /// Détails que le livreur doit connaître AVANT d'accepter la course.
  final String? orderNumber;
  final double orderTotal;
  final List<DeliveryItem> items;
  final String? leadTime;
  final String? addressDetails;

  /// Les deux extrémités de la course : boutique puis client.
  final DeliveryStop? pickup;
  final DeliveryStop? dropoff;

  DeliveryRequest({
    required this.id,
    required this.orderId,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.deliveryAddress,
    required this.deliveryLocation,
    required this.distance,
    required this.commission,
    required this.requestDate,
    this.acceptedDate,
    this.deliveredDate,
    this.notes,
    this.orderNumber,
    this.orderTotal = 0,
    this.items = const [],
    this.leadTime,
    this.addressDetails,
    this.pickup,
    this.dropoff,
  });

  factory DeliveryRequest.fromJson(Map<String, dynamic> json) {
    return DeliveryRequest(
      id: json['id'] as String,
      orderId: json['orderId'] as String,
      status: DeliveryStatus.values.firstWhere(
        (e) => e.toString() == 'DeliveryStatus.${json['status']}',
      ),
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      pickupAddress: json['pickupAddress'] as String,
      pickupLocation: LatLng(
        json['pickupLatitude'] as double,
        json['pickupLongitude'] as double,
      ),
      deliveryAddress: json['deliveryAddress'] as String,
      deliveryLocation: LatLng(
        json['deliveryLatitude'] as double,
        json['deliveryLongitude'] as double,
      ),
      distance: (json['distance'] as num).toDouble(),
      commission: (json['commission'] as num).toDouble(),
      requestDate: DateTime.parse(json['requestDate'] as String),
      acceptedDate: json['acceptedDate'] != null
          ? DateTime.parse(json['acceptedDate'] as String)
          : null,
      deliveredDate: json['deliveredDate'] != null
          ? DateTime.parse(json['deliveredDate'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'status': status.toString().split('.').last,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'pickupAddress': pickupAddress,
      'pickupLatitude': pickupLocation.latitude,
      'pickupLongitude': pickupLocation.longitude,
      'deliveryAddress': deliveryAddress,
      'deliveryLatitude': deliveryLocation.latitude,
      'deliveryLongitude': deliveryLocation.longitude,
      'distance': distance,
      'commission': commission,
      'requestDate': requestDate.toIso8601String(),
      'acceptedDate': acceptedDate?.toIso8601String(),
      'deliveredDate': deliveredDate?.toIso8601String(),
      'notes': notes,
    };
  }
}

/// Statistiques du livreur
class DeliveryStats {
  final int totalDeliveries;
  final int pendingDeliveries;
  final int inProgressDeliveries;
  final int completedDeliveries;
  final int cancelledDeliveries;

  /// Nombre de courses transportables en même temps, fixé par le serveur.
  final int maxActiveRuns;
  final double totalCommissions;
  final double todayCommissions;
  final double averageRating;

  DeliveryStats({
    required this.totalDeliveries,
    required this.pendingDeliveries,
    required this.inProgressDeliveries,
    required this.completedDeliveries,
    required this.cancelledDeliveries,
    this.maxActiveRuns = 3,
    required this.totalCommissions,
    required this.todayCommissions,
    required this.averageRating,
  });

  factory DeliveryStats.fromJson(Map<String, dynamic> json) {
    return DeliveryStats(
      totalDeliveries: json['totalDeliveries'] as int,
      pendingDeliveries: json['pendingDeliveries'] as int,
      inProgressDeliveries: json['inProgressDeliveries'] as int,
      completedDeliveries: json['completedDeliveries'] as int,
      cancelledDeliveries: json['cancelledDeliveries'] as int,
      maxActiveRuns: (json['maxActiveRuns'] as num?)?.toInt() ?? 3,
      totalCommissions: (json['totalCommissions'] as num).toDouble(),
      todayCommissions: (json['todayCommissions'] as num).toDouble(),
      averageRating: (json['averageRating'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDeliveries': totalDeliveries,
      'pendingDeliveries': pendingDeliveries,
      'inProgressDeliveries': inProgressDeliveries,
      'completedDeliveries': completedDeliveries,
      'cancelledDeliveries': cancelledDeliveries,
      'maxActiveRuns': maxActiveRuns,
      'totalCommissions': totalCommissions,
      'todayCommissions': todayCommissions,
      'averageRating': averageRating,
    };
  }
}
