/// Modèle de données pour une commande
class OrderModel {
  final String id;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String clientAvatar;
  final List<OrderItem> items;
  final double totalAmount;
  final OrderStatus status;
  final String city;
  final String address;
  final DateTime orderDate;
  final DateTime? validatedDate;
  final DateTime? cancelledDate;
  final String? cancelReason;
  final String? deliveryPersonId;
  final String? deliveryPersonName;
  final String? notes;

  /// Numéro lisible (CMD123456), celui que voit aussi le client.
  final String orderNumber;

  /// Numéro à appeler pour la livraison (peut différer du compte client).
  final String deliveryPhone;
  final String? addressDetails;
  final String paymentStatus;
  final double vendorAmount;
  final String? deliveryCompanyName;

  /// Livreur déjà assigné (statut serveur « preparing »).
  final bool deliveryAssigned;

  String get displayNumber => orderNumber.isNotEmpty ? orderNumber : '#$id';
  bool get isPaid => paymentStatus == 'paid';

  OrderModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    this.clientAvatar = '',
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.city,
    required this.address,
    required this.orderDate,
    this.validatedDate,
    this.cancelledDate,
    this.cancelReason,
    this.deliveryPersonId,
    this.deliveryPersonName,
    this.notes,
    this.orderNumber = '',
    this.deliveryPhone = '',
    this.addressDetails,
    this.paymentStatus = 'paid',
    this.vendorAmount = 0,
    this.deliveryCompanyName,
    this.deliveryAssigned = false,
  });

  /// Nombre total d'articles
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Conversion depuis JSON
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      clientName: json['clientName'] as String,
      clientPhone: json['clientPhone'] as String,
      clientAvatar: json['clientAvatar'] as String? ?? '',
      items: (json['items'] as List)
          .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == 'OrderStatus.${json['status']}',
        orElse: () => OrderStatus.pending,
      ),
      city: json['city'] as String,
      address: json['address'] as String,
      orderDate: DateTime.parse(json['orderDate'] as String),
      validatedDate: json['validatedDate'] != null
          ? DateTime.parse(json['validatedDate'] as String)
          : null,
      cancelledDate: json['cancelledDate'] != null
          ? DateTime.parse(json['cancelledDate'] as String)
          : null,
      cancelReason: json['cancelReason'] as String?,
      deliveryPersonId: json['deliveryPersonId'] as String?,
      deliveryPersonName: json['deliveryPersonName'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// Conversion vers JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      'clientAvatar': clientAvatar,
      'items': items.map((item) => item.toJson()).toList(),
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'city': city,
      'address': address,
      'orderDate': orderDate.toIso8601String(),
      'validatedDate': validatedDate?.toIso8601String(),
      'cancelledDate': cancelledDate?.toIso8601String(),
      'cancelReason': cancelReason,
      'deliveryPersonId': deliveryPersonId,
      'deliveryPersonName': deliveryPersonName,
      'notes': notes,
    };
  }

  /// Copie avec modification
  OrderModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientPhone,
    String? clientAvatar,
    List<OrderItem>? items,
    double? totalAmount,
    OrderStatus? status,
    String? city,
    String? address,
    DateTime? orderDate,
    DateTime? validatedDate,
    DateTime? cancelledDate,
    String? cancelReason,
    String? deliveryPersonId,
    String? deliveryPersonName,
    String? notes,
  }) {
    return OrderModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientAvatar: clientAvatar ?? this.clientAvatar,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      city: city ?? this.city,
      address: address ?? this.address,
      orderDate: orderDate ?? this.orderDate,
      validatedDate: validatedDate ?? this.validatedDate,
      cancelledDate: cancelledDate ?? this.cancelledDate,
      cancelReason: cancelReason ?? this.cancelReason,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      deliveryPersonName: deliveryPersonName ?? this.deliveryPersonName,
      notes: notes ?? this.notes,
    );
  }
}

/// Article dans une commande
class OrderItem {
  final String productId;
  final String productName;
  final String productImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  /// Choix du client à préparer, ex. « Couleur : Noir · Pointure : 42 ».
  final String? variantLabel;

  /// Conditionnement choisi pour une commande en gros.
  final String? tierLabel;

  OrderItem({
    required this.productId,
    required this.productName,
    this.productImage = '',
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.variantLabel,
    this.tierLabel,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      productImage: json['productImage'] as String? ?? '',
      quantity: json['quantity'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }
}

/// États possibles d'une commande
enum OrderStatus {
  pending, // En attente
  validated, // Validée
  cancelled, // Annulée
  inDelivery, // En livraison
  delivered, // Livrée
}

/// Extension pour obtenir le label français de l'état
extension OrderStatusExtension on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.validated:
        return 'Validée';
      case OrderStatus.cancelled:
        return 'Annulée';
      case OrderStatus.inDelivery:
        return 'En livraison';
      case OrderStatus.delivered:
        return 'Livrée';
    }
  }

  String get shortLabel {
    switch (this) {
      case OrderStatus.pending:
        return 'Attente';
      case OrderStatus.validated:
        return 'Validée';
      case OrderStatus.cancelled:
        return 'Annulée';
      case OrderStatus.inDelivery:
        return 'Livraison';
      case OrderStatus.delivered:
        return 'Livrée';
    }
  }
}
