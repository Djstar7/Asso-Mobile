import 'api_provider.dart';
import '../../core/values/constants.dart';

class PackageService {
  /// Get all available storage packages
  static Future<ApiResponse> getPackages() async {
    print('');
    print('========================================');
    print('📦 PACKAGE SERVICE: Get Packages START');
    print('========================================');

    try {
      print('🌐 Calling API: GET /v1/packages');

      final response = await ApiProvider.get('/v1/packages');

      print('✅ PACKAGE SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      if (response.data != null) {
        final packages = response.data!['packages'] ?? [];
        print('  └─ Packages count: ${packages.length}');
      }
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 PACKAGE SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Subscribe to a package with wallet type selection
  /// walletType: 'kpay' or 'paypal'
  static Future<ApiResponse> subscribeToPackage(
    int packageId, {
    required String walletType,
  }) async {
    print('');
    print('========================================');
    print('💳 PACKAGE SERVICE: Subscribe Package START');
    print('========================================');
    print('  └─ Package ID: $packageId');
    print('  └─ Wallet Type: $walletType');

    try {
      print('🌐 Calling API: POST /v1/packages/subscribe');

      final response = await ApiProvider.post(
        '/v1/packages/subscribe',
        body: {
          'package_id': packageId,
          'wallet_type': walletType,
        },
      );

      print('✅ PACKAGE SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      if (response.data != null && response.data!['vendor_package'] != null) {
        final vendorPackage = response.data!['vendor_package'];
        print('  └─ Storage Total: ${vendorPackage['storage_total_mb']} MB');
        print('  └─ Expires At: ${vendorPackage['expires_at']}');
        print('  └─ Wallet Used: $walletType');
      }
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 PACKAGE SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Souscrire à un package de stockage via un rail de paiement DIRECT
  /// (identique au parcours acheteur : KPay Mobile Money / PayPal / Stripe).
  ///
  ///  - kpay_direct  : nécessite [provider] + [phoneNumber] (fournis par le
  ///    KpayDirectPaymentSheet, mêmes valeurs que les commandes).
  ///  - paypal_direct / stripe_direct : aucune donnée supplémentaire ; la réponse
  ///    contient une [approval_url] à ouvrir en WebView.
  ///
  /// Réponse 201 : { success, message, payment_mode, subscription_id,
  ///                 status:"pending", payment_reference, approval_url }
  static Future<ApiResponse> subscribePackageDirect(
    int packageId, {
    required String paymentMode,
    String? provider,
    String? phoneNumber,
  }) async {
    print('');
    print('========================================');
    print('💳 PACKAGE SERVICE: Subscribe (direct) START');
    print('========================================');
    print('  └─ Package ID: $packageId');
    print('  └─ Payment mode: $paymentMode');

    try {
      final body = <String, dynamic>{
        'package_id': packageId,
        'payment_mode': paymentMode,
      };
      if (paymentMode == 'kpay_direct') {
        body['provider'] = provider;
        body['phone_number'] = phoneNumber;
      }

      final response = await ApiProvider.post(
        AppConstants.subscribePackageUrl,
        body: body,
      );

      print('✅ PACKAGE SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('  └─ Subscription ID: ${response.data?['subscription_id']}');
      print('  └─ Approval URL: ${response.data?['approval_url']}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 PACKAGE SERVICE: Exception!');
      print('  └─ Error: $e');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Statut de paiement d'un abonnement (à POLLER tant que status == "pending").
  ///
  /// Réponse : { success, data:{ subscription_id, status:"pending|paid|failed",
  ///             payment_mode, payment_reference, vendor_package_id,
  ///             vendor_package:{...}|null } }
  static Future<ApiResponse> getSubscriptionPaymentStatus(
    int subscriptionId,
  ) async {
    try {
      final response = await ApiProvider.get(
        '${AppConstants.packageSubscriptionUrl}/$subscriptionId/payment-status',
      );
      return response;
    } catch (e) {
      print('💥 PACKAGE SERVICE: subscription payment-status exception: $e');
      rethrow;
    }
  }

  /// Get all available certification packages
  static Future<ApiResponse> getCertificationPackages() async {
    print('');
    print('========================================');
    print('✅ PACKAGE SERVICE: Get Certification Packages START');
    print('========================================');

    try {
      print('🌐 Calling API: GET /v1/packages/certification');

      final response = await ApiProvider.get('/v1/packages/certification');

      print('✅ PACKAGE SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      if (response.data != null) {
        final packages = response.data!['packages'] ?? [];
        print('  └─ Certification Packages count: ${packages.length}');
      }
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 PACKAGE SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Get current active package for vendor
  static Future<ApiResponse> getCurrentPackage() async {
    print('');
    print('========================================');
    print('📊 PACKAGE SERVICE: Get Current Package START');
    print('========================================');

    try {
      print('🌐 Calling API: GET /v1/vendor/package/current');

      final response = await ApiProvider.get('/v1/vendor/package/current');

      print('✅ PACKAGE SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      if (response.data != null) {
        final hasPackage = response.data!['has_package'] ?? false;
        print('  └─ Has Package: $hasPackage');

        if (hasPackage && response.data!['vendor_package'] != null) {
          final vendorPackage = response.data!['vendor_package'];
          print('  └─ Storage Used: ${vendorPackage['storage_used_mb']} MB');
          print('  └─ Storage Total: ${vendorPackage['storage_total_mb']} MB');
          print('  └─ Storage Percentage: ${vendorPackage['storage_percentage_used']}%');
          print('  └─ Days Remaining: ${vendorPackage['days_remaining']}');
        }
      }
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 PACKAGE SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }
}
