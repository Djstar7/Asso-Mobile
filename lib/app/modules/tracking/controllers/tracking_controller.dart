import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/services/fcm_service.dart';
import '../../../core/controllers/app_config_controller.dart';
import '../../../core/utils/string_utils.dart';

class TrackingController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final RxList<Map<String, dynamic>> shipments = <Map<String, dynamic>>[].obs;
  final RxString selectedFilter = 'Tous'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;

  /// Identifiant (numéro) de la commande dont la conversation est en cours
  /// d'ouverture. Sert à afficher un indicateur de chargement sur la bonne carte.
  final RxString openingChatOrderId = ''.obs;

  final List<String> filters = ['Tous', 'En attente livreur', 'En livraison', 'Livré', 'Annulé'];

  StreamSubscription? _orderFcmSubscription;

  @override
  void onInit() {
    super.onInit();
    if (StorageService.isAuthenticated) {
      loadOrders();
      _listenToOrderNotifications();
    }
    searchController.addListener(() {
      searchQuery.value = searchController.text;
    });
  }

  @override
  void onClose() {
    _orderFcmSubscription?.cancel();
    searchController.dispose();
    super.onClose();
  }

  /// Écoute les notifications FCM de commande pour auto-refresh
  void _listenToOrderNotifications() {
    try {
      final fcmService = Get.find<FcmService>();
      _orderFcmSubscription = fcmService.orderNotificationStream.listen((data) {
        final type = data['type'] as String? ?? '';
        // Rafraîchir sur tout changement de statut commande
        if (type.startsWith('order_') || type.startsWith('delivery_')) {
          loadOrders();
        }
      });
    } catch (e) {
      // FcmService pas encore initialisé, pas grave
    }
  }

  /// Charge les commandes confirmées+ depuis l'API
  Future<void> loadOrders() async {
    isLoading.value = true;
    try {
      final response = await OrderService.getOrders(perPage: 50);

      if (response.success && response.data != null) {
        final ordersList = response.data!['orders'] as List? ?? [];
        final newShipments = ordersList
            .map((o) => _mapOrderToShipment(Map<String, dynamic>.from(o)))
            .where((s) => s != null)
            .cast<Map<String, dynamic>>()
            .toList();

        // Force update pour déclencher la réactivité
        shipments.value = [];
        shipments.value = newShipments;
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Impossible de charger les commandes',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur de connexion',
        'Impossible de rafraîchir les commandes',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Mappe une commande API vers le format shipment pour le tracking
  Map<String, dynamic>? _mapOrderToShipment(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'pending';

    // Ne montrer que les commandes qui ont avancé (pas pending = pas encore validé)
    // On garde pending aussi pour que le client voit tout
    final fmt = DateFormat('dd MMM, HH:mm', 'fr_FR');
    final fmtDate = DateFormat('dd MMM yyyy', 'fr_FR');

    final createdAt = DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now();
    final confirmedAt = order['confirmed_at'] != null ? DateTime.tryParse(order['confirmed_at']) : null;
    final shippedAt = order['shipped_at'] != null ? DateTime.tryParse(order['shipped_at']) : null;
    final deliveredAt = order['delivered_at'] != null ? DateTime.tryParse(order['delivered_at']) : null;
    final cancelledAt = order['cancelled_at'] != null ? DateTime.tryParse(order['cancelled_at']) : null;

    // Déterminer le statut display + couleur
    String displayStatus;
    int statusColor;
    switch (status) {
      case 'pending':
        displayStatus = 'En attente';
        statusColor = 0xFFF59E0B; // Orange
        break;
      case 'confirmed':
        displayStatus = 'En attente livreur';
        statusColor = 0xFF3B82F6; // Blue
        break;
      case 'preparing':
        displayStatus = 'En préparation';
        statusColor = 0xFF3B82F6; // Blue
        break;
      case 'shipped':
        displayStatus = 'En livraison';
        statusColor = 0xFF6366F1; // Indigo
        break;
      case 'delivered':
        displayStatus = 'Livré';
        statusColor = 0xFF10B981; // Green
        break;
      case 'cancelled':
        displayStatus = 'Annulé';
        statusColor = 0xFFEF4444; // Red
        break;
      default:
        displayStatus = 'En attente';
        statusColor = 0xFFF59E0B;
    }

    // Items info
    final items = order['items'] as List? ?? [];
    String productName = 'Commande';
    String productImage = '';

    // Vendeur associé à la commande (si l'API l'expose). À défaut de vendeur,
    // la conversation basculera sur le compte support ASSO (commande en gros
    // ou vendeur indisponible).
    int? sellerId;
    String sellerName = '';
    int? firstProductId;

    final orderSeller = order['seller'] as Map<String, dynamic>?;
    if (orderSeller != null) {
      sellerId = int.tryParse(orderSeller['id']?.toString() ?? '');
      sellerName = orderSeller['name']?.toString() ?? '';
    }

    if (items.isNotEmpty) {
      final firstItem = items[0] as Map<String, dynamic>;
      productName = firstItem['product_name'] ?? 'Produit';
      productImage = firstItem['product_image'] ?? '';
      firstProductId = int.tryParse(firstItem['product_id']?.toString() ?? '');

      // Fallback: certains payloads exposent le vendeur au niveau de l'item.
      if (sellerId == null) {
        sellerId = int.tryParse(firstItem['seller_id']?.toString() ?? '');
        final itemSeller = firstItem['seller'] as Map<String, dynamic>?;
        if (sellerId == null && itemSeller != null) {
          sellerId = int.tryParse(itemSeller['id']?.toString() ?? '');
        }
        if (sellerName.isEmpty && itemSeller != null) {
          sellerName = itemSeller['name']?.toString() ?? '';
        }
      }

      if (items.length > 1) {
        productName += ' +${items.length - 1} autre${items.length > 2 ? 's' : ''}';
      }
    }

    // Delivery company
    final deliveryCompany = order['delivery_company'] as Map<String, dynamic>?;
    final deliveryPerson = order['delivery_person'] as Map<String, dynamic>?;

    // Construire la timeline de tracking
    final trackingSteps = <Map<String, dynamic>>[];

    trackingSteps.add({
      'title': 'Commande passée',
      'date': fmt.format(createdAt),
      'completed': true,
    });

    if (status == 'cancelled') {
      trackingSteps.add({
        'title': 'Commande annulée',
        'date': cancelledAt != null ? fmt.format(cancelledAt) : 'Annulée',
        'completed': true,
      });
    } else {
      trackingSteps.add({
        'title': 'Validée par le vendeur',
        'date': confirmedAt != null ? fmt.format(confirmedAt) : 'En attente',
        'completed': confirmedAt != null,
      });

      trackingSteps.add({
        'title': 'En attente d\'un livreur',
        'date': confirmedAt != null && shippedAt == null
            ? 'Les livreurs ont été notifiés...'
            : (shippedAt != null ? 'Livreur trouvé' : 'En attente'),
        'completed': shippedAt != null,
      });

      trackingSteps.add({
        'title': 'Prise en charge par le livreur',
        'date': shippedAt != null
            ? '${fmt.format(shippedAt)}${deliveryPerson != null ? ' — ${deliveryPerson['name'] ?? ''}' : ''}'
            : 'En attente',
        'completed': shippedAt != null,
      });

      trackingSteps.add({
        'title': 'En cours de livraison',
        'date': shippedAt != null && deliveredAt == null ? 'En route...' : (shippedAt != null ? fmt.format(shippedAt) : 'En attente'),
        'completed': shippedAt != null,
      });

      trackingSteps.add({
        'title': 'Livrée',
        'date': deliveredAt != null ? fmt.format(deliveredAt) : 'En attente',
        'completed': deliveredAt != null,
      });
    }

    // Localisation courante
    String currentLocation;
    if (status == 'delivered') {
      currentLocation = 'Livré';
    } else if (status == 'shipped') {
      currentLocation = 'En livraison${deliveryPerson != null ? ' par ${deliveryPerson['name']}' : ''}';
    } else if (status == 'confirmed') {
      currentLocation = 'En attente d\'un livreur — les livreurs ont été notifiés';
    } else if (status == 'preparing') {
      currentLocation = 'En préparation chez le vendeur';
    } else if (status == 'cancelled') {
      currentLocation = 'Annulé';
    } else {
      currentLocation = 'En attente de validation';
    }

    final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0;

    return {
      'id': order['order_number'] ?? 'CMD-${order['id']}',
      'orderId': order['id'],
      'productName': productName,
      'productImage': productImage,
      'status': displayStatus,
      'statusColor': statusColor,
      'orderDate': fmtDate.format(createdAt),
      'estimatedDelivery': '',
      'currentLocation': currentLocation,
      'trackingSteps': trackingSteps,
      'seller': sellerName,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'firstProductId': firstProductId,
      'price': formatPrice(total),
      'deliveryAddress': order['delivery_address'] ?? '',
      'deliveryCompany': deliveryCompany?['name'] ?? '',
      'deliveryPersonName': deliveryPerson?['name'],
      'deliveryPersonPhone': deliveryPerson?['phone'],
      'confirmationCode': order['confirmation_code'],
      'canRate': order['can_rate'] == true,
      'cancelReason': order['cancel_reason'],
      'deliveredDate': deliveredAt != null ? fmtDate.format(deliveredAt) : null,
      'rawStatus': status,
    };
  }

  List<Map<String, dynamic>> get filteredShipments {
    var results = shipments.toList();

    if (selectedFilter.value != 'Tous') {
      results = results.where((s) => s['status'] == selectedFilter.value).toList();
    }

    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      results = results.where((s) {
        final id = s['id'].toString().toLowerCase();
        final name = s['productName'].toString().toLowerCase();
        return id.contains(query) || name.contains(query);
      }).toList();
    }

    return results;
  }

  void clearSearch() {
    searchController.clear();
    searchQuery.value = '';
  }

  void selectFilter(String filter) {
    selectedFilter.value = filter;
  }

  /// Ouvre (ou démarre) une conversation à propos d'une commande.
  ///
  /// - Si la commande expose un vendeur, la conversation est démarrée avec ce
  ///   vendeur (en taguant le produit lorsqu'il est disponible).
  /// - Sinon (commande en gros ou vendeur indisponible), on bascule sur le
  ///   compte support ASSO, comme le fait le module d'import.
  ///
  /// Le champ [openingChatOrderId] permet à la vue d'afficher un indicateur de
  /// chargement sur la carte concernée. La garde d'authentification doit être
  /// effectuée par l'appelant (qui dispose du BuildContext).
  Future<void> openConversationForOrder(Map<String, dynamic> shipment) async {
    final orderKey = shipment['id']?.toString() ?? '';
    // Empêche l'ouverture simultanée de plusieurs conversations.
    if (openingChatOrderId.value.isNotEmpty) return;

    openingChatOrderId.value = orderKey;
    try {
      final orderRef = shipment['id']?.toString() ?? '';
      final sellerId = shipment['sellerId'] as int?;
      final productId = shipment['firstProductId'] as int?;
      // Message pré-rempli repris par chatdetail_controller (default_message).
      final defaultMessage = 'Commande $orderRef : ';

      if (sellerId != null) {
        // ── Conversation avec le vendeur ──
        final response = await ConversationService.startConversation(
          userId: sellerId,
          productId: productId,
        );

        if (!response.success || response.data == null) {
          Get.snackbar(
            'Erreur',
            'Impossible de démarrer la conversation avec le vendeur.',
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }

        final conversation = response.data!['conversation'] ?? response.data!;
        final conversationId =
            conversation['id'] ?? conversation['conversation_id'];
        if (conversationId == null) {
          Get.snackbar('Erreur', 'Conversation indisponible.',
              snackPosition: SnackPosition.BOTTOM);
          return;
        }

        final otherUser = conversation['other_user'] as Map<String, dynamic>?;
        final sellerNameRaw = shipment['sellerName']?.toString() ?? '';
        final userName = (otherUser?['name']?.toString().isNotEmpty == true)
            ? otherUser!['name'].toString()
            : (sellerNameRaw.isNotEmpty ? sellerNameRaw : 'Vendeur');

        Get.toNamed('/chatdetail', arguments: {
          'id': conversationId.toString(),
          'name': userName,
          'avatar': StringUtils.getInitials(userName),
          'isOnline': false,
          'default_message': defaultMessage,
        });
        return;
      }

      // ── Fallback: compte support ASSO ──
      final appConfig = Get.isRegistered<AppConfigController>()
          ? Get.find<AppConfigController>()
          : Get.put(AppConfigController(), permanent: true);
      final supportUserId = await appConfig.ensureSupportUserId();

      if (supportUserId == null) {
        Get.snackbar(
          'Support indisponible',
          "Le service d'assistance n'est pas disponible pour le moment. Réessayez plus tard.",
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final response =
          await ConversationService.startConversation(userId: supportUserId);
      if (!response.success || response.data == null) {
        Get.snackbar(
          'Erreur',
          'Impossible de démarrer la conversation avec le support.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final conversation = response.data!['conversation'];
      final conversationId = conversation?['id'];
      if (conversationId == null) {
        Get.snackbar('Erreur', 'Conversation indisponible.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }

      final supportName = appConfig.supportName;
      Get.toNamed('/chatdetail', arguments: {
        'id': conversationId.toString(),
        'name': supportName,
        'avatar': StringUtils.getInitials(supportName),
        'isOnline': false,
        'default_message': defaultMessage,
        'is_support': true,
      });
    } catch (e) {
      Get.snackbar('Erreur', 'Une erreur est survenue: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      openingChatOrderId.value = '';
    }
  }

  void contactSupport() {
    Get.snackbar(
      'Support',
      'Fonction de contact support en développement',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format price with user's currency
  String formatPrice(double priceInXOF, {bool showSymbol = true}) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: showSymbol);
  }

  /// Get currency symbol
  String get currencySymbol {
    if (!Get.isRegistered<CurrencyService>()) {
      return 'FCFA';
    }
    return CurrencyService.to.currencySymbol;
  }
}
