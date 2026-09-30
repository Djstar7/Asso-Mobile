import 'package:firebase_messaging/firebase_messaging.dart';
import '../../core/values/constants.dart';
import '../../modules/shipConfig/models/sync_models.dart';
import '../models/deliverer_model.dart';
import 'api_provider.dart';
import 'package:get/get.dart';

/// Service pour la gestion de la synchronisation des livreurs
class DelivererService {
  /// Vérifie la validité d'un code de synchronisation
  ///
  /// Paramètres:
  /// - [syncCode] : Code de synchronisation format XXXX-XXXX-XXXX
  ///
  /// Retourne:
  /// - is_valid: boolean
  /// - is_used: boolean
  /// - is_expired: boolean
  /// - expires_at: datetime
  static Future<ApiResponse> verifySyncCode({
    required String syncCode,
  }) async {
    print('');
    print('========================================');
    print('🔍 DELIVERER SERVICE: Verify Sync Code START');
    print('========================================');
    print('  └─ Code: $syncCode');

    try {
      final response = await ApiProvider.post(
        AppConstants.delivererVerifySyncCodeUrl,
        body: {
          'sync_code': syncCode,
        },
      );

      print('✅ DELIVERER SERVICE: Verification completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 DELIVERER SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Synchronise le profil utilisateur avec une entreprise de livraison
  ///
  /// Paramètres:
  /// - [syncCode] : Code de synchronisation format XXXX-XXXX-XXXX
  /// - [deviceToken] : Token FCM pour les notifications (optionnel)
  ///
  /// Retourne:
  /// - success: boolean
  /// - message: string
  /// - company: DelivererCompany
  /// - zones: List<DeliveryZone>
  static Future<SyncProfileResponse> syncProfile({
    required String syncCode,
    String? deviceToken,
  }) async {
    print('');
    print('========================================');
    print('🔄 DELIVERER SERVICE: Sync Profile START');
    print('========================================');
    print('  └─ Code: $syncCode');
    print('  └─ Device Token: ${deviceToken != null ? 'Present' : 'Not provided'}');

    try {
      // Récupérer le token FCM si non fourni
      String? fcmToken = deviceToken;
      if (fcmToken == null) {
        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
          print('  └─ FCM Token retrieved: ${fcmToken != null ? 'Yes' : 'No'}');
          if (fcmToken != null) {
            print('  └─ FCM Token: ${fcmToken.substring(0, 20)}...');
          }
        } catch (e) {
          print('  └─ FCM Token retrieval failed: $e');
          print('  └─ Continuing without FCM token (will work but no push notifications)');
          fcmToken = null; // Continuer sans token
        }
      }

      // Préparer le body
      final Map<String, dynamic> body = {
        'sync_code': syncCode,
      };

      if (fcmToken != null) {
        body['device_token'] = fcmToken;
      }

      print('🌐 DELIVERER SERVICE: Calling API...');
      print('  └─ Endpoint: ${AppConstants.delivererSyncProfileUrl}');

      final response = await ApiProvider.post(
        AppConstants.delivererSyncProfileUrl,
        body: body,
      );

      print('✅ DELIVERER SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('  └─ Response data type: ${response.data.runtimeType}');
      print('  └─ Response data keys: ${response.data?.keys}');
      print('  └─ Response data: ${response.data}');

      // Parser la réponse
      final syncResponse = SyncProfileResponse.fromJson(response.data ?? {});

      print('  └─ SyncResponse success: ${syncResponse.success}');
      print('  └─ SyncResponse message: ${syncResponse.message}');
      print('  └─ SyncResponse company: ${syncResponse.company}');
      print('  └─ SyncResponse zones: ${syncResponse.zones?.length ?? 0}');

      if (syncResponse.success && syncResponse.company != null) {
        print('  └─ Company: ${syncResponse.company!.name}');
        print('  └─ Zones: ${syncResponse.zones?.length ?? 0}');

        if (syncResponse.zones != null && syncResponse.zones!.isNotEmpty) {
          for (var zone in syncResponse.zones!) {
            print('    ├─ ${zone.name}');
            if (zone.activePricelist != null) {
              print('    │  └─ Tarif: ${zone.activePricelist!.pricingType.label}');
            }
          }
        }
      }

      print('========================================');
      return syncResponse;
    } catch (e, stackTrace) {
      print('💥 DELIVERER SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');

      // Retourner une réponse d'erreur
      return SyncProfileResponse(
        success: false,
        message: 'data.deliverer.sync_error'.trParams({'error': '$e'}),
      );
    }
  }

  /// Désynchronise le profil utilisateur
  ///
  /// Retire le rôle livreur et marque le code de synchronisation comme non utilisé
  ///
  /// Retourne:
  /// - success: boolean
  /// - message: string
  static Future<ApiResponse> unsyncProfile() async {
    print('');
    print('========================================');
    print('🔴 DELIVERER SERVICE: Unsync Profile START');
    print('========================================');

    try {
      print('🌐 DELIVERER SERVICE: Calling API...');
      print('  └─ Endpoint: ${AppConstants.delivererUnsyncProfileUrl}');

      final response = await ApiProvider.post(
        AppConstants.delivererUnsyncProfileUrl,
        body: {},
      );

      print('✅ DELIVERER SERVICE: API call completed');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');
      print('  └─ Message: ${response.message}');

      if (response.success) {
        print('  └─ Unsync successful!');
        print('  └─ User role changed');
      }

      print('========================================');
      return response;
    } catch (e, stackTrace) {
      print('💥 DELIVERER SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Récupère les informations de la company du livreur (si déjà synchronisé)
  static Future<ApiResponse> getDelivererCompanyInfo() async {
    print('');
    print('========================================');
    print('ℹ️ DELIVERER SERVICE: Get Company Info START');
    print('========================================');

    try {
      // Pour l'instant on utilise le endpoint du dashboard qui retourne les infos
      final response = await ApiProvider.get(AppConstants.deliveryDashboardUrl);

      print('✅ DELIVERER SERVICE: Company info retrieved');
      print('  └─ Success: ${response.success}');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 DELIVERER SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Récupère les informations de l'entreprise du livreur
  static Future<ApiResponse> getMyCompany() async {
    print('');
    print('========================================');
    print('🏢 DELIVERER SERVICE: Get My Company START');
    print('========================================');

    try {
      // Endpoint pour récupérer l'entreprise du livreur
      final response = await ApiProvider.get(AppConstants.deliveryDashboardUrl);

      if (response.success && response.data != null) {
        print('  └─ Response keys: ${response.data!.keys}');
        if (response.data!['company'] != null) {
          print('  └─ Company name: ${response.data!['company']['name']}');
          print('  └─ Company logo: ${response.data!['company']['logo']}');
        }
      }

      print('✅ DELIVERER SERVICE: My company retrieved');
      print('========================================');

      return response;
    } catch (e, stackTrace) {
      print('💥 DELIVERER SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      rethrow;
    }
  }

  /// Récupère tous les partenaires de livraison avec leur position
  /// Cette méthode est utilisée pour afficher les livreurs sur la map
  static Future<List<DelivererModel>> getDeliveryPartners() async {
    print('');
    print('========================================');
    print('📍 DELIVERER SERVICE: Get Delivery Partners START');
    print('========================================');

    try {
      final response = await ApiProvider.get(AppConstants.deliveryPartnersUrl);

      print('✅ DELIVERER SERVICE: Partners retrieved');
      print('  └─ Success: ${response.success}');
      print('  └─ Status: ${response.statusCode}');

      if (response.success && response.data != null) {
        final deliverersData = response.data!['deliverers'] as List<dynamic>?;

        if (deliverersData != null && deliverersData.isNotEmpty) {
          final deliverers = deliverersData
              .map((json) => DelivererModel.fromJson(json as Map<String, dynamic>))
              .toList();

          print('  └─ Total deliverers: ${deliverers.length}');
          for (var deliverer in deliverers) {
            print('    ├─ ${deliverer.name} (${deliverer.zone.name})');
            print('    │  └─ Position: (${deliverer.zone.latitude}, ${deliverer.zone.longitude})');
          }

          print('========================================');
          return deliverers;
        } else {
          print('  └─ No deliverers found');
          print('========================================');
          return [];
        }
      } else {
        print('  └─ API call failed: ${response.message}');
        print('========================================');
        return [];
      }
    } catch (e, stackTrace) {
      print('💥 DELIVERER SERVICE: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('========================================');
      return [];
    }
  }
}
