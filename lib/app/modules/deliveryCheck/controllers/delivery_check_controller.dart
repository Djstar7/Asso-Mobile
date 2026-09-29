import 'package:get/get.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/deliverer_service.dart';
import '../../../data/providers/storage_service.dart';

/// Controller pour l'écran de vérification du mode livreur
/// Cet écran détermine si l'utilisateur doit aller vers la config ou le dashboard
class DeliveryCheckController extends GetxController {
  final isLoading = true.obs;
  final statusMessage = 'delivery_check.verifying'.tr.obs;
  final companyName = ''.obs;
  final companyLogo = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    _checkDeliveryStatus();
  }

  /// Vérifie le statut de livraison de l'utilisateur et redirige
  Future<void> _checkDeliveryStatus() async {
    try {
      print('');
      print('========================================');
      print('🔍 DELIVERY CHECK: Verification START');
      print('========================================');

      // Étape 1: Vérifier le cache local
      statusMessage.value = 'delivery_check.checking_profile'.tr;
      var currentUser = StorageService.getUser();
      print('  └─ Cache local: role=${currentUser?.role}, roles=${currentUser?.roles}');

      // Étape 2: Si pas dans le cache ou pas livreur, rafraîchir depuis le backend
      if (currentUser == null || !currentUser.isDelivery) {
        print('⚠️  Cache local ne confirme pas, vérification backend...');
        statusMessage.value = 'delivery_check.syncing'.tr;

        await _refreshUserProfileFromBackend();
        currentUser = StorageService.getUser();
        print('  └─ Après rafraîchissement: role=${currentUser?.role}, roles=${currentUser?.roles}');
      }

      // Étape 3: Vérifier si l'utilisateur est livreur
      if (currentUser != null && currentUser.isDelivery) {
        print('✅ Utilisateur est livreur');
        statusMessage.value = 'delivery_check.loading_info'.tr;

        // Charger les infos de livraison
        try {
          final response = await DelivererService.getMyCompany();
          print('  └─ Company info loaded: ${response.success}');

          if (response.data != null) {
            print('  └─ Response keys: ${response.data!.keys}');

            // Extraire les infos de l'entreprise
            if (response.data!['company'] != null) {
              final company = response.data!['company'] as Map<String, dynamic>;
              companyName.value = company['name'] ?? '';
              companyLogo.value = company['logo'];

              print('  └─ Company name: ${companyName.value}');
              print('  └─ Company logo: ${companyLogo.value}');

              // Mettre à jour le message de statut avec le nom de l'entreprise
              if (companyName.value.isNotEmpty) {
                statusMessage.value = 'delivery_check.welcome'.trParams({
                  'company': companyName.value,
                });
              }

              // Petit délai pour que l'utilisateur voie le logo et le nom
              await Future.delayed(const Duration(milliseconds: 800));
            }
          }
        } catch (e) {
          print('⚠️  Erreur lors du chargement des infos: $e');
          // Continue quand même vers le dashboard
        }

        print('🎯 DELIVERY CHECK: Redirection vers dashboard');
        print('========================================');

        // Quitté entre-temps avec le bouton retour : ne pas y ramener de force.
        if (isClosed) return;
        // Rediriger vers le dashboard
        Get.offAllNamed('/delivery-dashboard');
      } else {
        print('ℹ️  Utilisateur n\'est pas encore livreur');
        statusMessage.value = 'delivery_check.setup_required'.tr;

        // Délai pour une transition smooth
        await Future.delayed(const Duration(milliseconds: 300));

        print('🎯 DELIVERY CHECK: Redirection vers configuration');
        print('========================================');

        // Quitté entre-temps avec le bouton retour : ne pas y ramener de force.
        if (isClosed) return;
        // Rediriger vers la configuration
        Get.offAllNamed('/ship-config');
      }
    } catch (e, stackTrace) {
      print('❌ DELIVERY CHECK: Exception!');
      print('  └─ Error: $e');
      print('  └─ Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      print('========================================');

      // En cas d'erreur, rediriger vers la config par sécurité
      statusMessage.value = 'delivery_check.error_redirecting'.tr;
      await Future.delayed(const Duration(milliseconds: 500));
      if (isClosed) return;
      Get.offAllNamed('/ship-config');
    }
  }

  /// Rafraîchit le profil utilisateur depuis le backend
  Future<void> _refreshUserProfileFromBackend() async {
    try {
      print('🔄 Rafraîchissement du profil depuis le backend...');

      final response = await ApiProvider.get('/v1/auth/profile');

      print('  └─ Response success: ${response.success}');
      print('  └─ Response status: ${response.statusCode}');

      if (response.success && response.data != null) {
        final responseData = response.data!;

        if (responseData['user'] != null) {
          final userData = responseData['user'] as Map<String, dynamic>;

          print('  └─ User ID: ${userData['id']}');
          print('  └─ User role: ${userData['role']}');
          print('  └─ User roles: ${userData['roles']}');

          try {
            final user = UserModel.fromJson(userData);
            StorageService.saveUser(user);
            print('✅ Profil rafraîchi: role=${user.role}, roles=${user.roles}, isDelivery=${user.isDelivery}');
          } catch (parseError, stackTrace) {
            print('❌ Erreur de parsing du profil: $parseError');
            print('  └─ Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
          }
        } else {
          print('⚠️  Pas de données utilisateur dans la réponse');
        }
      } else {
        print('⚠️  Erreur lors du rafraîchissement: ${response.message}');
      }
    } catch (e, stackTrace) {
      print('❌ Exception lors du rafraîchissement du profil: $e');
      print('  └─ Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      rethrow;
    }
  }
}
