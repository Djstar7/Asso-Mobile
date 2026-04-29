import 'package:get/get.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/auth_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../routes/app_pages.dart';

class ProfileController extends GetxController {
  final RxMap<String, dynamic> profile = <String, dynamic>{}.obs;
  final RxBool isLoading = false.obs;
  final RxBool isGuest = true.obs;

  @override
  void onInit() {
    super.onInit();
    // Vérifier si l'utilisateur est connecté
    isGuest.value = !StorageService.isAuthenticated;

    // Charger le profil uniquement si l'utilisateur est connecté
    if (!isGuest.value) {
      _loadProfile();
    } else {
      // Mode invité - profil par défaut
      _setGuestProfile();
    }
  }

  void _setGuestProfile() {
    profile.value = {
      'name': 'Invité',
      'avatar': '?',
      'email': '',
      'phone': '',
      'location': 'Cameroun',
      'memberSince': '',
      'role': 'guest',
      'stats': {
        'orders': 0,
        'reviews': 0,
        'favorites': 0,
      },
    };
  }

  void _loadProfile() {
    // Load from cache first using StorageService
    final cachedUser = StorageService.getUser();
    if (cachedUser != null) {
      _setProfileData(cachedUser.toJson());
    }

    // Then refresh from API
    _refreshProfile();
  }

  /// Public method to reload profile (called after profile update)
  Future<void> reloadProfile() async {
    await _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    // Ne pas rafraîchir si en mode invité
    if (isGuest.value) return;

    isLoading.value = true;
    try {
      final response = await AuthService.getProfile();
      if (response.success && response.data != null) {
        final user = response.data!['user'];
        if (user != null) {
          _setProfileData(Map<String, dynamic>.from(user));
        }
      }
    } catch (e) {
      // Use cached data
    } finally {
      isLoading.value = false;
    }
  }

  /// Transform raw API data into view-compatible format
  void _setProfileData(Map<String, dynamic> data) {
    final fn = data['first_name'] ?? '';
    final ln = data['last_name'] ?? '';
    final fullName = '$fn $ln'.trim();

    // Compute initials for avatar
    String initials = '?';
    if (fullName.isNotEmpty) {
      final parts = fullName.split(' ');
      if (parts.length >= 2) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = fullName[0].toUpperCase();
      }
    }

    // Build profile map with keys expected by the view
    profile.value = {
      ...data,
      'name': fullName.isEmpty ? 'Utilisateur' : fullName,
      'avatar': initials,
      'email': data['email'] ?? '',
      'phone': data['phone'] ?? '',
      'location': data['address'] ?? data['city'] ?? 'Cameroun',
      'memberSince': _formatMemberSince(data['created_at']),
      'role': data['role'] ?? 'client',
      'stats': data['stats'] ?? {
        'orders': data['orders_count'] ?? 0,
        'reviews': data['reviews_count'] ?? 0,
        'favorites': data['favorites_count'] ?? 0,
      },
    };
  }

  String _formatMemberSince(dynamic createdAt) {
    if (createdAt == null) return 'Membre récent';
    try {
      final date = DateTime.parse(createdAt.toString());
      final months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
      return 'Membre depuis ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'Membre récent';
    }
  }

  /// Getter compatible avec la vue qui attend 'userProfile'
  RxMap<String, dynamic> get userProfile => profile;

  String get displayName => profile['name'] ?? 'Utilisateur';
  String get email => profile['email'] ?? '';
  String get phone => profile['phone'] ?? '';
  String get avatar => profile['avatar'] ?? '';
  String get memberSince => profile['memberSince'] ?? '';
  String get role => profile['role'] ?? 'client';
  String get address => profile['location'] ?? '';

  /// Check if user is a vendor based on profile data
  bool get isVendor {
    final roles = profile['roles'];
    if (roles is List && roles.isNotEmpty) {
      return roles.contains('vendor') || roles.contains('vendeur');
    }
    // Fallback to role column
    final userRole = profile['role'] ?? 'client';
    return userRole == 'vendor' || userRole == 'vendeur';
  }

  void editProfile() {
    try {
      Get.toNamed(Routes.COMPLETE_PROFILE);
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible d\'ouvrir l\'éditeur de profil',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void goToMyProducts() {
    Get.toNamed(Routes.PRODUCT_MANAGEMENT);
  }

  void goToBecomeVendor() {
    Get.toNamed(Routes.VENDOR_CONFIG);
  }

  void goToFavorites() {
    // Protégé par le UI - ne devrait pas être appelé en mode invité
    if (StorageService.isAuthenticated) {
      Get.toNamed(Routes.FAVORITES);
    }
  }

  void goToOrders() {
    Get.toNamed(Routes.MY_ORDER);
  }

  void goToAddresses() {
    // TODO
  }

  void goToPaymentMethods() {
    // TODO
  }

  void goToSettings() {
    // Protégé par le UI - ne devrait pas être appelé en mode invité
    if (StorageService.isAuthenticated) {
      Get.toNamed(Routes.SETTINGS);
    }
  }

  void goToHelp() {
    Get.toNamed(Routes.HELP);
  }

  void goToAbout() {
    // TODO
  }

  Future<void> logout() async {
    try {
      await AuthService.logout();
    } catch (e) {
      // Even if API fails, clear local data
      ApiProvider.clearAuth();
    }
    Get.offAllNamed(Routes.WELCOMER);
  }
}
