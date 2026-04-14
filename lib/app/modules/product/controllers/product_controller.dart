import 'dart:math';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/order_service.dart';

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

  void toggleFavorite() {
    isFavorite.value = !isFavorite.value;
    Get.snackbar(
      isFavorite.value ? 'Ajouté aux favoris' : 'Retiré des favoris',
      isFavorite.value
          ? 'Ce produit a été ajouté à vos favoris'
          : 'Ce produit a été retiré de vos favoris',
      snackPosition: SnackPosition.BOTTOM,
    );
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
      currentLocation.value = '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (e) {
      currentLocation.value = 'Position non disponible';
    } finally {
      isLoadingLocation.value = false;
    }
  }

  /// Charger les partenaires de livraison avec prix calculé pour un produit
  Future<void> loadDeliveryPartners(int productId) async {
    isLoadingPartners.value = true;
    deliveryPartners.clear();
    selectedPartner.value = null;
    deliveryPrice.value = 0;

    try {
      final response = await DeliveryService.getDeliveryPartnersWithPricing(
        productId: productId,
        latitude: clientLatitude,
        longitude: clientLongitude,
      );

      if (response.success && response.data != null) {
        final partners = response.data!['partners'] as List<dynamic>? ?? [];
        deliveryPartners.value = partners.cast<Map<String, dynamic>>();
      }
    } catch (e) {
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
        Get.toNamed(
          '/chatdetail',
          arguments: {
            'id': conversation['id'] ?? conversation['conversation_id'] ?? '',
            'name': seller?['name'] ?? 'Vendeur',
            'avatar': seller?['avatar'] ?? 'V',
            'isOnline': false,
            'product': product,
          },
        );
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
}
