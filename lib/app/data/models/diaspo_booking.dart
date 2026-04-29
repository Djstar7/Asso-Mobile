import 'diaspo_offer.dart';

class DiaspoBooking {
  final int id;
  final int diaspoOfferId;
  final int buyerUserId;
  final int sellerUserId;

  // Booking details
  final double kgBooked;
  final double pricePerKg;
  final double subtotal;
  final double commissionAmount;
  final double totalPrice;

  // Status
  final String status;
  final String confirmationCode;
  final DateTime? confirmedByBuyerAt;

  // Payment
  final String paymentStatus;
  final String? paymentReference;
  final DateTime? paidAt;
  final DateTime? refundedAt;

  // Communication
  final int? conversationId;
  final String? notes;

  // Cancellation
  final String? cancelReason;
  final DateTime? cancelledAt;

  // Computed
  final String formattedTotal;
  final bool isCompleted;

  // Relations
  final DiaspoOffer? diaspoOffer;
  final DiaspoUser? buyer;
  final DiaspoUser? seller;

  final DateTime createdAt;
  final DateTime updatedAt;

  DiaspoBooking({
    required this.id,
    required this.diaspoOfferId,
    required this.buyerUserId,
    required this.sellerUserId,
    required this.kgBooked,
    required this.pricePerKg,
    required this.subtotal,
    required this.commissionAmount,
    required this.totalPrice,
    required this.status,
    required this.confirmationCode,
    this.confirmedByBuyerAt,
    required this.paymentStatus,
    this.paymentReference,
    this.paidAt,
    this.refundedAt,
    this.conversationId,
    this.notes,
    this.cancelReason,
    this.cancelledAt,
    required this.formattedTotal,
    required this.isCompleted,
    this.diaspoOffer,
    this.buyer,
    this.seller,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DiaspoBooking.fromJson(Map<String, dynamic> json) {
    return DiaspoBooking(
      id: json['id'],
      diaspoOfferId: json['diaspo_offer_id'],
      buyerUserId: json['buyer_user_id'],
      sellerUserId: json['seller_user_id'],
      kgBooked: double.parse(json['kg_booked'].toString()),
      pricePerKg: double.parse(json['price_per_kg'].toString()),
      subtotal: double.parse(json['subtotal'].toString()),
      commissionAmount: double.parse(json['commission_amount'].toString()),
      totalPrice: double.parse(json['total_price'].toString()),
      status: json['status'] ?? 'pending',
      confirmationCode: json['confirmation_code'] ?? '',
      confirmedByBuyerAt: json['confirmed_by_buyer_at'] != null
          ? DateTime.parse(json['confirmed_by_buyer_at'])
          : null,
      paymentStatus: json['payment_status'] ?? 'pending',
      paymentReference: json['payment_reference'],
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      refundedAt: json['refunded_at'] != null ? DateTime.parse(json['refunded_at']) : null,
      conversationId: json['conversation_id'],
      notes: json['notes'],
      cancelReason: json['cancel_reason'],
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at']) : null,
      formattedTotal: json['formatted_total'] ?? '',
      isCompleted: json['is_completed'] ?? false,
      diaspoOffer: json['diaspo_offer'] != null
          ? DiaspoOffer.fromJson(json['diaspo_offer'])
          : null,
      buyer: json['buyer'] != null ? DiaspoUser.fromJson(json['buyer']) : null,
      seller: json['seller'] != null ? DiaspoUser.fromJson(json['seller']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'diaspo_offer_id': diaspoOfferId,
      'buyer_user_id': buyerUserId,
      'seller_user_id': sellerUserId,
      'kg_booked': kgBooked,
      'price_per_kg': pricePerKg,
      'subtotal': subtotal,
      'commission_amount': commissionAmount,
      'total_price': totalPrice,
      'status': status,
      'confirmation_code': confirmationCode,
      'confirmed_by_buyer_at': confirmedByBuyerAt?.toIso8601String(),
      'payment_status': paymentStatus,
      'payment_reference': paymentReference,
      'paid_at': paidAt?.toIso8601String(),
      'refunded_at': refundedAt?.toIso8601String(),
      'conversation_id': conversationId,
      'notes': notes,
      'cancel_reason': cancelReason,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DiaspoBooking copyWith({
    int? id,
    int? diaspoOfferId,
    int? buyerUserId,
    int? sellerUserId,
    double? kgBooked,
    double? pricePerKg,
    double? subtotal,
    double? commissionAmount,
    double? totalPrice,
    String? status,
    String? confirmationCode,
    DateTime? confirmedByBuyerAt,
    String? paymentStatus,
    String? paymentReference,
    DateTime? paidAt,
    DateTime? refundedAt,
    int? conversationId,
    String? notes,
    String? cancelReason,
    DateTime? cancelledAt,
    String? formattedTotal,
    bool? isCompleted,
    DiaspoOffer? diaspoOffer,
    DiaspoUser? buyer,
    DiaspoUser? seller,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaspoBooking(
      id: id ?? this.id,
      diaspoOfferId: diaspoOfferId ?? this.diaspoOfferId,
      buyerUserId: buyerUserId ?? this.buyerUserId,
      sellerUserId: sellerUserId ?? this.sellerUserId,
      kgBooked: kgBooked ?? this.kgBooked,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      subtotal: subtotal ?? this.subtotal,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      confirmationCode: confirmationCode ?? this.confirmationCode,
      confirmedByBuyerAt: confirmedByBuyerAt ?? this.confirmedByBuyerAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentReference: paymentReference ?? this.paymentReference,
      paidAt: paidAt ?? this.paidAt,
      refundedAt: refundedAt ?? this.refundedAt,
      conversationId: conversationId ?? this.conversationId,
      notes: notes ?? this.notes,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      formattedTotal: formattedTotal ?? this.formattedTotal,
      isCompleted: isCompleted ?? this.isCompleted,
      diaspoOffer: diaspoOffer ?? this.diaspoOffer,
      buyer: buyer ?? this.buyer,
      seller: seller ?? this.seller,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
