import 'package:get/get.dart';
import '../providers/currency_service.dart';

/// Wallet model matching backend structure
class WalletModel {
  final double currentBalance;
  final double freemopayBalance;
  final double paypalBalance;
  final double lockedFreemopayBalance;
  final double lockedPaypalBalance;
  final double totalLockedBalance;
  final double availableBalance;
  final double totalCredits;
  final double totalDebits;
  final int totalTransactions;
  final String? lastTransactionDate;

  WalletModel({
    required this.currentBalance,
    required this.freemopayBalance,
    required this.paypalBalance,
    required this.lockedFreemopayBalance,
    required this.lockedPaypalBalance,
    required this.totalLockedBalance,
    required this.availableBalance,
    required this.totalCredits,
    required this.totalDebits,
    required this.totalTransactions,
    this.lastTransactionDate,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      currentBalance: _parseDouble(json['current_balance']),
      freemopayBalance: _parseDouble(json['freemopay_balance']),
      paypalBalance: _parseDouble(json['paypal_balance']),
      lockedFreemopayBalance: _parseDouble(json['locked_freemopay_balance']),
      lockedPaypalBalance: _parseDouble(json['locked_paypal_balance']),
      totalLockedBalance: _parseDouble(json['total_locked_balance']),
      availableBalance: _parseDouble(json['available_balance']),
      totalCredits: _parseDouble(json['total_credits']),
      totalDebits: _parseDouble(json['total_debits']),
      totalTransactions: json['total_transactions'] ?? 0,
      lastTransactionDate: json['last_transaction_date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_balance': currentBalance,
      'freemopay_balance': freemopayBalance,
      'paypal_balance': paypalBalance,
      'locked_freemopay_balance': lockedFreemopayBalance,
      'locked_paypal_balance': lockedPaypalBalance,
      'total_locked_balance': totalLockedBalance,
      'available_balance': availableBalance,
      'total_credits': totalCredits,
      'total_debits': totalDebits,
      'total_transactions': totalTransactions,
      'last_transaction_date': lastTransactionDate,
    };
  }

  String get formattedBalance {
    try {
      if (Get.isRegistered<CurrencyService>()) {
        return CurrencyService.to.formatPrice(currentBalance);
      }
    } catch (e) {
      // Fallback si CurrencyService n'est pas encore initialisé
    }
    return '${currentBalance.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        )} FCFA';
  }

  String get formattedLockedBalance {
    try {
      if (Get.isRegistered<CurrencyService>()) {
        return CurrencyService.to.formatPrice(totalLockedBalance);
      }
    } catch (e) {
      // Fallback si CurrencyService n'est pas encore initialisé
    }
    return '${totalLockedBalance.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        )} FCFA';
  }

  String get formattedAvailableBalance {
    try {
      if (Get.isRegistered<CurrencyService>()) {
        return CurrencyService.to.formatPrice(availableBalance);
      }
    } catch (e) {
      // Fallback si CurrencyService n'est pas encore initialisé
    }
    return '${availableBalance.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        )} FCFA';
  }

  bool get hasLockedFunds => totalLockedBalance > 0;

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Wallet transaction model
class WalletTransactionModel {
  final int id;
  final int userId;
  final String type; // credit, debit, refund, bonus, adjustment, lock, unlock, escrow_release
  final double amount;
  final String? paymentProvider; // freemopay, paypal
  final String status; // pending, completed, failed
  final String description;
  final String? referenceType; // order, subscription, withdrawal, recharge, diaspo_booking
  final int? referenceId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? completedAt;

  WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    this.paymentProvider,
    required this.status,
    required this.description,
    this.referenceType,
    this.referenceId,
    this.metadata,
    required this.createdAt,
    this.completedAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'],
      amount: WalletModel._parseDouble(json['amount']),
      paymentProvider: json['payment_provider'],
      status: json['status'],
      description: json['description'] ?? '',
      referenceType: json['reference_type'],
      referenceId: json['reference_id'],
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'amount': amount,
      'payment_provider': paymentProvider,
      'status': status,
      'description': description,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  /// Check if transaction is a credit (incoming money)
  bool get isCredit => type == 'credit' || type == 'refund' || type == 'bonus';

  /// Check if transaction is escrow-related
  bool get isEscrow => type == 'lock' || type == 'unlock' || type == 'escrow_release';

  /// Get formatted amount with sign
  String get formattedAmount {
    final sign = isCredit ? '+' : '-';
    final absAmount = amount.abs();

    try {
      if (Get.isRegistered<CurrencyService>()) {
        final formattedPrice = CurrencyService.to.formatPrice(absAmount, showSymbol: false);
        final symbol = CurrencyService.to.currencySymbol;
        return '$sign $formattedPrice $symbol';
      }
    } catch (e) {
      // Fallback si CurrencyService n'est pas encore initialisé
    }

    return '$sign ${absAmount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        )} F';
  }

  /// Get type label in French
  String get typeLabel {
    switch (type) {
      case 'credit':
        return 'Recharge';
      case 'debit':
        return 'Paiement';
      case 'refund':
        return 'Remboursement';
      case 'bonus':
        return 'Bonus';
      case 'adjustment':
        return 'Ajustement';
      case 'lock':
        return 'Fonds bloqués';
      case 'unlock':
        return 'Fonds débloqués';
      case 'escrow_release':
        return 'Paiement libéré';
      default:
        return 'Transaction';
    }
  }

  /// Get type icon emoji
  String get typeIcon {
    switch (type) {
      case 'credit':
        return '💵';
      case 'debit':
        return '💸';
      case 'refund':
        return '↩️';
      case 'bonus':
        return '🎁';
      case 'adjustment':
        return '⚙️';
      case 'lock':
        return '🔒';
      case 'unlock':
        return '🔓';
      case 'escrow_release':
        return '✅';
      default:
        return '💰';
    }
  }

  /// Get status text in French
  String get statusText {
    switch (status) {
      case 'completed':
        return 'Complété';
      case 'pending':
        return 'En attente';
      case 'failed':
        return 'Échoué';
      default:
        return status;
    }
  }
}
