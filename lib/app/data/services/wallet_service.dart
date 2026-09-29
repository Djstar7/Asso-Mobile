import 'package:get/get.dart';
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
          'message': response.data?['message'] ?? 'data.wallet.recharge_success'.tr,
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'data.wallet.recharge_failed'.tr,
      };
    } catch (e) {
      print('[WalletService] Error recharging wallet: $e');
      return {
        'success': false,
        'message': 'data.wallet.recharge_error'.tr,
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
        'message': 'data.wallet.balance_check_failed'.tr,
      };
    } catch (e) {
      print('[WalletService] Error checking payment ability: $e');
      return {
        'can_pay': false,
        'message': 'data.wallet.check_error'.tr,
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
          'message': response.data?['message'] ?? 'data.wallet.payment_success'.tr,
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'data.wallet.payment_failed'.tr,
      };
    } catch (e) {
      print('[WalletService] Error paying with wallet: $e');
      return {
        'success': false,
        'message': 'data.wallet.payment_error'.tr,
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
          'message': response.data?['message'] ?? 'data.wallet.withdrawal_initiated'.tr,
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.data?['message'] ?? 'data.wallet.withdrawal_failed'.tr,
      };
    } catch (e) {
      print('[WalletService] Error initiating KPay withdrawal: $e');
      return {
        'success': false,
        'message': 'data.wallet.withdrawal_error'.tr,
      };
    }
  }

  /// Initiate Stripe withdrawal (virement bancaire vers l'IBAN validé)
  Future<Map<String, dynamic>> initiateStripeWithdrawal({
    required double amount,
    String? currency,
    String? notes,
  }) async {
    try {
      final response = await wallet_provider.WalletService.withdrawStripe(
        amount: amount,
        currency: currency,
        notes: notes,
      );

      if (response.success) {
        return {
          'success': true,
          'message': response.data?['message'] ?? 'data.wallet.transfer_initiated'.tr,
          ...?response.data,
        };
      }

      return {
        'success': false,
        'message': response.message.isNotEmpty
            ? response.message
            : (response.data?['message'] ?? 'data.wallet.transfer_failed'.tr),
      };
    } catch (e) {
      print('[WalletService] Error initiating Stripe withdrawal: $e');
      return {
        'success': false,
        'message': 'data.wallet.transfer_error'.tr,
      };
    }
  }


  /// Devis d'un virement IBAN : montant converti vers la devise du compte bancaire.
  Future<Map<String, dynamic>> getStripeWithdrawalQuote({
    required double amount,
    String? currency,
  }) async {
    try {
      final response = await wallet_provider.WalletService.stripeWithdrawalQuote(
        amount: amount,
        currency: currency,
      );

      if (response.success && response.data != null) {
        // `ApiResponse.data` porte le corps complet : le devis est sous `data`.
        final payload = response.data!['data'];
        return {
          'success': true,
          ...(payload is Map<String, dynamic> ? payload : response.data!),
        };
      }

      return {'success': false, 'message': response.message};
    } catch (e) {
      print('[WalletService] Error fetching Stripe quote: $e');
      return {'success': false, 'message': 'data.wallet.conversion_unavailable'.tr};
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
        'message': 'data.wallet.status_check_failed'.tr,
      };
    } catch (e) {
      print('[WalletService] Error checking withdrawal status: $e');
      return {
        'success': false,
        'message': 'data.wallet.status_check_error'.tr,
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
        'message': 'data.wallet.payment_status_check_failed'.tr,
      };
    } catch (e) {
      print('[WalletService] Error checking payment status: $e');
      return {
        'success': false,
        'message': 'data.wallet.status_check_error'.tr,
      };
    }
  }

}
