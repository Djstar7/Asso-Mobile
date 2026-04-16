import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/deliverer_service.dart';
import '../../../data/providers/storage_service.dart';
import '../models/sync_models.dart';

class ShipConfigController extends GetxController {
  // Storage
  final _storage = GetStorage();

  // État de chargement
  final isLoading = false.obs;
  final isSyncing = false.obs;
  final isVerifying = false.obs;

  // Code de synchronisation
  final syncCode = ''.obs;
  final TextEditingController syncCodeController = TextEditingController();

  // Informations de synchronisation
  final Rx<DelivererCompany?> delivererCompany = Rx<DelivererCompany?>(null);
  final RxList<DeliveryZone> deliveryZones = <DeliveryZone>[].obs;

  @override
  void onInit() {
    super.onInit();
    // La vérification du statut livreur est maintenant faite dans DeliveryCheckController
    // avant d'arriver sur cet écran, donc pas besoin de vérifier ici
    _loadCachedDeliveryInfo();
  }

  /// Vérifie si l'utilisateur est déjà livreur et redirige si oui
  Future<void> _checkIfAlreadyDeliverer() async {
    print('🔍 Vérification du statut livreur...');

    // D'abord vérifier le cache local
    var currentUser = StorageService.getUser();
    print(
      '  └─ Cache local: role=${currentUser?.role}, roles=${currentUser?.roles}',
    );

    // Si le cache dit qu'il est livreur, OK
    if (currentUser != null && currentUser.isDelivery) {
      print('✅ Cache local confirme : utilisateur est livreur');
      await Future.delayed(const Duration(milliseconds: 500));
      navigateToDeliveryDashboard();
      return;
    }

    // Sinon, rafraîchir depuis le backend pour être sûr
    print('⚠️  Cache local ne confirme pas, vérification backend...');
    await _refreshUserProfileFromBackend();

    // Re-vérifier après rafraîchissement
    currentUser = StorageService.getUser();
    print(
      '  └─ Après rafraîchissement: role=${currentUser?.role}, roles=${currentUser?.roles}',
    );

    if (currentUser != null && currentUser.isDelivery) {
      print('✅ Backend confirme : utilisateur est livreur');

      // Charger les infos de livraison
      await refreshDeliveryInfo();

      await Future.delayed(const Duration(milliseconds: 500));
      navigateToDeliveryDashboard();
    } else {
      print('ℹ️  Utilisateur n\'est pas encore livreur');
    }
  }

  /// Rafraîchit le profil utilisateur depuis le backend (endpoint /profile)
  Future<void> _refreshUserProfileFromBackend() async {
    try {
      print('🔄 Rafraîchissement du profil depuis le backend...');

      // Utiliser l'endpoint standard de profil
      final response = await ApiProvider.get('/v1/auth/profile');

      print('  └─ Response success: ${response.success}');
      print('  └─ Response status: ${response.statusCode}');
      print('  └─ Response data type: ${response.data.runtimeType}');

      if (response.success && response.data != null) {
        final responseData = response.data!;

        // Le backend retourne {success: true, user: {...}}
        // Il faut extraire l'objet 'user'
        if (responseData['user'] != null) {
          final userData = responseData['user'] as Map<String, dynamic>;

          print('  └─ User ID: ${userData['id']}');
          print('  └─ User role: ${userData['role']}');
          print('  └─ User roles: ${userData['roles']}');

          try {
            final user = UserModel.fromJson(userData);
            StorageService.saveUser(user);
            print(
              '✅ Profil rafraîchi: role=${user.role}, roles=${user.roles}, isDelivery=${user.isDelivery}',
            );
          } catch (parseError, stackTrace) {
            print('❌ Erreur de parsing du profil: $parseError');
            print(
              '  └─ Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}',
            );
          }
        } else {
          print('⚠️  Pas de données utilisateur dans la réponse');
        }
      } else {
        print('⚠️  Erreur lors du rafraîchissement: ${response.message}');
      }
    } catch (e, stackTrace) {
      print('❌ Exception lors du rafraîchissement du profil: $e');
      print(
        '  └─ Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}',
      );
    }
  }

  @override
  void onClose() {
    syncCodeController.dispose();
    super.onClose();
  }

  /// Charge les informations de livraison mises en cache
  Future<void> _loadCachedDeliveryInfo() async {
    isLoading.value = true;

    try {
      // Charger les infos de company depuis le cache
      final companyData = _storage.read('deliverer_company');
      if (companyData != null) {
        delivererCompany.value = DelivererCompany.fromJson(
          Map<String, dynamic>.from(companyData),
        );
      }

      // Charger les zones depuis le cache
      final zonesData = _storage.read('delivery_zones');
      if (zonesData != null) {
        deliveryZones.value = (zonesData as List<dynamic>)
            .map(
              (zone) => DeliveryZone.fromJson(Map<String, dynamic>.from(zone)),
            )
            .toList();
      }

      // Si l'utilisateur est déjà synchronisé, charger les infos depuis le backend
      if (delivererCompany.value != null) {
        await refreshDeliveryInfo();
      }
    } catch (e) {
      print('Erreur lors du chargement des infos en cache: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Rafraîchit les informations de livraison depuis le backend
  Future<void> refreshDeliveryInfo() async {
    try {
      final response = await DelivererService.getDelivererCompanyInfo();
      if (response.success && response.data != null) {
        final data = response.data!;

        // Mettre à jour les infos en cache
        if (data['company'] != null) {
          _storage.write('deliverer_company', data['company']);
        }
        if (data['zones'] != null) {
          _storage.write('delivery_zones', data['zones']);
        }

        // Mettre à jour les observables
        if (data['company'] != null) {
          delivererCompany.value = DelivererCompany.fromJson(
            data['company'] as Map<String, dynamic>,
          );
        }
        if (data['zones'] != null) {
          deliveryZones.value = (data['zones'] as List<dynamic>)
              .map(
                (zone) => DeliveryZone.fromJson(zone as Map<String, dynamic>),
              )
              .toList();
        }
      }
    } catch (e) {
      print('Erreur lors du rafraîchissement des infos: $e');
    }
  }

  /// Valide le format du code de synchronisation (XXXX-XXXX-XXXX)
  bool validateSyncCode(String code) {
    // Format: XXXX-XXXX-XXXX (14 caractères total)
    final pattern = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    return pattern.hasMatch(code);
  }

  /// Vérifie la validité du code de synchronisation
  Future<void> verifySyncCode() async {
    final code = syncCodeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      _showErrorSnackbar(
        'Champ requis',
        'Veuillez entrer votre code de synchronisation',
      );
      return;
    }

    if (!validateSyncCode(code)) {
      _showErrorSnackbar(
        'Format invalide',
        'Le code doit être au format: XXXX-XXXX-XXXX',
      );
      return;
    }

    isVerifying.value = true;

    try {
      final response = await DelivererService.verifySyncCode(syncCode: code);

      if (response.success && response.data != null) {
        final data = response.data!;
        final isValid = data['is_valid'] ?? false;
        final isUsed = data['is_used'] ?? false;
        final isExpired = data['is_expired'] ?? false;

        if (!isValid) {
          if (isUsed) {
            _showErrorSnackbar(
              'Code déjà utilisé',
              'Ce code de synchronisation a déjà été utilisé par un autre utilisateur',
            );
          } else if (isExpired) {
            _showErrorSnackbar(
              'Code expiré',
              'Ce code de synchronisation a expiré. Veuillez contacter le support',
            );
          } else {
            _showErrorSnackbar(
              'Code invalide',
              'Ce code de synchronisation n\'existe pas ou est invalide',
            );
          }
        } else {
          _showSuccessSnackbar(
            'Code valide',
            'Le code est valide ! Vous pouvez synchroniser votre profil',
          );
        }
      } else {
        _showErrorSnackbar('Erreur', response.message);
      }
    } catch (e) {
      _showErrorSnackbar(
        'Erreur',
        'Une erreur est survenue lors de la vérification',
      );
    } finally {
      isVerifying.value = false;
    }
  }

  /// Synchronise le profil pour devenir livreur
  Future<void> syncProfileToDelivery() async {
    final code = syncCodeController.text.trim().toUpperCase();

    // Valider le code de synchronisation
    if (code.isEmpty) {
      _showErrorSnackbar(
        'Champ requis',
        'Veuillez entrer votre code de synchronisation',
      );
      return;
    }

    if (!validateSyncCode(code)) {
      _showErrorSnackbar(
        'Format invalide',
        'Le code doit être au format: XXXX-XXXX-XXXX',
      );
      return;
    }

    isSyncing.value = true;

    try {
      final response = await DelivererService.syncProfile(syncCode: code);

      if (response.success && response.company != null) {
        // Sauvegarder les informations
        syncCode.value = code;
        delivererCompany.value = response.company;
        deliveryZones.value = response.zones ?? [];

        // Mettre en cache
        _storage.write('deliverer_company', response.company!.toJson());
        if (response.zones != null) {
          _storage.write(
            'delivery_zones',
            response.zones!.map((zone) => zone.toJson()).toList(),
          );
        }

        _showSuccessSnackbar(
          'Synchronisation réussie',
          'Votre profil a été synchronisé avec ${response.company!.name} !',
        );

        // Rafraîchir le profil utilisateur pour mettre à jour le rôle
        await _refreshUserProfileFromBackend();

        // Naviguer vers le dashboard de livraison
        await Future.delayed(const Duration(seconds: 1));
        navigateToDeliveryDashboard();
      } else {
        // Gérer le cas où le code est déjà utilisé
        if (response.message.toLowerCase().contains('déjà été utilisé') ||
            response.message.toLowerCase().contains('already used')) {
          // Vérifier si l'utilisateur actuel est déjà livreur
          await _checkIfCurrentUserIsDeliverer();
        } else {
          _showErrorSnackbar('Erreur', response.message);
        }
      }
    } catch (e) {
      _showErrorSnackbar(
        'Erreur',
        'Une erreur est survenue lors de la synchronisation: $e',
      );
    } finally {
      isSyncing.value = false;
    }
  }

  /// Vérifie si l'utilisateur actuel est déjà livreur et redirige
  Future<void> _checkIfCurrentUserIsDeliverer() async {
    print('🔍 Vérification si l\'utilisateur est déjà livreur...');

    // Rafraîchir le profil depuis le backend
    await _refreshUserProfileFromBackend();

    final currentUser = StorageService.getUser();
    if (currentUser != null && currentUser.isDelivery) {
      print('✅ L\'utilisateur est déjà livreur !');

      // Charger les infos de livraison
      await refreshDeliveryInfo();

      _showSuccessSnackbar(
        'Déjà synchronisé',
        'Vous êtes déjà configuré comme livreur. Redirection...',
      );

      await Future.delayed(const Duration(seconds: 1));
      navigateToDeliveryDashboard();
    } else {
      print('❌ L\'utilisateur n\'est pas livreur');
      _showErrorSnackbar(
        'Code déjà utilisé',
        'Ce code de synchronisation a déjà été utilisé par un autre utilisateur.',
      );
    }
  }

  /// Contacte le support pour obtenir un code de synchronisation
  Future<void> contactSupport() async {
    try {
      final Uri supportUri = Uri.parse(
        'mailto:support@asso-corporation.com?subject=Demande de code de synchronisation livreur',
      );

      if (await canLaunchUrl(supportUri)) {
        await launchUrl(supportUri);
      } else {
        _showErrorSnackbar('Erreur', 'Impossible d\'ouvrir le client mail');
      }
    } catch (e) {
      _showErrorSnackbar('Erreur', 'Une erreur est survenue');
    }
  }

  /// Navigation vers le dashboard de livraison
  void navigateToDeliveryDashboard() {
    Get.offAllNamed('/delivery-dashboard');
  }

  // ========================================
  // HELPERS
  // ========================================

  /// Affiche un snackbar d'erreur
  void _showErrorSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.error,
      colorText: Get.theme.colorScheme.onError,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.error_outline, color: Colors.white),
      duration: const Duration(seconds: 4),
    );
  }

  /// Affiche un snackbar de succès
  void _showSuccessSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Get.theme.colorScheme.onPrimary,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      duration: const Duration(seconds: 3),
    );
  }

  /// Affiche un snackbar d'information
  void _showInfoSnackbar(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue.shade600,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.info_outline, color: Colors.white),
      duration: const Duration(seconds: 3),
    );
  }
}
