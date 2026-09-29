import 'package:asso/app/routes/app_pages.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/media_helper.dart';
import '../models/store_models.dart';
import '../../../data/providers/shop_service.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/vendor_service.dart';
import '../../../data/providers/vendor_product_service.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/location_label.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/free_delivery_widgets.dart';

class StoreManagementController extends GetxController {
  // État de chargement
  final RxBool isLoading = false.obs;

  // Enregistrement du formulaire « Modifier la boutique » en cours
  final RxBool isSaving = false.obs;

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

  // Livraison gratuite sur toute la boutique (financée par le vendeur).
  final freeDelivery = false.obs;
  final isSavingFreeDelivery = false.obs;

  // Logo en cours d'envoi depuis « Ma boutique »
  final RxBool isUploadingLogo = false.obs;

  // Location change requests
  final RxBool hasLocationUpdatePending = false.obs;

  /// Demande de changement d'emplacement en attente de validation par ASSO.
  final pendingLocationRequest = Rxn<Map<String, dynamic>>();

  /// Dernière demande, quand elle a été refusée (motif affiché au vendeur).
  final rejectedLocationRequest = Rxn<Map<String, dynamic>>();
  final isRequestingLocation = false.obs;

  /// Boutique déjà placée : son emplacement ne change plus que par une demande
  /// validée par ASSO. Le premier placement reste libre.
  bool get isShopPlaced {
    final store = storeInfo.value;
    return store != null && (store.latitude != 0 || store.longitude != 0);
  }

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
          storeInfo.value = storeInfoFromApi(Map<String, dynamic>.from(shop));
          freeDelivery.value = readFreeDelivery(shop['free_delivery']);
          print('✅ CONTROLLER: Store info loaded: ${storeInfo.value?.name}');
          print('  └─ Categories: ${storeInfo.value?.categories.join(", ")}');
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
          // Audience cumulée (P8) ; le détail par période est sur l'écran Statistiques.
          final visitors = (stats['unique_visitors'] as num?)?.toInt() ?? 0;
          final sales = (stats['sales_count'] as num?)?.toInt() ?? 0;
          audienceStats.value = AudienceStats(
            totalViews: (stats['total_visits'] as num?)?.toInt() ?? 0,
            totalClicks: (stats['total_product_views'] as num?)?.toInt() ?? 0,
            totalOrders: (stats['total_orders'] as num?)?.toInt() ?? 0,
            conversionRate: visitors > 0 ? (sales / visitors * 100).clamp(0, 100).toDouble() : 0.0,
            dailyStats: [],
            topProducts: {},
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

        // Charger l'inventaire depuis l'API
        try {
          final inventoryResponse = await VendorProductService.getInventory(
            page: 1,
            perPage: 50,
          );

          if (inventoryResponse.success && inventoryResponse.data != null) {
            final List<dynamic> inventoryData = inventoryResponse.data!['data'] ?? [];
            inventoryEntries.value = inventoryData.map((item) {
              return InventoryEntry.fromJson({
                'id': item['id'],
                'productId': item['product_id'],
                'productName': item['product_name'],
                'type': item['type'],
                'quantity': item['quantity'],
                'date': item['date'],
                'orderId': item['order_id'],
                'notes': item['notes'],
              });
            }).toList();

            print('✅ CONTROLLER: Inventory loaded successfully');
            print('  └─ Total entries: ${inventoryEntries.length}');
          } else {
            inventoryEntries.value = [];
            print('⚠️ CONTROLLER: No inventory data');
          }
        } catch (e) {
          print('❌ CONTROLLER: Failed to load inventory: $e');
          inventoryEntries.value = [];
        }
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
        'store_management.error'.tr,
        'store_management.load_error'.trParams({'error': e.toString()}),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Écran des statistiques détaillées de la boutique
  void openStatistics() {
    Get.toNamed(Routes.SHOP_STATISTICS);
  }

  /// Convert dynamic value to double (handles both String and num)
  static double _toDouble(dynamic value) {
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
        title: 'store_management.banner.storage_title'.tr,
        description: 'store_management.banner.storage_description'.tr,
        imageUrl: '',
        type: BannerType.storage,
        actionLabel: 'store_management.banner.storage_action'.tr,
        onTap: upgradeStorage,
      ),
      PromotionalBanner(
        id: 'banner_2',
        title: 'store_management.banner.boost_title'.tr,
        description: 'store_management.banner.boost_description'.tr,
        imageUrl: '',
        type: BannerType.boost,
        actionLabel: 'store_management.banner.boost_action'.tr,
        onTap: boostProducts,
      ),
      PromotionalBanner(
        id: 'banner_3',
        title: 'store_management.banner.certification_title'.tr,
        description: 'store_management.banner.certification_description'.tr,
        imageUrl: '',
        type: BannerType.certification,
        actionLabel: 'store_management.banner.certification_action'.tr,
        onTap: requestCertification,
      ),
      PromotionalBanner(
        id: 'banner_4',
        title: 'store_management.banner.premium_title'.tr,
        description: 'store_management.banner.premium_description'.tr,
        imageUrl: '',
        type: BannerType.premium,
        actionLabel: 'store_management.banner.premium_action'.tr,
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

  /// Active ou coupe la livraison gratuite sur toute la boutique. Le
  /// changement s'affiche tout de suite et revient en arrière en cas d'échec.
  Future<void> setFreeDelivery(bool value) async {
    if (isSavingFreeDelivery.value) return;
    final previous = freeDelivery.value;
    freeDelivery.value = value;
    isSavingFreeDelivery.value = true;
    try {
      final response = await ShopService.updateFreeDelivery(value);
      if (!response.success) {
        freeDelivery.value = previous;
        Get.snackbar(
          'store_management.free_delivery.title'.tr,
          response.message,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      final overridden =
          (response.data?['overridden_products'] as num?)?.toInt() ?? 0;
      Get.snackbar(
        'store_management.free_delivery.title'.tr,
        [
          value
              ? 'store_management.free_delivery.enabled'.tr
              : 'store_management.free_delivery.disabled'.tr,
          if (overridden > 0)
            (overridden > 1
                    ? 'store_management.free_delivery.overridden_many'
                    : 'store_management.free_delivery.overridden_one')
                .trParams({'count': '$overridden'}),
        ].join(' '),
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      freeDelivery.value = previous;
      Get.snackbar(
        'store_management.free_delivery.title'.tr,
        'store_management.free_delivery.save_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isSavingFreeDelivery.value = false;
    }
  }

  /// Boutique renvoyée par l'API (`GET` ou `PUT /vendor/shop`).
  static StoreInfo storeInfoFromApi(Map<String, dynamic> shop) {
    // Nettoyer l'adresse (gérer les valeurs placeholder)
    var address = shop['address']?.toString() ?? '';
    if (address.contains('Chargement de l')) address = '';

    final categories = shop['categories'];

    return StoreInfo(
      id: shop['id']?.toString() ?? '',
      name: shop['name']?.toString() ?? '',
      logoUrl: shop['logo']?.toString(),
      description: shop['description']?.toString() ?? '',
      latitude: _toDouble(shop['latitude']),
      longitude: _toDouble(shop['longitude']),
      address: address,
      // « Quartier, Ville, Pays » calculé par le serveur.
      city: LocationLabel.fromApi(shop) ?? '',
      phone: shop['phone']?.toString() ?? '',
      categories: categories is List
          ? categories.map((category) => category.toString()).toList()
          : const [],
    );
  }

  /// Choisit une image pour le logo (picker de marque partagé, web + mobile).
  Future<XFile?> pickLogoImage() => MediaHelper.pickBrandedImage(
    title: 'store_management.logo.title'.tr,
    subtitle: 'store_management.logo.subtitle'.tr,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );

  /// Remplace le logo depuis « Ma boutique » : il est envoyé aussitôt.
  ///
  /// L'image choisie ici n'était qu'affichée (« N'oubliez pas de
  /// sauvegarder ») alors que cet écran n'a pas de bouton d'enregistrement :
  /// elle disparaissait au chargement suivant.
  Future<void> changeLogo() async {
    if (isUploadingLogo.value) return;
    final image = await pickLogoImage();
    if (image == null) return;

    isUploadingLogo.value = true;
    try {
      final response = await ShopService.updateShop(shopLogo: image);
      final shop = response.data?['shop'];
      if (response.success && shop is Map) {
        storeInfo.value = storeInfoFromApi(Map<String, dynamic>.from(shop));
        freeDelivery.value = readFreeDelivery(shop['free_delivery']);
        Get.snackbar(
          'store_management.success'.tr,
          'store_management.logo.updated'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'store_management.error'.tr,
          response.message.isNotEmpty
              ? response.message
              : 'store_management.logo.update_error'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'store_management.error'.tr,
        'store_management.logo.update_error'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    } finally {
      isUploadingLogo.value = false;
    }
  }

  /// Load location change requests
  Future<void> loadLocationRequests() async {
    try {
      final response = await ShopService.getLocationRequests();

      if (response.success && response.data != null) {
        final pendingCount = response.data!['pending_count'] as int? ?? 0;
        hasLocationUpdatePending.value = pendingCount > 0;

        // Demandes de la plus récente à la plus ancienne.
        final requests = (response.data!['requests'] as List? ?? const [])
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        pendingLocationRequest.value = requests.firstWhereOrNull(
          (r) => r['status'] == 'pending',
        );
        final latest = requests.firstOrNull;
        rejectedLocationRequest.value =
            latest != null && latest['status'] == 'rejected' ? latest : null;

        print('✅ CONTROLLER: Location requests loaded');
        print('  └─ Pending requests: $pendingCount');
      } else {
        hasLocationUpdatePending.value = false;
      }
    } catch (e) {
      print('⚠️ CONTROLLER: Failed to load location requests: $e');
      hasLocationUpdatePending.value = false;
    }
  }

  /// Déménager suppose de n'avoir aucune commande en cours : sinon le livreur
  /// irait chercher le colis à l'ancienne adresse.
  Future<bool> canMoveShop() async {
    final ordersResponse = await VendorService.checkActiveOrders();
    final count = ordersResponse.data?['active_orders_count'] as int? ?? 0;
    if (ordersResponse.success && (ordersResponse.data?['has_active_orders'] == true)) {
      Get.snackbar(
        'store_management.move.active_orders_title'.tr,
        'store_management.move.active_orders_message'.trParams({'count': '$count'}),
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return false;
    }
    return true;
  }

  /// Envoie la demande de changement d'emplacement à ASSO. L'emplacement doit
  /// être desservi par un livreur. Renvoie true une fois la demande reçue.
  Future<bool> requestLocationChange({
    required double latitude,
    required double longitude,
    required String address,
    String? city,
    String? country,
    String? reason,
  }) async {
    if (isRequestingLocation.value) return false;
    isRequestingLocation.value = true;
    try {
      await checkDeliveryAvailability(latitude, longitude);
      if (!isDeliveryAvailable.value) {
        Get.snackbar(
          'store_management.out_of_zone_title'.tr,
          'store_management.move.out_of_zone_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
        return false;
      }

      final response = await ShopService.createLocationRequest(
        latitude: latitude,
        longitude: longitude,
        address: address,
        city: city,
        country: country,
        reason: reason,
      );
      if (!response.success) {
        Get.snackbar(
          'store_management.move.request_not_sent'.tr,
          response.message.isNotEmpty
              ? response.message
              : 'store_management.move.retry_later'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return false;
      }
      await loadLocationRequests();
      return true;
    } finally {
      isRequestingLocation.value = false;
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
      deliveryAvailabilityMessage.value = 'store_management.delivery_check_error'.tr;
    } finally {
      isCheckingDeliveryAvailability.value = false;
      print('========================================');
    }
  }

  /// Sauvegarde les informations de la boutique.
  ///
  /// Renvoie `true` une fois la boutique enregistrée : c'est l'écran
  /// d'édition qui se referme alors, lui seul sait s'il est encore affiché.
  Future<bool> saveStoreInfo({
    required String name,
    String? description,
    required String address,
    required String city,
    required String phone,
    String? locationCity,
    String? locationCountry,
    double? latitude,
    double? longitude,
    List<String>? categories,
    XFile? logo,
  }) async {
    if (isSaving.value) return false;
    try {
      isSaving.value = true;

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

      // Boutique déjà placée : l'emplacement ne part pas avec le formulaire, il
      // change par une demande validée par ASSO (requestLocationChange).
      final placed = isShopPlaced;

      // Premier placement : il doit tomber dans une zone de livraison.
      if (!placed && latitude != null && longitude != null) {
        await checkDeliveryAvailability(latitude, longitude);
        if (!isDeliveryAvailable.value) {
          Get.snackbar(
            'store_management.out_of_zone_title'.tr,
            'store_management.out_of_zone_message'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppThemeSystem.errorColor,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return false;
        }
      }

      // Appel API pour sauvegarder
      print('');
      print('🌐 Calling ShopService.updateShop...');
      final response = await ShopService.updateShop(
        shopName: name,
        shopDescription: description,
        shopAddress: placed ? null : address,
        shopCity: placed ? null : locationCity,
        shopCountry: placed ? null : locationCountry,
        shopPhone: phone,
        shopLatitude: placed ? null : latitude,
        shopLongitude: placed ? null : longitude,
        shopLogo: logo,
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
        if (shop is Map) {
          storeInfo.value = storeInfoFromApi(Map<String, dynamic>.from(shop));
          freeDelivery.value = readFreeDelivery(shop['free_delivery']);

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

        final message = 'store_management.save_success'.tr;

        print('');
        print('========================================');
        print('✅ SAVE COMPLETED SUCCESSFULLY');
        print('  └─ Message: $message');
        print('========================================');

        Get.snackbar(
          'store_management.success'.tr,
          message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
        return true;
      } else {
        Get.snackbar(
          'store_management.error'.tr,
          response.message.isNotEmpty
              ? response.message
              : 'store_management.save_error'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
        return false;
      }
    } catch (e) {
      Get.snackbar(
        'store_management.error'.tr,
        'store_management.save_error_detail'.trParams({'error': e.toString()}),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  /// Améliorer le stockage
  void upgradeStorage() async {
    // Naviguer vers la page de souscription et rafraîchir les données au retour
    await Get.toNamed('/package-subscription');
    // Rafraîchir toutes les données après le retour
    await loadData();
  }

  /// Ouvre Asso Ads pour sponsoriser un article.
  void boostProducts() => Get.toNamed(Routes.BOOST);

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
      'store_management.premium.title'.tr,
      'store_management.premium.in_progress'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Voir les détails de l'inventaire
  void viewInventoryDetails(InventoryEntry entry) {
    Get.snackbar(
      'store_management.inventory.title'.tr,
      '${entry.type.label}: ${entry.productName} (${entry.quantity})',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Voir toutes les entrées d'inventaire
  void viewAllInventory() {
    Get.toNamed(Routes.INVENTORY_LIST);
  }
}
