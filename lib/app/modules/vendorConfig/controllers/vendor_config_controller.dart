import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../../routes/app_pages.dart';
import '../../../data/providers/vendor_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/category_service.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/deliverer_service.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/deliverer_model.dart';
import '../../../core/utils/app_theme_system.dart';
import '../views/map_location_picker_view.dart';
import '../../profile/controllers/profile_controller.dart';

class VendorConfigController extends GetxController {
  // State management
  bool _isDisposed = false;
  bool get isSafe => !_isDisposed && isClosed == false;

  // Stepper
  final currentStep = 0.obs;

  // Step 1: Profil personnel
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  // Observable versions for reactive UI updates
  final firstNameText = ''.obs;
  final lastNameText = ''.obs;
  final emailText = ''.obs;

  final selectedGender = ''.obs;
  final genders = ['Homme', 'Femme'];

  final selectedAccountType = 'Particulier'.obs;
  final accountTypes = ['Particulier', 'Entreprise'];

  final profileImage = Rx<File?>(null);
  final isPickingProfileImage = false.obs;
  final locationPermissionGranted = false.obs;
  final userLocation = ''.obs;

  // Step 2: Configuration boutique
  final TextEditingController shopNameController = TextEditingController();
  final TextEditingController shopDescriptionController = TextEditingController();
  final TextEditingController locationSearchController = TextEditingController();

  // Observable versions for reactive UI updates
  final shopNameText = ''.obs;
  final shopDescriptionText = ''.obs;

  final shopLogo = Rx<File?>(null);
  final isPickingShopLogo = false.obs;
  final shopLocation = ''.obs;
  final shopLatitude = 0.0.obs;
  final shopLongitude = 0.0.obs;
  final isDeliveryAvailable = false.obs;
  final isCheckingDeliveryAvailability = false.obs;
  final deliveryAvailabilityMessage = ''.obs;

  // Categories
  final selectedCategories = <String>[].obs; // Category names selected
  final RxList<CategoryModel> categories = <CategoryModel>[].obs; // Full category objects from API
  final isCategoriesLoading = false.obs;
  final categoriesLoadError = ''.obs;

  // Delivery Partners (for map display)
  final RxList<DelivererModel> deliveryPartners = <DelivererModel>[].obs;
  final isLoadingDeliveryPartners = false.obs;

  // Validation
  final isLoading = false.obs;

  final ImagePicker _picker = ImagePicker();

  // Scroll controllers for each step
  final ScrollController step1ScrollController = ScrollController();
  final ScrollController step2ScrollController = ScrollController();
  final ScrollController step3ScrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();
    _requestLocationPermission();
    _loadCategories();
    _loadDeliveryPartners();
    _setupTextFieldListeners();
  }

  /// Configure les listeners sur les TextControllers pour la réactivité
  void _setupTextFieldListeners() {
    // Step 1 listeners
    firstNameController.addListener(() {
      firstNameText.value = firstNameController.text;
    });

    lastNameController.addListener(() {
      lastNameText.value = lastNameController.text;
    });

    emailController.addListener(() {
      emailText.value = emailController.text;
    });

    // Step 2 listeners
    shopNameController.addListener(() {
      shopNameText.value = shopNameController.text;
    });

    shopDescriptionController.addListener(() {
      shopDescriptionText.value = shopDescriptionController.text;
    });
  }

  /// Charge les catégories depuis l'API
  Future<void> _loadCategories() async {
    print('');
    print('========================================');
    print('📂 VENDOR CONFIG: Load Categories START');
    print('========================================');

    isCategoriesLoading.value = true;
    categoriesLoadError.value = '';

    try {
      print('🌐 VENDOR CONFIG: Fetching categories from API...');
      final loadedCategories = await CategoryService.getCategories();

      if (loadedCategories.isNotEmpty) {
        categories.value = loadedCategories;
        print('✅ VENDOR CONFIG: Categories loaded successfully');
        print('  └─ Total: ${loadedCategories.length}');
        for (var cat in loadedCategories) {
          print('  └─ ${cat.name} (${cat.productsCount ?? 0} produits)');
        }
      } else {
        print('⚠️ VENDOR CONFIG: No categories loaded, using fallback');
        // Fallback si l'API ne retourne rien
        _useFallbackCategories();
      }

      isCategoriesLoading.value = false;
      print('========================================');
    } catch (e, stackTrace) {
      print('💥 VENDOR CONFIG: Categories load failed!');
      print('  └─ Error: $e');
      print('  └─ Stack Trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));
      print('  └─ Using fallback categories');

      categoriesLoadError.value = 'Impossible de charger les catégories';
      _useFallbackCategories();
      isCategoriesLoading.value = false;
      print('========================================');
    }
  }

  /// Catégories de secours si l'API échoue
  void _useFallbackCategories() {
    categories.value = [
      CategoryModel(id: 0, name: 'Électronique', slug: 'electronique'),
      CategoryModel(id: 0, name: 'Mode & Vêtements', slug: 'mode-vetements'),
      CategoryModel(id: 0, name: 'Alimentation', slug: 'alimentation'),
      CategoryModel(id: 0, name: 'Maison & Jardin', slug: 'maison-jardin'),
      CategoryModel(id: 0, name: 'Beauté & Santé', slug: 'beaute-sante'),
      CategoryModel(id: 0, name: 'Sports & Loisirs', slug: 'sports-loisirs'),
      CategoryModel(id: 0, name: 'Automobile', slug: 'automobile'),
      CategoryModel(id: 0, name: 'Livres & Médias', slug: 'livres-medias'),
      CategoryModel(id: 0, name: 'Artisanat', slug: 'artisanat'),
      CategoryModel(id: 0, name: 'Services', slug: 'services'),
    ];
    print('  └─ Fallback: ${categories.length} categories');
  }

  /// Charge les partenaires de livraison depuis l'API
  Future<void> _loadDeliveryPartners() async {
    print('');
    print('========================================');
    print('🚚 VENDOR CONFIG: Load Delivery Partners START');
    print('========================================');

    isLoadingDeliveryPartners.value = true;

    try {
      print('🌐 VENDOR CONFIG: Fetching delivery partners from API...');
      final loadedPartners = await DelivererService.getDeliveryPartners();

      deliveryPartners.value = loadedPartners;
      print('✅ VENDOR CONFIG: Delivery partners loaded successfully');
      print('  └─ Total: ${loadedPartners.length}');
      for (var partner in loadedPartners) {
        print('  └─ ${partner.name} - ${partner.zone.name} (${partner.zone.latitude}, ${partner.zone.longitude})');
      }

      isLoadingDeliveryPartners.value = false;
      print('========================================');
    } catch (e, stackTrace) {
      print('💥 VENDOR CONFIG: Delivery partners load failed!');
      print('  └─ Error: $e');
      print('  └─ Stack Trace:');
      print(stackTrace.toString().split('\n').take(3).join('\n'));

      deliveryPartners.value = [];
      isLoadingDeliveryPartners.value = false;
      print('========================================');
    }
  }

  @override
  void onClose() {
    print('');
    print('========================================');
    print('🏪 VENDOR CONFIG CONTROLLER: Closing');
    print('========================================');

    _isDisposed = true;

    try {
      firstNameController.dispose();
      lastNameController.dispose();
      emailController.dispose();
      shopNameController.dispose();
      shopDescriptionController.dispose();
      locationSearchController.dispose();
      print('  └─ Text controllers disposed');
    } catch (e) {
      print('  └─ Error disposing text controllers: $e');
    }

    try {
      step1ScrollController.dispose();
      step2ScrollController.dispose();
      step3ScrollController.dispose();
      print('  └─ Scroll controllers disposed');
    } catch (e) {
      print('  └─ Error disposing scroll controllers: $e');
    }

    super.onClose();

    print('  └─ Controller disposed safely');
    print('========================================');
  }

  /// Demande la permission de localisation
  Future<void> _requestLocationPermission() async {
    try {
      // Vérifier d'abord le statut de la permission
      PermissionStatus status = await Permission.location.status;

      if (status.isDenied) {
        // Demander la permission
        status = await Permission.location.request();
      }

      if (status.isGranted) {
        locationPermissionGranted.value = true;
        // Obtenir la position actuelle
        await _getCurrentLocation();
      } else if (status.isPermanentlyDenied) {
        // Permission refusée de façon permanente
        locationPermissionGranted.value = false;
        Get.snackbar(
          'Permission requise',
          'Veuillez autoriser l\'accès à la localisation dans les paramètres',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      } else {
        locationPermissionGranted.value = false;
        userLocation.value = '';
      }
    } catch (e) {
      locationPermissionGranted.value = false;
      userLocation.value = '';
    }
  }

  /// Obtenir la position actuelle
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Pour l'instant, on affiche juste les coordonnées
      // Dans une vraie app, on utiliserait un service de géocodage inversé
      userLocation.value = 'Position: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

      // Simuler une adresse pour le moment
      userLocation.value = 'Douala, Cameroun';
    } catch (e) {
      userLocation.value = 'Localisation non disponible';
    }
  }

  /// Sélectionne une photo de profil
  Future<void> pickProfileImage() async {
    try {
      // Afficher le choix caméra ou galerie
      final source = await Get.bottomSheet<ImageSource>(
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Get.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titre
              Text(
                'Choisir une photo',
                style: Get.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Bouton Caméra
              ListTile(
                leading: const Icon(Icons.camera_alt, size: 30),
                title: const Text('Prendre une photo'),
                onTap: () => Get.back(result: ImageSource.camera),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(height: 8),

              // Bouton Galerie
              ListTile(
                leading: const Icon(Icons.photo_library, size: 30),
                title: const Text('Choisir depuis la galerie'),
                onTap: () => Get.back(result: ImageSource.gallery),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(height: 8),

              // Bouton Annuler
              ListTile(
                leading: const Icon(Icons.close, size: 30),
                title: const Text('Annuler'),
                onTap: () => Get.back(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
        isDismissible: true,
      );

      if (source != null) {
        isPickingProfileImage.value = true;

        try {
          final XFile? image = await _picker.pickImage(
            source: source,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );

          if (image != null) {
            print('📸 Profile image picked: ${image.path}');

            // Copier vers un emplacement permanent pour éviter la suppression du cache
            final permanentFile = await _copyToAppDirectory(
              image.path,
              'profile_${DateTime.now().millisecondsSinceEpoch}.jpg'
            );
            profileImage.value = permanentFile;

            print('✅ Profile image set successfully');
          }
        } finally {
          isPickingProfileImage.value = false;
        }
      }
    } catch (e) {
      isPickingProfileImage.value = false;
      print('❌ Error picking profile image: $e');
      Get.snackbar(
        'Erreur',
        'Impossible de sélectionner l\'image',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }

  /// Sélectionne le logo de la boutique
  Future<void> pickShopLogo() async {
    try {
      // Afficher le choix caméra ou galerie
      final source = await Get.bottomSheet<ImageSource>(
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Get.theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Titre
              Text(
                'Choisir un logo',
                style: Get.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Bouton Caméra
              ListTile(
                leading: const Icon(Icons.camera_alt, size: 30),
                title: const Text('Prendre une photo'),
                onTap: () => Get.back(result: ImageSource.camera),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(height: 8),

              // Bouton Galerie
              ListTile(
                leading: const Icon(Icons.photo_library, size: 30),
                title: const Text('Choisir depuis la galerie'),
                onTap: () => Get.back(result: ImageSource.gallery),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(height: 8),

              // Bouton Annuler
              ListTile(
                leading: const Icon(Icons.close, size: 30),
                title: const Text('Annuler'),
                onTap: () => Get.back(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
        isDismissible: true,
      );

      if (source != null) {
        isPickingShopLogo.value = true;

        try {
          final XFile? image = await _picker.pickImage(
            source: source,
            maxWidth: 512,
            maxHeight: 512,
            imageQuality: 85,
          );

          if (image != null) {
            print('📸 Shop logo picked: ${image.path}');

            // Copier vers un emplacement permanent pour éviter la suppression du cache
            final permanentFile = await _copyToAppDirectory(
              image.path,
              'shop_logo_${DateTime.now().millisecondsSinceEpoch}.jpg'
            );
            shopLogo.value = permanentFile;

            print('✅ Shop logo set successfully');
          }
        } finally {
          isPickingShopLogo.value = false;
        }
      }
    } catch (e) {
      isPickingShopLogo.value = false;
      print('❌ Error picking shop logo: $e');
      Get.snackbar(
        'Erreur',
        'Impossible de sélectionner le logo',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
      );
    }
  }

  /// Valide l'étape 1
  bool validateStep1() {
    if (firstNameController.text.trim().isEmpty) {
      Get.snackbar(
        'Champ requis',
        'Veuillez entrer votre prénom',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (lastNameController.text.trim().isEmpty) {
      Get.snackbar(
        'Champ requis',
        'Veuillez entrer votre nom',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (selectedGender.value.isEmpty) {
      Get.snackbar(
        'Champ requis',
        'Veuillez sélectionner votre genre',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (profileImage.value == null) {
      Get.snackbar(
        'Photo requise',
        'Veuillez ajouter une photo de profil',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    return true;
  }

  /// Valide l'étape 2
  bool validateStep2() {
    if (shopNameController.text.trim().isEmpty) {
      Get.snackbar(
        'Champ requis',
        'Veuillez entrer le nom de votre boutique',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (shopDescriptionController.text.trim().isEmpty) {
      Get.snackbar(
        'Champ requis',
        'Veuillez décrire votre activité',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (shopLogo.value == null) {
      Get.snackbar(
        'Logo requis',
        'Veuillez ajouter le logo de votre boutique',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    if (shopLocation.value.isEmpty) {
      Get.snackbar(
        'Emplacement requis',
        'Veuillez sélectionner l\'emplacement de votre boutique',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    // Note: We don't check isDeliveryAvailable here because shopLocation can only be filled
    // if the position was validated during selection (line 827 + line 844-846).
    // This prevents the bug where isDeliveryAvailable might be reset to false in error cases.

    if (selectedCategories.isEmpty) {
      Get.snackbar(
        'Catégorie requise',
        'Veuillez sélectionner au moins une catégorie',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    return true;
  }

  /// Passe à l'étape suivante
  void nextStep() async {
    if (currentStep.value == 0) {
      if (validateStep1()) {
        currentStep.value++;
        // Scroll to top of next step
        _scrollToTop(step2ScrollController);
      }
    } else if (currentStep.value == 1) {
      if (validateStep2()) {
        // Soumettre la configuration
        await submitVendorConfig();
        // Si la soumission réussit, passer au step 3
        currentStep.value++;
        // Scroll to top of next step
        _scrollToTop(step3ScrollController);
      }
    } else if (currentStep.value == 2) {
      // Step 3 - Rediriger vers la boutique
      navigateToShop();
    }
  }

  /// Retourne à l'étape précédente
  void previousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
      // Scroll to top of previous step
      if (currentStep.value == 0) {
        _scrollToTop(step1ScrollController);
      } else if (currentStep.value == 1) {
        _scrollToTop(step2ScrollController);
      }
    }
  }

  /// Scroll to top of a ScrollController
  void _scrollToTop(ScrollController controller) {
    // Wait for the UI to rebuild before scrolling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Toggle catégorie
  void toggleCategory(String categoryName) {
    if (selectedCategories.contains(categoryName)) {
      selectedCategories.remove(categoryName);
      print('✖️ Category unselected: $categoryName');
    } else {
      selectedCategories.add(categoryName);
      print('✔️ Category selected: $categoryName');
    }
    print('  └─ Total selected: ${selectedCategories.length}');
  }

  /// Rafraîchir les catégories
  Future<void> refreshCategories() async {
    print('🔄 VENDOR CONFIG: Refreshing categories...');
    await _loadCategories();
  }

  /// Sélectionne un emplacement sur la carte
  void selectLocation(double lat, double lng, String address) {
    shopLatitude.value = lat;
    shopLongitude.value = lng;
    shopLocation.value = address;
  }

  /// Vérifie si la livraison est disponible à une position donnée
  Future<void> checkDeliveryAvailability(double latitude, double longitude) async {
    print('');
    print('========================================');
    print('🚚 VENDOR CONFIG: Checking delivery availability');
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

      print('📥 VENDOR CONFIG: Delivery availability response received');
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
          print('✅ VENDOR CONFIG: Delivery is available');
          final nearestZone = response.data!['nearest_zone'];
          if (nearestZone != null) {
            print('  └─ Nearest zone: ${nearestZone['name']}');
            print('  └─ Distance: ${nearestZone['distance']} km');
          }
        } else {
          print('❌ VENDOR CONFIG: Delivery is NOT available');
          print('  └─ This will keep the "Finaliser" button DISABLED!');
        }
      } else {
        isDeliveryAvailable.value = false;
        deliveryAvailabilityMessage.value = response.message;

        print('⚠️ VENDOR CONFIG: API returned error');
        print('  └─ Message: ${response.message}');
      }
    } catch (e, stackTrace) {
      print('💥 VENDOR CONFIG: Exception caught during delivery check!');
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

  /// Ouvre la carte pour sélectionner la position
  Future<void> openMapPicker() async {
    print('');
    print('========================================');
    print('🗺️ VENDOR CONFIG: Opening Map Picker');
    print('========================================');
    print('  └─ Delivery Partners Available: ${deliveryPartners.length}');
    print('  └─ Is Loading Partners: ${isLoadingDeliveryPartners.value}');

    // Afficher un loader
    Get.dialog(
      WillPopScope(
        onWillPop: () async => false, // Empêcher de fermer en appuyant sur retour
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppThemeSystem.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chargement de la carte...',
                  style: Get.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isLoadingDeliveryPartners.value) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Récupération des partenaires de livraison...',
                    style: Get.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );

      // Attendre que les partenaires soient chargés si nécessaire
      if (deliveryPartners.isNotEmpty) {
        print('📋 Partners to display on map:');
        for (var partner in deliveryPartners) {
          print('  ├─ ${partner.name} (${partner.zone.name})');
          print('  │  └─ Position: (${partner.zone.latitude}, ${partner.zone.longitude})');
        }
      } else if (isLoadingDeliveryPartners.value) {
        print('⏳ Partners are still loading... waiting...');
        // Attendre que les partenaires soient chargés (max 5 secondes)
        int waitCount = 0;
        while (isLoadingDeliveryPartners.value && waitCount < 10) {
          await Future.delayed(const Duration(milliseconds: 500));
          waitCount++;
        }
        print('  └─ After wait, partners count: ${deliveryPartners.length}');
      } else {
        print('⚠️ No partners loaded and not loading!');
      }
      print('========================================');

    try {
      // Préparer la position initiale
      LatLng? initialPosition;

      // Si une position de boutique est déjà sélectionnée, l'utiliser
      if (shopLatitude.value != 0.0 && shopLongitude.value != 0.0) {
        initialPosition = LatLng(shopLatitude.value, shopLongitude.value);
      } else {
        // Sinon, essayer d'obtenir la position actuelle de l'utilisateur
        try {
          if (locationPermissionGranted.value) {
            Position position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
              ),
            );
            initialPosition = LatLng(position.latitude, position.longitude);
          }
        } catch (e) {
          // Si la position actuelle n'est pas disponible, utiliser Douala par défaut
          initialPosition = const LatLng(4.0511, 9.7679);
        }
      }

      // Fermer le loader
      Get.back();

      // Petit délai pour une transition fluide
      await Future.delayed(const Duration(milliseconds: 100));

      // Ouvrir la carte avec les partenaires de livraison
      final result = await Get.to<Map<String, dynamic>>(
        () => MapLocationPickerView(
          initialPosition: initialPosition,
          initialAddress: shopLocation.value.isEmpty ? null : shopLocation.value,
          deliveryPartners: deliveryPartners.toList(),
        ),
      );

      // Si l'utilisateur a confirmé une position
      if (result != null) {
        final latitude = result['latitude'] as double;
        final longitude = result['longitude'] as double;
        final address = result['address'] as String;

        // Afficher un loader de vérification
        Get.dialog(
          PopScope(
            canPop: false,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Get.theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Vérification de la zone de livraison...',
                      style: Get.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Veuillez patienter',
                      style: Get.textTheme.bodyMedium?.copyWith(
                        color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          barrierDismissible: false,
        );

        print('');
        print('🎯 USER SELECTED POSITION:');
        print('  ├─ Latitude: $latitude');
        print('  ├─ Longitude: $longitude');
        print('  └─ Address: $address');
        print('');
        print('🔍 Now checking delivery availability for this position...');

        // Vérifier si la livraison est disponible
        await checkDeliveryAvailability(latitude, longitude);

        // Fermer le loader
        Get.back();

        print('');
        print('📋 AFTER DELIVERY CHECK:');
        print('  ├─ isDeliveryAvailable: ${isDeliveryAvailable.value}');
        print('  └─ Will show dialog: ${!isDeliveryAvailable.value}');

        // Si la livraison n'est pas disponible, afficher le popup bloquant
        if (!isDeliveryAvailable.value) {
          print('⚠️ Showing NO DELIVERY dialog (user must choose another position)');
          await _showNoDeliveryServiceDialog();
        } else {
          print('✅ Position SAVED! Button "Finaliser" should now be enabled');

          // Validation de l'adresse avant sauvegarde
          if (address.contains('Chargement') || address.trim().isEmpty) {
            print('⚠️ WARNING: Invalid address detected: "$address"');
            Get.snackbar(
              'Adresse invalide',
              'L\'adresse n\'a pas pu être récupérée. Veuillez réessayer.',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppThemeSystem.warningColor,
              colorText: Colors.white,
            );
            return;
          }

          // Sauvegarder la position uniquement si la zone est disponible
          shopLatitude.value = latitude;
          shopLongitude.value = longitude;
          shopLocation.value = address;

          print('  └─ Address validated and saved: "$address"');
        }
      }
    } catch (e) {
      // Fermer le loader si ouvert
      if (Get.isDialogOpen == true) {
        Get.back();
      }

      Get.snackbar(
        'Erreur',
        'Impossible d\'ouvrir la carte',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Affiche un dialog bloquant informant qu'il n'y a pas de service de livraison dans la zone
  Future<void> _showNoDeliveryServiceDialog() async {
    return Get.dialog(
      PopScope(
        canPop: false, // Empêcher la fermeture par back button
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Get.theme.colorScheme.error,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Zone non desservie',
                  style: Get.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Get.theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Désolé, l\'emplacement de votre boutique est en dehors des zones de livraison disponibles.',
                style: Get.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pour créer une boutique sur Asso, vous devez choisir un emplacement dans une zone où nous avons des partenaires de livraison actifs.',
                style: Get.textTheme.bodyMedium?.copyWith(
                  color: Get.theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Get.theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Get.theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Get.theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nous travaillons pour étendre nos services à plus de zones.',
                        style: Get.textTheme.bodySmall?.copyWith(
                          color: Get.theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Bouton principal : Modifier mon emplacement
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Get.back(); // Fermer le dialog
                  openMapPicker(); // Rouvrir la carte pour choisir un autre emplacement
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Get.theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.edit_location),
                label: const Text(
                  'Modifier mon emplacement',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Bouton secondaire : Retour à l'accueil
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Get.back(); // Fermer le dialog
                  Get.offAllNamed(Routes.HOME); // Retourner au home
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Get.theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(
                    color: Get.theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.home),
                label: const Text(
                  'Retour à l\'accueil',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: false, // Empêcher la fermeture en cliquant en dehors
    );
  }

  /// Soumet la configuration vendeur
  Future<void> submitVendorConfig() async {
    print('');
    print('========================================');
    print('🏪 VENDOR CONFIG: SUBMIT START');
    print('========================================');

    isLoading.value = true;

    try {
      // Log data being sent
      print('📤 VENDOR CONFIG: Preparing data to send...');
      print('  └─ Shop Name: ${shopNameController.text.trim()}');
      print('  └─ Shop Description: ${shopDescriptionController.text.trim().isNotEmpty ? "YES" : "NO"}');
      print('  └─ Shop Address: ${shopLocation.value}');
      print('  └─ Shop Coordinates: (${shopLatitude.value}, ${shopLongitude.value})');
      print('  └─ Categories: ${selectedCategories.toList()}');
      print('  └─ First Name: ${firstNameController.text.trim()}');
      print('  └─ Last Name: ${lastNameController.text.trim()}');
      print('  └─ Gender: ${selectedGender.value}');
      print('  └─ Account Type: ${selectedAccountType.value}');
      print('  └─ Has Shop Logo: ${shopLogo.value != null}');
      print('  └─ Has Profile Image: ${profileImage.value != null}');

      print('🌐 VENDOR CONFIG: Calling API...');
      final response = await VendorService.applyVendor(
        shopName: shopNameController.text.trim(),
        shopDescription: shopDescriptionController.text.trim(),
        shopAddress: shopLocation.value,
        shopLatitude: shopLatitude.value,
        shopLongitude: shopLongitude.value,
        categories: selectedCategories.toList(),
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        gender: selectedGender.value,
        accountType: selectedAccountType.value,
        companyName: selectedAccountType.value == 'Entreprise' ? shopNameController.text.trim() : null,
        shopLogo: shopLogo.value,
        profileImage: profileImage.value,
      );

      print('📥 VENDOR CONFIG: API Response received');
      print('  └─ Success: ${response.success}');
      print('  └─ Status Code: ${response.statusCode}');
      print('  └─ Message: ${response.message}');

      if (response.success) {
        print('✅ VENDOR CONFIG: Success!');
        if (response.data != null) {
          print('  └─ Shop ID: ${response.data!['shop']?['id']}');
          print('  └─ Shop Name: ${response.data!['shop']?['name']}');
          print('  └─ User Role: ${response.data!['user']?['role']}');

          // IMPORTANT: Update user in storage with new role
          if (response.data!['user'] != null) {
            print('💾 VENDOR CONFIG: Updating user in storage...');
            try {
              final currentUser = StorageService.getUser();
              if (currentUser != null) {
                final userData = response.data!['user'];
                List<String>? roles;
                if (userData['roles'] != null) {
                  roles = List<String>.from(userData['roles'] as List);
                }

                final updatedUser = currentUser.copyWith(
                  role: userData['role'],
                  roles: roles,
                  firstName: userData['first_name'],
                  lastName: userData['last_name'],
                  gender: userData['gender'],
                  companyName: userData['company_name'],
                  avatar: userData['avatar'],
                );
                StorageService.saveUser(updatedUser);
                print('  └─ User updated in storage');
                print('  └─ Role: ${updatedUser.role}');
                print('  └─ Roles: ${updatedUser.roles}');
                print('  └─ Is Vendor: ${updatedUser.isVendor}');

                // Update ProfileController to refresh the UI
                try {
                  if (Get.isRegistered<ProfileController>()) {
                    final profileController = Get.find<ProfileController>();
                    await profileController.reloadProfile();
                    print('  └─ ProfileController reloaded');
                  }
                } catch (e) {
                  print('  └─ ⚠️ Failed to reload ProfileController: $e');
                }
              }
            } catch (e) {
              print('  └─ ⚠️ Failed to update user in storage: $e');
              // Non-blocking, continue anyway
            }
          }
        }

        Get.snackbar('Succès', 'Vous êtes maintenant vendeur !',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        isLoading.value = false;
        print('========================================');
      } else {
        print('❌ VENDOR CONFIG: Failed');
        print('  └─ Error Message: ${response.message}');

        Get.snackbar('Erreur', response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        isLoading.value = false;
        print('========================================');
      }
    } catch (e, stackTrace) {
      print('💥 VENDOR CONFIG: Exception caught!');
      print('  └─ Error: $e');
      print('  └─ Stack Trace:');
      print(stackTrace.toString().split('\n').take(5).join('\n'));

      Get.snackbar('Erreur', 'Une erreur est survenue: $e',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      isLoading.value = false;
      print('========================================');
    }
  }

  /// Navigation vers la boutique
  void navigateToShop() {
    // Naviguer vers le dashboard vendeur
    Get.offAllNamed(Routes.VENDOR_DASHBOARD);
  }

  /// Copie un fichier du cache vers le répertoire de l'application
  Future<File> _copyToAppDirectory(String sourcePath, String fileName) async {
    try {
      final sourceFile = File(sourcePath);

      // Vérifier que le fichier source existe
      if (!await sourceFile.exists()) {
        print('⚠️ Source file does not exist: $sourcePath');
        throw Exception('Source file does not exist');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final newPath = path.join(appDir.path, fileName);

      // Copier le fichier immédiatement
      final copiedFile = await sourceFile.copy(newPath);

      print('📁 File copied to permanent location:');
      print('  └─ From: $sourcePath');
      print('  └─ To: $newPath');
      print('  └─ Size: ${await copiedFile.length()} bytes');

      return copiedFile;
    } catch (e) {
      print('❌ Error copying file: $e');
      // Si la copie échoue, essayer de retourner le fichier original si il existe toujours
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        print('  └─ Returning original file as fallback');
        return sourceFile;
      }

      // Si même le fichier source n'existe pas, propager l'erreur
      rethrow;
    }
  }
}
