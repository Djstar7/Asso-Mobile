import 'package:asso/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/store_models.dart';
import '../../../data/providers/shop_service.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/vendor_service.dart';
import '../../../core/utils/app_theme_system.dart';

class StoreManagementController extends GetxController {
  // État de chargement
  final RxBool isLoading = false.obs;

  // Informations de la boutique
  final Rx<StoreInfo?> storeInfo = Rx<StoreInfo?>(null);

  // Vérification de zone de livraison
  final isDeliveryAvailable = false.obs;
  final isCheckingDeliveryAvailability = false.obs;
  final deliveryAvailabilityMessage = ''.obs;

  // Statistiques de stockage
  final Rx<StorageStats?> storageStats = Rx<StorageStats?>(null);

  // Certification
  final Rx<Certification?> certification = Rx<Certification?>(null);

  // Statistiques d'audience
  final Rx<AudienceStats?> audienceStats = Rx<AudienceStats?>(null);

  // Inventaire
  final RxList<InventoryEntry> inventoryEntries = <InventoryEntry>[].obs;
  final Rx<InventoryType?> selectedInventoryFilter = Rx<InventoryType?>(null);

  // Bannières promotionnelles
  final RxList<PromotionalBanner> banners = <PromotionalBanner>[].obs;
  final RxInt currentBannerIndex = 0.obs;

  // Image picker
  final ImagePicker _picker = ImagePicker();
  final Rx<File?> selectedLogo = Rx<File?>(null);

  // Location change requests
  final RxList<dynamic> locationRequests = <dynamic>[].obs;
  final RxBool hasLocationUpdatePending = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadData();
    loadLocationRequests();
    _setupBanners();
  }

  /// Charge toutes les données
  Future<void> loadData() async {
    isLoading.value = true;
    try {
      // Essayer de charger depuis l'API shop dédiée
      final response = await ShopService.getShop();

      print('📊 CONTROLLER: Response success: ${response.success}');
      print('📊 CONTROLLER: Response data: ${response.data}');

      if (response.success && response.data != null) {
        final data = response.data!;
        final shop = data['shop'];
        final stats = data['stats'];
        final certificationData = data['certification'];
        final package = data['package'];

        print('📊 CONTROLLER: Shop data: $shop');
        print('📊 CONTROLLER: Stats data: $stats');
        print('📊 CONTROLLER: Certification data: $certificationData');
        print('📊 CONTROLLER: Package data: $package');

        // Parser les informations de la boutique
        if (shop != null) {
          // Nettoyer l'adresse (gérer les valeurs placeholder)
          String? address = shop['address']?.toString();
          if (address != null &&
              (address.contains('Chargement de l') || address.isEmpty)) {
            address = '';
          }

          // Extraire la ville de l'adresse si présente
          String city = '';
          if (address != null && address.isNotEmpty && address.contains(',')) {
            city = address.split(',').last.trim();
          }

          // Parser les catégories
          List<String> categories = [];
          if (shop['categories'] != null) {
            if (shop['categories'] is List) {
              categories = List<String>.from(shop['categories'] as List);
            }
          }

          storeInfo.value = StoreInfo(
            id: shop['id']?.toString() ?? '',
            name: shop['name'] ?? '',
            logoUrl: shop['logo'],
            description: shop['description'] ?? '',
            latitude: _toDouble(shop['latitude']),
            longitude: _toDouble(shop['longitude']),
            address: address ?? '',
            city: city,
            phone: shop['phone'] ?? '',
            categories: categories,
          );
          print('✅ CONTROLLER: Store info loaded: ${storeInfo.value?.name}');
          print('  └─ Categories: ${categories.join(", ")}');
        } else {
          print('⚠️ CONTROLLER: No shop data');
          storeInfo.value = null;
        }

        // Parser les statistiques depuis stats et package
        if (stats != null) {
          final totalProducts = stats['total_products'] ?? 0;

          // Parser les stats de stockage depuis le package
          final storageUsedGB = package != null
              ? _toDouble(package['storage_used_gb'])
              : 0.0;
          final storageTotalGB = package != null
              ? _toDouble(package['storage_total_gb'])
              : 0.0;

          storageStats.value = StorageStats(
            usedSpaceGB: storageUsedGB,
            totalSpaceGB: storageTotalGB,
            totalProducts: totalProducts,
            totalImages: 0, // TODO: À calculer depuis les produits
          );
          print('✅ CONTROLLER: Storage stats loaded');

          // Parser les statistiques d'audience depuis stats
          audienceStats.value = AudienceStats(
            totalViews: 0, // TODO: À implémenter dans le backend
            totalClicks: 0, // TODO: À implémenter dans le backend
            totalOrders: stats['total_orders'] ?? 0,
            conversionRate: 0.0, // TODO: À calculer
            dailyStats: [], // TODO: À implémenter dans le backend
            topProducts: {}, // TODO: À implémenter dans le backend
          );
          print('✅ CONTROLLER: Audience stats loaded');
        } else {
          print('⚠️ CONTROLLER: No stats data');
          storageStats.value = null;
          audienceStats.value = null;
        }

        // Parser la certification depuis certificationData (séparé de la vérification)
        if (certificationData != null) {
          final isCertified = certificationData['is_certified'] ?? false;
          final expiresAt = certificationData['certification_expires_at'];

          certification.value = Certification(
            isCertified: isCertified,
            status: isCertified
                ? CertificationStatus.certified
                : CertificationStatus.notCertified,
            expiryDate: expiresAt != null ? DateTime.parse(expiresAt) : null,
          );
          print(
            '✅ CONTROLLER: Certification loaded (isCertified: $isCertified)',
          );
        } else {
          print('⚠️ CONTROLLER: No certification data');
          certification.value = Certification(
            isCertified: false,
            status: CertificationStatus.notCertified,
          );
        }

        // Inventaire vide pour l'instant (TODO: implémenter l'API backend)
        inventoryEntries.value = [];
        print(
          '✅ CONTROLLER: Inventory loaded (empty - waiting for backend implementation)',
        );
      } else {
        print('❌ CONTROLLER: API call failed');
        // Clear all data
        storeInfo.value = null;
        storageStats.value = null;
        audienceStats.value = null;
        certification.value = null;
        inventoryEntries.value = [];
      }
    } catch (e, stackTrace) {
      print('💥 CONTROLLER: Exception occurred!');
      print('  └─ Error: $e');
      print('  └─ Stack trace:');
      print(stackTrace.toString().split('\n').take(5).join('\n'));

      // Clear all data on error
      storeInfo.value = null;
      storageStats.value = null;
      audienceStats.value = null;
      certification.value = null;
      inventoryEntries.value = [];

      Get.snackbar(
        'Erreur',
        'Impossible de charger les données: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Convert dynamic value to double (handles both String and num)
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Configure les bannières promotionnelles
  void _setupBanners() {
    banners.value = [
      PromotionalBanner(
        id: 'banner_1',
        title: 'Augmentez votre espace',
        description: 'Passez à 50 GB de stockage',
        imageUrl: '',
        type: BannerType.storage,
        actionLabel: 'Voir les offres',
        onTap: upgradeStorage,
      ),
      PromotionalBanner(
        id: 'banner_2',
        title: 'Boostez vos produits',
        description: 'Augmentez votre visibilité de 300%',
        imageUrl: '',
        type: BannerType.boost,
        actionLabel: 'Booster maintenant',
        onTap: boostProducts,
      ),
      PromotionalBanner(
        id: 'banner_3',
        title: 'Devenez certifié',
        description: 'Gagnez la confiance des clients',
        imageUrl: '',
        type: BannerType.certification,
        actionLabel: 'Demander certification',
        onTap: requestCertification,
      ),
      PromotionalBanner(
        id: 'banner_4',
        title: 'Passez Premium',
        description: 'Accédez à toutes les fonctionnalités',
        imageUrl: '',
        type: BannerType.premium,
        actionLabel: 'Découvrir',
        onTap: upgradeToPremium,
      ),
    ];
  }

  /// Filtre l'inventaire
  List<InventoryEntry> get filteredInventory {
    if (selectedInventoryFilter.value == null) {
      return inventoryEntries;
    }
    return inventoryEntries
        .where((entry) => entry.type == selectedInventoryFilter.value)
        .toList();
  }

  /// Sélectionne une image pour le logo
  Future<void> pickLogo() async {
    // Show bottom sheet to choose source
    final ImageSource? source = await Get.bottomSheet<ImageSource>(
      Container(
        decoration: BoxDecoration(
          color: Get.theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choisir une source',
                style: Get.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: AppThemeSystem.primaryColor,
                  ),
                ),
                title: const Text('Galerie'),
                subtitle: const Text('Choisir une photo existante'),
                onTap: () => Get.back(result: ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: AppThemeSystem.primaryColor,
                  ),
                ),
                title: const Text('Caméra'),
                subtitle: const Text('Prendre une nouvelle photo'),
                onTap: () => Get.back(result: ImageSource.camera),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      isDismissible: true,
      enableDrag: true,
    );

    if (source == null) return;

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        selectedLogo.value = File(image.path);
        Get.snackbar(
          'Succès',
          'Logo sélectionné. N\'oubliez pas de sauvegarder.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.successColor,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de sélectionner l\'image',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    }
  }

  /// Load location change requests
  Future<void> loadLocationRequests() async {
    try {
      final response = await ShopService.getLocationRequests();

      if (response.success && response.data != null) {
        locationRequests.value = response.data!['requests'] as List? ?? [];
        final pendingCount = response.data!['pending_count'] as int? ?? 0;
        hasLocationUpdatePending.value = pendingCount > 0;

        print('✅ CONTROLLER: Location requests loaded');
        print('  ├─ Total requests: ${locationRequests.length}');
        print('  └─ Pending requests: $pendingCount');
      } else {
        locationRequests.value = [];
        hasLocationUpdatePending.value = false;
      }
    } catch (e) {
      print('⚠️ CONTROLLER: Failed to load location requests: $e');
      locationRequests.value = [];
      hasLocationUpdatePending.value = false;
    }
  }

  /// Vérifie si la livraison est disponible à une position donnée
  Future<void> checkDeliveryAvailability(double latitude, double longitude) async {
    print('');
    print('========================================');
    print('🚚 STORE MANAGEMENT: Checking delivery availability');
    print('========================================');
    print('  └─ Latitude: $latitude');
    print('  └─ Longitude: $longitude');

    isCheckingDeliveryAvailability.value = true;
    deliveryAvailabilityMessage.value = '';

    try {
      final response = await DeliveryService.checkDeliveryAvailability(
        latitude: latitude,
        longitude: longitude,
      );

      print('📥 STORE MANAGEMENT: Delivery availability response received');
      print('  └─ Success: ${response.success}');
      print('  └─ Status Code: ${response.statusCode}');
      print('  └─ Message: ${response.message}');

      if (response.success && response.data != null) {
        final available = response.data!['available'] as bool? ?? false;
        final message = response.data!['message'] as String? ?? '';

        isDeliveryAvailable.value = available;
        deliveryAvailabilityMessage.value = message;

        print('');
        print('🔔 DELIVERY AVAILABILITY RESULT:');
        print('  ├─ Available: $available');
        print('  ├─ Message: $message');
        print('  └─ isDeliveryAvailable.value is now: ${isDeliveryAvailable.value}');

        if (available) {
          print('✅ STORE MANAGEMENT: Delivery is available');
        } else {
          print('❌ STORE MANAGEMENT: Delivery is NOT available');
        }
      } else {
        isDeliveryAvailable.value = false;
        deliveryAvailabilityMessage.value = response.message;

        print('⚠️ STORE MANAGEMENT: API returned error');
        print('  └─ Message: ${response.message}');
      }
    } catch (e, stackTrace) {
      print('💥 STORE MANAGEMENT: Exception caught during delivery check!');
      print('  └─ Error: $e');
      print('  └─ Stack Trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));

      isDeliveryAvailable.value = false;
      deliveryAvailabilityMessage.value = 'Erreur lors de la vérification';
    } finally {
      isCheckingDeliveryAvailability.value = false;
      print('========================================');
    }
  }

  /// Sauvegarde les informations de la boutique
  Future<void> saveStoreInfo({
    required String name,
    String? description,
    required String address,
    required String city,
    required String phone,
    double? latitude,
    double? longitude,
    List<String>? categories,
  }) async {
    try {
      isLoading.value = true;

      print('');
      print('========================================');
      print('💾 STORE MANAGEMENT: SAVE STORE INFO START');
      print('========================================');
      print('📝 Data to save:');
      print('  ├─ Name: $name');
      print('  ├─ Description: $description');
      print('  ├─ Address: $address');
      print('  ├─ Phone: $phone');
      print('  ├─ Latitude: $latitude');
      print('  ├─ Longitude: $longitude');
      print('  ├─ Categories: $categories');
      print('  └─ City: $city');

      print('');
      print('📊 Current store info BEFORE save:');
      print('  ├─ Name: ${storeInfo.value?.name}');
      print('  ├─ Description: ${storeInfo.value?.description}');
      print('  ├─ Address: ${storeInfo.value?.address}');
      print('  ├─ Phone: ${storeInfo.value?.phone}');
      print('  ├─ Latitude: ${storeInfo.value?.latitude}');
      print('  ├─ Longitude: ${storeInfo.value?.longitude}');
      print('  └─ Categories: ${storeInfo.value?.categories}');

      // Vérifier si la position a changé
      final oldLat = storeInfo.value?.latitude ?? 0.0;
      final oldLng = storeInfo.value?.longitude ?? 0.0;
      final newLat = latitude ?? oldLat;
      final newLng = longitude ?? oldLng;

      final hasLocationChanged = (newLat - oldLat).abs() > 0.0001 || (newLng - oldLng).abs() > 0.0001;

      print('');
      print('========================================');
      print('📍 STORE MANAGEMENT: Checking location change');
      print('  ├─ Old position: ($oldLat, $oldLng)');
      print('  ├─ New position: ($newLat, $newLng)');
      print('  └─ Location changed: $hasLocationChanged');
      print('========================================');

      if (hasLocationChanged) {
        // 1. Vérifier qu'il n'y a pas de commandes en cours
        print('📦 Checking active orders...');
        final ordersResponse = await VendorService.checkActiveOrders();

        if (ordersResponse.success && ordersResponse.data != null) {
          final hasActiveOrders = ordersResponse.data!['has_active_orders'] as bool? ?? false;
          final activeOrdersCount = ordersResponse.data!['active_orders_count'] as int? ?? 0;

          if (hasActiveOrders) {
            Get.snackbar(
              'Commandes en cours',
              'Vous avez $activeOrdersCount commande(s) en cours. Veuillez les terminer avant de modifier votre emplacement.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppThemeSystem.warningColor,
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );
            return;
          }
          print('✅ No active orders');
        }

        // 2. Vérifier que la nouvelle position est dans une zone de livraison
        print('🚚 Checking delivery availability...');
        await checkDeliveryAvailability(newLat, newLng);

        if (!isDeliveryAvailable.value) {
          Get.snackbar(
            'Hors zone de livraison',
            'La nouvelle position est en dehors des zones de livraison disponibles. Veuillez choisir un emplacement dans une zone desservie.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppThemeSystem.errorColor,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return;
        }
        print('✅ Delivery available at new location');
      }

      // Appel API pour sauvegarder
      print('');
      print('🌐 Calling ShopService.updateShop...');
      final response = await ShopService.updateShop(
        shopName: name,
        shopDescription: description,
        shopAddress: address,
        shopPhone: phone,
        shopLatitude: latitude ?? storeInfo.value?.latitude,
        shopLongitude: longitude ?? storeInfo.value?.longitude,
        shopLogo: selectedLogo.value,
        categories: categories,
      );

      print('');
      print('📥 Response received from API:');
      print('  ├─ Success: ${response.success}');
      print('  ├─ Status Code: ${response.statusCode}');
      print('  ├─ Message: ${response.message}');
      print('  └─ Data: ${response.data}');

      if (response.success && response.data != null) {
        print('');
        print('✅ API call successful, processing response data...');
        // Mettre à jour directement avec les données de la réponse
        final shop = response.data!['shop'];
        if (shop != null) {
          // Nettoyer l'adresse (gérer les valeurs placeholder)
          String? updatedAddress = shop['address']?.toString();
          if (updatedAddress != null &&
              (updatedAddress.contains('Chargement de l') || updatedAddress.isEmpty)) {
            updatedAddress = '';
          }

          // Extraire la ville de l'adresse si présente
          String updatedCity = '';
          if (updatedAddress != null && updatedAddress.isNotEmpty && updatedAddress.contains(',')) {
            updatedCity = updatedAddress.split(',').last.trim();
          }

          // Parser les catégories
          List<String> updatedCategories = [];
          if (shop['categories'] != null) {
            if (shop['categories'] is List) {
              updatedCategories = List<String>.from(shop['categories'] as List);
            }
          }

          print('');
          print('🔄 Updating storeInfo from API response...');
          print('  ├─ ID: ${shop['id']}');
          print('  ├─ Name: ${shop['name']}');
          print('  ├─ Description: ${shop['description']}');
          print('  ├─ Address: $updatedAddress');
          print('  ├─ Phone: ${shop['phone']}');
          print('  ├─ Latitude: ${shop['latitude']}');
          print('  ├─ Longitude: ${shop['longitude']}');
          print('  └─ Categories: $updatedCategories');

          storeInfo.value = StoreInfo(
            id: shop['id']?.toString() ?? '',
            name: shop['name'] ?? '',
            logoUrl: shop['logo'],
            description: shop['description'] ?? '',
            latitude: _toDouble(shop['latitude']),
            longitude: _toDouble(shop['longitude']),
            address: updatedAddress ?? '',
            city: updatedCity,
            phone: shop['phone'] ?? '',
            categories: updatedCategories,
          );

          print('');
          print('✅ CONTROLLER: Store info updated from API response');
          print('📊 New storeInfo.value:');
          print('  ├─ Name: ${storeInfo.value?.name}');
          print('  ├─ Description: ${storeInfo.value?.description}');
          print('  ├─ Address: ${storeInfo.value?.address}');
          print('  ├─ Phone: ${storeInfo.value?.phone}');
          print('  ├─ Latitude: ${storeInfo.value?.latitude}');
          print('  ├─ Longitude: ${storeInfo.value?.longitude}');
          print('  └─ Categories: ${storeInfo.value?.categories}');
        }

        // Réinitialiser le logo sélectionné
        selectedLogo.value = null;

        // Reload location requests to check for new pending requests
        print('');
        print('🔄 Reloading location requests...');
        await loadLocationRequests();

        Get.back(); // Fermer le formulaire d'édition

        // Determine success message based on whether location request was created
        final hasLocationRequest = response.data!['location_request'] != null;
        final message = hasLocationRequest
            ? 'Informations mises à jour. Votre demande de changement de localisation sera validée par un administrateur.'
            : 'Informations de la boutique mises à jour avec succès';

        print('');
        print('========================================');
        print('✅ SAVE COMPLETED SUCCESSFULLY');
        print('  ├─ Location request created: $hasLocationRequest');
        print('  └─ Message: $message');
        print('========================================');

        Get.snackbar(
          'Succès',
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty
              ? response.message
              : 'Impossible de sauvegarder les informations',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de sauvegarder les informations: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Améliorer le stockage
  void upgradeStorage() async {
    // Naviguer vers la page de souscription et rafraîchir les données au retour
    await Get.toNamed('/package-subscription');
    // Rafraîchir toutes les données après le retour
    await loadData();
  }

  /// Booster les produits
  void boostProducts() {
    Get.snackbar(
      'Boost',
      'Fonctionnalité de boost en cours de développement',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Demander la certification
  void requestCertification() async {
    // Navigate to certification packages page
    await Get.toNamed('/certification-packages');
    // Reload data when user returns to refresh certification status
    await loadData();
  }

  /// Passer en premium
  void upgradeToPremium() {
    Get.snackbar(
      'Premium',
      'Upgrade premium en cours de développement',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Voir les détails de l'inventaire
  void viewInventoryDetails(InventoryEntry entry) {
    Get.snackbar(
      'Inventaire',
      '${entry.type.label}: ${entry.productName} (${entry.quantity})',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Voir toutes les entrées d'inventaire
  void viewAllInventory() {
    Get.toNamed(Routes.INVENTORY_LIST);
  }
}
