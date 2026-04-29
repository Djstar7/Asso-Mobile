import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/product_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../home/controllers/home_controller.dart';
import '../../chat/controllers/chat_controller.dart';

class ProductController extends GetxController {
  final RxInt currentImageIndex = 0.obs;
  final RxBool isFavorite = false.obs;

  // Pour la commande
  final RxBool withDelivery = false.obs;
  final RxBool isLoadingLocation = false.obs;
  final RxBool isLoadingPartners = false.obs;
  final RxBool isCreatingOrder = false.obs;
  final RxString currentLocation = 'Récupération de votre position...'.obs;
  final RxDouble deliveryPrice = 0.0.obs;
  final RxBool isStartingConversation = false.obs;

  // Position GPS du client
  double? clientLatitude;
  double? clientLongitude;

  // Partenaires de livraison
  final RxList<Map<String, dynamic>> deliveryPartners = <Map<String, dynamic>>[].obs;
  final Rxn<Map<String, dynamic>> selectedPartner = Rxn<Map<String, dynamic>>();

  // Produits similaires
  final RxList<Map<String, dynamic>> similarProducts = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingSimilarProducts = false.obs;

  // Stocker le productId pour le rechargement après sélection manuelle
  int? currentProductId;

  @override
  void onInit() {
    super.onInit();
    _initializeProduct();

    // Écouter les changements d'adresse de livraison pour réactualiser les partenaires
    ever(currentLocation, (location) {
      final product = Get.arguments as Map<String, dynamic>?;
      if (product != null && location.isNotEmpty && !location.contains('Récupération')) {
        final productId = product['id'] as int?;
        if (productId != null) {
          loadDeliveryPartners(productId);
        }
      }
    });
  }

  @override
  void onReady() {
    super.onReady();
    // Called after widget is built, ensure product is initialized
    _initializeProduct();
  }

  /// Initialize or update product data from arguments
  void _initializeProduct() {
    final product = Get.arguments as Map<String, dynamic>?;
    if (product != null) {
      // Reset state
      currentImageIndex.value = 0;
      withDelivery.value = false;
      deliveryPartners.clear();
      selectedPartner.value = null;
      similarProducts.clear();

      // Set favorite status
      isFavorite.value = product['is_favorite'] ?? false;

      // Stocker le productId pour le rechargement après sélection manuelle
      currentProductId = product['id'] as int?;

      // Load similar products based on category
      final categoryId = product['category']?['id'];
      final productId = product['id'];
      if (categoryId != null && productId != null) {
        loadSimilarProducts(
          categoryId: categoryId,
          currentProductId: productId,
        );
      }
    }
  }

  /// Update product data (called when navigating to a new product)
  void updateProduct(Map<String, dynamic> newProduct) {
    _initializeProduct();
  }

  /// Toggle favorite for the current product
  Future<void> toggleFavorite(int productId) async {
    try {
      // Check authentication
      if (!StorageService.isAuthenticated) {
        AuthGuard.navigateIfAuthenticated(
          Get.context!,
          '/favorites',
          featureName: 'les favoris',
          useDialog: true,
        );
        return;
      }

      final response = await ProductService.toggleFavorite(productId);

      if (response.success) {
        final newFavoriteStatus = response.data?['is_favorite'] ?? false;
        final message = response.data?['message'] ?? (newFavoriteStatus ? 'Ajouté aux favoris' : 'Retiré des favoris');

        // Update local state
        isFavorite.value = newFavoriteStatus;

        // Sync with HomeController if it exists
        try {
          if (Get.isRegistered<HomeController>()) {
            final homeController = Get.find<HomeController>();
            homeController.updateProductFavoriteStatus(productId, newFavoriteStatus);
          }
        } catch (e) {
          // HomeController not found, ignore
        }

        Get.snackbar(
          'Succès',
          message,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          backgroundColor: AppThemeSystem.successColor,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de modifier le favori',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    }
  }

  void toggleDelivery() {
    withDelivery.value = !withDelivery.value;
    if (!withDelivery.value) {
      selectedPartner.value = null;
      deliveryPrice.value = 0;
    }
  }

  /// Sélectionner un partenaire de livraison
  void selectPartner(Map<String, dynamic> partner) {
    selectedPartner.value = partner;
    deliveryPrice.value = (partner['delivery_price'] as num?)?.toDouble() ?? 0;
  }

  /// Récupérer la position GPS réelle du client
  Future<void> fetchCurrentLocation() async {
    isLoadingLocation.value = true;
    currentLocation.value = 'Récupération de votre position...';

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        isLoadingLocation.value = false;
        currentLocation.value = 'Permission GPS refusée';
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      clientLatitude = position.latitude;
      clientLongitude = position.longitude;

      // Faire du reverse geocoding pour obtenir l'adresse
      try {
        print('🔄 Reverse geocoding: ${position.latitude}, ${position.longitude}');

        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;

          // Construire une adresse lisible
          final parts = <String>[];

          if (placemark.locality != null && placemark.locality!.isNotEmpty) {
            parts.add(placemark.locality!); // Ville
          } else if (placemark.subAdministrativeArea != null && placemark.subAdministrativeArea!.isNotEmpty) {
            parts.add(placemark.subAdministrativeArea!);
          } else if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
            parts.add(placemark.administrativeArea!);
          }

          if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
            parts.add(placemark.subLocality!); // Quartier
          }

          currentLocation.value = parts.isNotEmpty
              ? parts.join(', ')
              : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

          print('✅ Adresse trouvée: ${currentLocation.value}');
          print('   Détails placemark:');
          print('   - locality: ${placemark.locality}');
          print('   - subLocality: ${placemark.subLocality}');
          print('   - administrativeArea: ${placemark.administrativeArea}');
          print('   - subAdministrativeArea: ${placemark.subAdministrativeArea}');
          print('   - country: ${placemark.country}');
        } else {
          print('⚠️ Aucun placemark trouvé, utilisation des coordonnées');
          currentLocation.value = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }
      } catch (reverseGeoError) {
        print('❌ Erreur reverse geocoding: $reverseGeoError');
        currentLocation.value = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }
    } catch (e) {
      print('❌ Erreur fetchCurrentLocation: $e');
      currentLocation.value = 'Position non disponible';
    } finally {
      isLoadingLocation.value = false;
    }
  }

  /// Extraire le nom de la ville depuis l'adresse complète
  String? _extractCityFromAddress(String address) {
    if (address.isEmpty || address.contains('Récupération') || address.contains('Position non disponible')) {
      return null;
    }

    // Format exemples: "Douala, Bonapriso" -> "Douala"
    //                  "Yaoundé - Centre Ville" -> "Yaoundé"
    //                  "Bafoussam, Quartier..." -> "Bafoussam"

    // Extraire avec des séparateurs communs
    final separators = [',', '-', '–', '|', '/'];
    for (final separator in separators) {
      if (address.contains(separator)) {
        final parts = address.split(separator);
        if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
          return parts[0].trim();
        }
      }
    }

    // Si pas de séparateur, prendre les 3 premiers mots max
    final words = address.split(' ');
    if (words.length > 3) {
      return words.take(2).join(' ');
    }

    // Retourner l'adresse si courte (moins de 30 caractères)
    if (address.length <= 30) {
      return address;
    }

    return null;
  }

  /// Charger les partenaires de livraison avec prix calculé pour un produit
  Future<void> loadDeliveryPartners(int productId) async {
    isLoadingPartners.value = true;
    deliveryPartners.clear();
    selectedPartner.value = null;
    deliveryPrice.value = 0;

    try {
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('🚚 CHARGEMENT DES PARTENAIRES DE LIVRAISON');
      print('═══════════════════════════════════════════════════════════════');

      // Extraire la ville de l'adresse de livraison
      final city = _extractCityFromAddress(currentLocation.value);

      print('📍 MA POSITION / ADRESSE DE LIVRAISON:');
      print('   Adresse complète: ${currentLocation.value}');
      print('   Ville extraite: ${city ?? "NON DÉTECTÉE"}');
      print('   Latitude: ${clientLatitude ?? "NON DÉFINIE"}');
      print('   Longitude: ${clientLongitude ?? "NON DÉFINIE"}');
      print('');

      final response = await DeliveryService.getDeliveryPartnersWithPricing(
        productId: productId,
        latitude: clientLatitude,
        longitude: clientLongitude,
        city: city,
      );

      print('📦 RÉPONSE API:');
      print('   Success: ${response.success}');
      print('   Message: ${response.message}');

      if (response.success && response.data != null) {
        final partners = response.data!['partners'] as List<dynamic>? ?? [];
        print('   Nombre de partenaires reçus: ${partners.length}');
        print('');

        if (partners.isEmpty) {
          print('⚠️ AUCUN PARTENAIRE TROUVÉ');
          print('   Raison possible: Aucun partenaire ne dessert la ville "$city"');
        } else {
          print('✅ PARTENAIRES TROUVÉS:');
          print('───────────────────────────────────────────────────────────────');
          for (var i = 0; i < partners.length; i++) {
            final partner = partners[i] as Map<String, dynamic>;
            print('   ${i + 1}. ${partner['company_name']}');
            print('      └─ Zone: ${partner['zone_name']}');
            print('      └─ Ville zone: ${partner['city'] ?? "NON DÉFINIE"}');
            print('      └─ Prix livraison: ${partner['delivery_price']} FCFA');
            print('      └─ Distance: ${partner['distance_km'] ?? "N/A"} km');
            print('      └─ Type tarification: ${partner['pricing_type']}');

            // Comparaison ville
            final partnerCity = partner['city']?.toString().toLowerCase();
            final myCity = city?.toLowerCase();
            if (partnerCity != null && myCity != null) {
              final match = partnerCity.contains(myCity) || myCity.contains(partnerCity);
              print('      └─ Correspondance ville: ${match ? "✅ OUI" : "❌ NON"} (${partnerCity} vs ${myCity})');
            }
            print('');
          }
        }

        deliveryPartners.value = partners.cast<Map<String, dynamic>>();

        print('📊 RÉSUMÉ:');
        print('   Ville recherchée: ${city ?? "AUCUNE"}');
        print('   Partenaires affichés: ${deliveryPartners.length}');
      } else {
        print('❌ ERREUR API: ${response.message}');
      }

      print('═══════════════════════════════════════════════════════════════');
      print('');
    } catch (e) {
      print('');
      print('❌ EXCEPTION lors du chargement des partenaires:');
      print('   Erreur: $e');
      print('');

      Get.snackbar(
        'Erreur',
        'Impossible de charger les partenaires de livraison',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoadingPartners.value = false;
    }
  }

  /// Créer la commande avec escrow
  Future<bool> createOrder({
    required int productId,
    required int quantity,
    required String walletProvider,
    String? notes,
  }) async {
    if (withDelivery.value && selectedPartner.value == null) {
      Get.snackbar('Erreur', 'Veuillez choisir un partenaire de livraison',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    isCreatingOrder.value = true;

    try {
      final response = await OrderService.createOrder(
        items: [
          {'product_id': productId, 'quantity': quantity},
        ],
        deliveryCompanyId: selectedPartner.value?['company_id'],
        deliveryZoneId: selectedPartner.value?['zone_id'],
        walletProvider: walletProvider,
        deliveryAddress: withDelivery.value ? currentLocation.value : null,
        deliveryLatitude: clientLatitude,
        deliveryLongitude: clientLongitude,
        notes: notes,
      );

      if (response.success) {
        return true;
      } else {
        Get.snackbar('Erreur', response.message.isNotEmpty ? response.message : 'Échec de la commande',
            snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Une erreur est survenue',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    } finally {
      isCreatingOrder.value = false;
    }
  }

  double calculateTotal(double productPrice) {
    if (withDelivery.value && selectedPartner.value != null) {
      return productPrice + deliveryPrice.value;
    }
    return productPrice;
  }

  /// Générer un message initial aléatoire concernant le produit
  String _generateInitialMessage(String productName) {
    final messages = [
      'Bonjour, cet article est-il toujours disponible ?',
      'Bonjour, je suis intéressé(e) par cet article. Est-il disponible ?',
      'Bonjour, le produit est-il encore disponible ?',
      'Bonjour, puis-je avoir plus d\'informations sur cet article ?',
      'Bonjour, ce produit est-il toujours en vente ?',
      'Bonjour, est-ce que cet article est disponible ?',
    ];

    // Choisir un message aléatoire
    final random = Random();
    return messages[random.nextInt(messages.length)];
  }

  /// Charger les produits similaires par catégorie
  Future<void> loadSimilarProducts({
    required int categoryId,
    required int currentProductId,
  }) async {
    isLoadingSimilarProducts.value = true;
    similarProducts.clear();

    try {
      final response = await ProductService.getProducts(
        categoryId: categoryId,
        perPage: 7, // Get 7 to exclude current product and keep 6
      );

      if (response.success && response.data != null) {
        final products = response.data!['products'] as List<dynamic>? ?? [];

        // Filtrer pour exclure le produit actuel
        final filtered = products
            .cast<Map<String, dynamic>>()
            .where((p) => p['id'] != currentProductId)
            .take(6)
            .toList();

        similarProducts.value = filtered;
      }
    } catch (e) {
      print('❌ Erreur lors du chargement des produits similaires: $e');
    } finally {
      isLoadingSimilarProducts.value = false;
    }
  }

  /// Ouvrir une conversation avec le vendeur concernant ce produit
  Future<void> openConversationWithSeller({
    required Map<String, dynamic> product,
  }) async {
    if (isStartingConversation.value) return;

    try {
      isStartingConversation.value = true;

      // Extraire les informations nécessaires
      final seller = product['seller'] as Map<String, dynamic>?;
      final sellerId = int.tryParse(seller?['id']?.toString() ?? '');
      final productId = int.tryParse(product['id']?.toString() ?? '');
      final productName = product['name']?.toString() ?? 'le produit';

      if (sellerId == null) {
        Get.snackbar(
          'Erreur',
          'Impossible d\'identifier le vendeur',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Démarrer ou récupérer la conversation
      final response = await ConversationService.startConversation(
        userId: sellerId,
        productId: productId,
      );

      if (response.success && response.data != null) {
        // Extraire la conversation du body
        final conversation = response.data!['conversation'] ?? response.data!;
        final conversationId = int.tryParse(
          (conversation['id'] ?? conversation['conversation_id'] ?? '').toString(),
        );

        if (conversationId != null) {
          // Envoyer automatiquement le premier message avec le produit taggué
          final initialMessage = _generateInitialMessage(productName);

          try {
            await ConversationService.sendMessage(
              conversationId,
              initialMessage,
              productId: productId, // Taguer le produit dans le message
            );
          } catch (e) {
            // Si l'envoi du message échoue, on continue quand même vers le chat
            // L'utilisateur pourra envoyer manuellement
          }
        }

        // Naviguer vers chatdetail avec les infos de conversation
        await Get.toNamed(
          '/chatdetail',
          arguments: {
            'id': conversation['id'] ?? conversation['conversation_id'] ?? '',
            'name': seller?['name'] ?? 'Vendeur',
            'avatar': seller?['avatar'] ?? 'V',
            'isOnline': false,
            'product': product,
          },
        );

        // Rafraîchir la liste des conversations après être revenu du chat
        // pour que la nouvelle conversation apparaisse instantanément
        _refreshChatList();
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Impossible de démarrer la conversation',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue lors de l\'ouverture de la conversation',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isStartingConversation.value = false;
    }
  }

  /// Rafraîchir la liste des conversations dans le ChatController
  void _refreshChatList() {
    try {
      // Essayer de trouver le ChatController et rafraîchir les conversations
      final chatController = Get.find<ChatController>();
      chatController.refreshConversations();
    } catch (e) {
      // Le ChatController n'est pas chargé, ce n'est pas grave
      // La conversation apparaîtra au prochain chargement de la page chat
    }
  }
}
