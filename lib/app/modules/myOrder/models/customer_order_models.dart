/// Statut de commande client
enum CustomerOrderStatus {
  pending,
  confirmed,
  preparing,
  shipped,
  delivered,
  cancelled,
}

extension CustomerOrderStatusExtension on CustomerOrderStatus {
  String get label {
    switch (this) {
      case CustomerOrderStatus.pending:
        return 'En attente';
      case CustomerOrderStatus.confirmed:
        return 'Confirmée';
      case CustomerOrderStatus.preparing:
        return 'En préparation';
      case CustomerOrderStatus.shipped:
        return 'Expédiée';
      case CustomerOrderStatus.delivered:
        return 'Livrée';
      case CustomerOrderStatus.cancelled:
        return 'Annulée';
    }
  }

  String get icon {
    switch (this) {
      case CustomerOrderStatus.pending:
        return '⏳';
      case CustomerOrderStatus.confirmed:
        return '✅';
      case CustomerOrderStatus.preparing:
        return '📦';
      case CustomerOrderStatus.shipped:
        return '🚚';
      case CustomerOrderStatus.delivered:
        return '✨';
      case CustomerOrderStatus.cancelled:
        return '❌';
    }
  }
}

/// Article de commande
class CustomerOrderItem {
  final String productId;
  final String productName;
  final String? productImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  CustomerOrderItem({
    required this.productId,
    required this.productName,
    this.productImage,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory CustomerOrderItem.fromMap(Map<String, dynamic> map) {
    return CustomerOrderItem(
      productId: (map['product_id'] ?? map['id'] ?? '').toString(),
      productName: map['product']?['name'] ?? 'Produit',
      productImage: map['product']?['main_image'],
      quantity: map['quantity'] ?? 1,
      unitPrice: double.tryParse(map['unit_price']?.toString() ?? '0') ?? 0,
      totalPrice: double.tryParse(map['total_price']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Commande client
class CustomerOrder {
  final String id;
  final String? orderNumber;
  final CustomerOrderStatus status;
  final List<CustomerOrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final String deliveryAddress;
  final String? trackingNumber;
  final String? confirmationCode;
  final bool canRate;
  final String? ratedAt;
  final String? deliveryPersonName;
  final String? deliveryPersonPhone;
  final String? deliveryCompanyName;

  CustomerOrder({
    required this.id,
    this.orderNumber,
    required this.status,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.orderDate,
    this.deliveryDate,
    required this.deliveryAddress,
    this.trackingNumber,
    this.confirmationCode,
    this.canRate = false,
    this.ratedAt,
    this.deliveryPersonName,
    this.deliveryPersonPhone,
    this.deliveryCompanyName,
  });

  factory CustomerOrder.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status']?.toString() ?? 'pending';
    return CustomerOrder(
      id: (map['id'] ?? '').toString(),
      orderNumber: map['order_number'],
      status: _parseStatus(statusStr),
      items: (map['items'] as List?)?.map((i) => CustomerOrderItem.fromMap(Map<String, dynamic>.from(i))).toList() ?? [],
      subtotal: double.tryParse(map['subtotal']?.toString() ?? '0') ?? 0,
      deliveryFee: double.tryParse(map['delivery_fee']?.toString() ?? '0') ?? 0,
      total: double.tryParse(map['total']?.toString() ?? '0') ?? 0,
      orderDate: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      deliveryDate: map['delivered_at'] != null ? DateTime.tryParse(map['delivered_at']) : null,
      deliveryAddress: map['delivery_address'] ?? '',
      trackingNumber: map['tracking_number'],
      confirmationCode: map['confirmation_code'],
      canRate: map['can_rate'] == true,
      ratedAt: map['rated_at'],
      deliveryPersonName: map['delivery_person'] != null ? '${map['delivery_person']['name'] ?? ''}' : null,
      deliveryPersonPhone: map['delivery_person']?['phone'],
      deliveryCompanyName: map['delivery_company']?['name'],
    );
  }

  static CustomerOrderStatus _parseStatus(String status) {
    switch (status) {
      case 'pending': return CustomerOrderStatus.pending;
      case 'confirmed': return CustomerOrderStatus.confirmed;
      case 'preparing': return CustomerOrderStatus.preparing;
      case 'shipped': return CustomerOrderStatus.shipped;
      case 'delivered': return CustomerOrderStatus.delivered;
      case 'cancelled': return CustomerOrderStatus.cancelled;
      default: return CustomerOrderStatus.pending;
    }
  }
}
