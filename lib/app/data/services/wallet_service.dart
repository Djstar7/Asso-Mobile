import '../providers/api_provider.dart';
import '../providers/wallet_service.dart' as wallet_provider;
import '../models/wallet_model.dart';
import '../../core/values/constants.dart';

/// Injectable wallet service that wraps the static provider
class WalletService {
  /// Get wallet stats and balances
  Future<WalletModel?> getWalletStats() async {
    try {
      final response = await wallet_provider.WalletService.getWallet();

      if (response.success && response.data != null) {
        // Extract the actual data from the response
        final actualData = response.data!['data'] as Map<String, dynamic>?;
        if (actualData != null) {
          return WalletModel.fromJson(actualData);
        }
      }
      return null;
    } catch (e) {
      print('[WalletService] Error getting wallet stats: $e');
      return null;
    }
  }

  /// Get transaction history
  Future<Map<String, dynamic>> getTransactionHistory({
    int page = 1,
    int perPage = 20,
    String? type,
  }) async {
    try {
      final response = await wallet_provider.WalletService.getTransactions(
        page: page,
        perPage: perPage,
        type: type,
      );

      if (response.success && response.data != null) {
        // Extract the actual data from the response
        final actualData = response.data!['data'] as Map<String, dynamic>?;
        if (actualData != null) {
          final transactionsList = actualData['transactions'] as List? ?? [];

          return {
            'transactions': transactionsList
                .map((t) => WalletTransactionModel.fromJson(t))
                .toList(),
            'current_page': actualData['current_page'] ?? page,
            'last_page': actualData['last_page'] ?? 1,
            'total': actualData['total'] ?? 0,
            'per_page': actualData['per_page'] ?? perPage,
          };
        }
      }

      return {
        'transactions': <WalletTransactionModel>[],
        'current_page': 1,
        'last_page': 1,
        'total': 0,
        'per_page': perPage,
      };
    } catch (e) {
      print('[WalletService] Error getting transactions: $e');
      return {
        'transactions': <WalletTransactionModel>[],
        'current_page': 1,
        'last_page': 1,
        'total': 0,
        'per_page': perPage,
      };
    }
  }

  /// Recharge wallet
  Future<Map<String, dynamic>> rechargeWallet({
    required double amount,
    required String paymentMethod,
    String? provider, // code opérateur KPay (ex. MTN_MOMO_CMR)
    String? phoneNumber,
  }) async {
    try {
      final response = await wallet_provider.WalletService.recharge(
        amount: amount,
        paymentMethod: paymentMethod,
        provider: provider,
        phoneNumber: phoneNumber,
      );

      if (response.success) {
        return {
          'success': true,
          'message': response.data?['message'] ?? 'Recharge réussie',
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'Échec de la recharge',
      };
    } catch (e) {
      print('[WalletService] Error recharging wallet: $e');
      return {
        'success': false,
        'message': 'Erreur lors de la recharge',
      };
    }
  }

  /// Check if user can pay with wallet
  Future<Map<String, dynamic>> canPayWithWallet(double amount) async {
    try {
      final response = await wallet_provider.WalletService.canPay(
        amount: amount,
      );

      if (response.success && response.data != null) {
        // Extract the actual data from the response
        final actualData = response.data!['data'] as Map<String, dynamic>?;
        if (actualData != null) {
          return actualData;
        }
      }

      return {
        'can_pay': false,
        'message': 'Impossible de vérifier le solde',
      };
    } catch (e) {
      print('[WalletService] Error checking payment ability: $e');
      return {
        'can_pay': false,
        'message': 'Erreur lors de la vérification',
      };
    }
  }

  /// Pay with wallet
  Future<Map<String, dynamic>> payWithWallet({
    required double amount,
    required String description,
    required String referenceType,
    required int referenceId,
    required String paymentProvider,
  }) async {
    try {
      final response = await wallet_provider.WalletService.pay(
        amount: amount,
        description: description,
        referenceType: referenceType,
        referenceId: referenceId,
        paymentProvider: paymentProvider,
      );

      if (response.success) {
        return {
          'success': true,
          'message': response.data?['message'] ?? 'Paiement réussi',
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'Échec du paiement',
      };
    } catch (e) {
      print('[WalletService] Error paying with wallet: $e');
      return {
        'success': false,
        'message': 'Erreur lors du paiement',
      };
    }
  }

  /// Get withdrawal balances
  Future<Map<String, dynamic>> getWithdrawalBalances() async {
    try {
      final response = await wallet_provider.WalletService.getWithdrawalBalances();

      if (response.success && response.data != null) {
        // Extract the actual data from the response
        final actualData = response.data!['data'] as Map<String, dynamic>?;
        if (actualData != null) {
          return {
            'success': true,
            ...actualData,
          };
        }
      }

      return {
        'success': false,
        'kpay_wallet_balance': 0.0,
        'paypal_balance': 0.0,
        'total_balance': 0.0,
      };
    } catch (e) {
      print('[WalletService] Error getting withdrawal balances: $e');
      return {
        'success': false,
        'kpay_wallet_balance': 0.0,
        'paypal_balance': 0.0,
        'total_balance': 0.0,
      };
    }
  }

  /// Initiate KPay withdrawal
  Future<Map<String, dynamic>> initiateKpayWithdrawal({
    required double amount,
    required String provider, // code opérateur KPay (ex. MTN_MOMO_CMR)
    required String phoneNumber,
    String? notes,
  }) async {
    try {
      final response = await wallet_provider.WalletService.withdrawKpay(
        amount: amount,
        provider: provider,
        phoneNumber: phoneNumber,
        notes: notes,
      );

      if (response.success) {
        return {
          'success': true,
          'message': response.data?['message'] ?? 'Retrait initié avec succès',
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'Échec du retrait',
      };
    } catch (e) {
      print('[WalletService] Error initiating KPay withdrawal: $e');
      return {
        'success': false,
        'message': 'Erreur lors de l\'initiation du retrait',
      };
    }
  }

  /// Initiate PayPal withdrawal
  Future<Map<String, dynamic>> initiatePayPalWithdrawal({
    required double amount,
    required String paypalEmail,
    String? notes,
  }) async {
    try {
      final response = await wallet_provider.WalletService.withdrawPaypal(
        amount: amount,
        paypalEmail: paypalEmail,
        notes: notes,
      );

      if (response.success) {
        return {
          'success': true,
          'message': response.data?['message'] ?? 'Retrait PayPal initié avec succès',
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'Échec du retrait PayPal',
      };
    } catch (e) {
      print('[WalletService] Error initiating PayPal withdrawal: $e');
      return {
        'success': false,
        'message': 'Erreur lors de l\'initiation du retrait PayPal',
      };
    }
  }

  /// Check withdrawal status
  Future<Map<String, dynamic>> checkWithdrawalStatus(int withdrawalId) async {
    try {
      final response = await wallet_provider.WalletService.checkWithdrawalStatus(
        withdrawalId,
      );

      if (response.success && response.data != null) {
        // Extract the actual data from the response
        final actualData = response.data!['data'] as Map<String, dynamic>?;
        if (actualData != null) {
          return {
            'success': true,
            ...actualData,
          };
        }
      }

      return {
        'success': false,
        'message': 'Impossible de vérifier le statut',
      };
    } catch (e) {
      print('[WalletService] Error checking withdrawal status: $e');
      return {
        'success': false,
        'message': 'Erreur lors de la vérification du statut',
      };
    }
  }

  /// Get withdrawal history
  Future<Map<String, dynamic>> getWithdrawalHistory({
    int page = 1,
    int perPage = 20,
    String? provider,
    String? status,
  }) async {
    try {
      final response = await wallet_provider.WalletService.getWithdrawalHistory(
        page: page,
        perPage: perPage,
        provider: provider,
        status: status,
      );

      if (response.success && response.data != null) {
        // Extract the actual data from the response
        final actualData = response.data!['data'] as Map<String, dynamic>?;
        if (actualData != null) {
          return actualData;
        }
      }

      return {
        'withdrawals': [],
        'current_page': 1,
        'last_page': 1,
        'total': 0,
        'per_page': perPage,
      };
    } catch (e) {
      print('[WalletService] Error getting withdrawal history: $e');
      return {
        'withdrawals': [],
        'current_page': 1,
        'last_page': 1,
        'total': 0,
        'per_page': perPage,
      };
    }
  }

  /// Check payment status (for recharge polling)
  Future<Map<String, dynamic>> checkPaymentStatus(int paymentId) async {
    try {
      final response = await ApiProvider.get('${AppConstants.walletPaymentStatusUrl}/$paymentId');

      if (response.success && response.data != null) {
        // Extract the actual data from the response
        final actualData = response.data!['data'] as Map<String, dynamic>?;
        if (actualData != null) {
          return {
            'success': true,
            ...actualData,
          };
        }
      }

      return {
        'success': false,
        'message': 'Impossible de vérifier le statut du paiement',
      };
    } catch (e) {
      print('[WalletService] Error checking payment status: $e');
      return {
        'success': false,
        'message': 'Erreur lors de la vérification du statut',
      };
    }
  }

  /// Create native PayPal order (for PayPal SDK)
  Future<Map<String, dynamic>> createNativePayPalOrder({
    required double amount,
  }) async {
    try {
      final response = await ApiProvider.post(
        AppConstants.walletPayPalCreateNativeOrderUrl,
        body: {'amount': amount},
      );

      if (response.success) {
        return {
          'success': true,
          'message': 'Ordre PayPal créé',
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'Échec de la création de l\'ordre',
      };
    } catch (e) {
      print('[WalletService] Error creating PayPal order: $e');
      return {
        'success': false,
        'message': 'Erreur lors de la création de l\'ordre PayPal',
      };
    }
  }

  /// Capture native PayPal order
  Future<Map<String, dynamic>> captureNativePayPalOrder({
    required int paymentId,
    required String orderId,
  }) async {
    try {
      final response = await ApiProvider.post(
        AppConstants.walletPayPalCaptureNativeOrderUrl,
        body: {
          'payment_id': paymentId,
          'order_id': orderId,
        },
      );

      if (response.success) {
        return {
          'success': true,
          'message': response.data?['message'] ?? 'Paiement capturé avec succès',
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'Échec de la capture du paiement',
      };
    } catch (e) {
      print('[WalletService] Error capturing PayPal order: $e');
      return {
        'success': false,
        'message': 'Erreur lors de la capture du paiement',
      };
    }
  }
}
