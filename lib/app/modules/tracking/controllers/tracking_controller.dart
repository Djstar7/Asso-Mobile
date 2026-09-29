import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_design.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/services/fcm_service.dart';
import '../../../core/controllers/app_config_controller.dart';
import '../../../core/utils/string_utils.dart';
import '../../../data/models/delivery_info.dart';

class TrackingController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final RxList<Map<String, dynamic>> shipments = <Map<String, dynamic>>[].obs;
  final RxString selectedFilter = 'tracking.filters.all'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;

  /// Identifiant (numéro) de la commande dont la conversation est en cours
  /// d'ouverture. Sert à afficher un indicateur de chargement sur la bonne carte.
  final RxString openingChatOrderId = ''.obs;

  // Clés de traduction : l'affichage passe par .tr, le filtrage compare statusKey.
  final List<String> filters = [
    'tracking.filters.all',
    'tracking.status.awaiting_courier',
    'tracking.status.shipped',
    'tracking.status.delivered',
    'tracking.status.cancelled',
  ];

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
          'tracking.errors.error'.tr,
          response.message.isNotEmpty ? response.message : 'tracking.errors.load_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      Get.snackbar(
        'tracking.errors.connection'.tr,
        'tracking.errors.refresh_failed'.tr,
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
    final fmt = DateFormat('dd MMM, HH:mm');
    final fmtDate = DateFormat('dd MMM yyyy');

    final createdAt = DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now();
    final confirmedAt = order['confirmed_at'] != null ? DateTime.tryParse(order['confirmed_at']) : null;
    final shippedAt = order['shipped_at'] != null ? DateTime.tryParse(order['shipped_at']) : null;
    final deliveredAt = order['delivered_at'] != null ? DateTime.tryParse(order['delivered_at']) : null;
    final cancelledAt = order['cancelled_at'] != null ? DateTime.tryParse(order['cancelled_at']) : null;

    // Déterminer le statut display + couleur
    String displayStatus;
    String statusKey;
    int statusColor;
    // Couleurs prises aux tokens sémantiques : la palette écrite en dur ici
    // introduisait un second orange, concurrent de l'accent de marque.
    switch (status) {
      case 'pending':
        statusKey = 'tracking.status.pending';
        displayStatus = statusKey.tr;
        statusColor = AppDesign.warning.toARGB32();
        break;
      case 'confirmed':
        statusKey = 'tracking.status.awaiting_courier';
        displayStatus = statusKey.tr;
        statusColor = AppDesign.info.toARGB32();
        break;
      case 'preparing':
        statusKey = 'tracking.status.preparing';
        displayStatus = statusKey.tr;
        statusColor = AppDesign.info.toARGB32();
        break;
      case 'shipped':
        statusKey = 'tracking.status.shipped';
        displayStatus = statusKey.tr;
        statusColor = AppDesign.accent.toARGB32();
        break;
      case 'delivered':
        statusKey = 'tracking.status.delivered';
        displayStatus = statusKey.tr;
        statusColor = AppDesign.success.toARGB32();
        break;
      case 'cancelled':
        statusKey = 'tracking.status.cancelled';
        displayStatus = statusKey.tr;
        statusColor = AppDesign.danger.toARGB32();
        break;
      default:
        statusKey = 'tracking.status.pending';
        displayStatus = statusKey.tr;
        statusColor = AppDesign.warning.toARGB32();
    }

    // Items info
    final items = order['items'] as List? ?? [];
    String productName = 'tracking.order'.tr;
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
      productName = firstItem['product_name'] ?? 'tracking.product'.tr;
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
        productName += (items.length > 2 ? 'tracking.more_items_many' : 'tracking.more_items_one')
            .trParams({'count': '${items.length - 1}'});
      }
    }

    // Delivery company
    final deliveryCompany = order['delivery_company'] as Map<String, dynamic>?;
    final deliveryPerson = order['delivery_person'] as Map<String, dynamic>?;

    // Construire la timeline de tracking
    final trackingSteps = <Map<String, dynamic>>[];

    trackingSteps.add({
      'title': 'tracking.steps.placed'.tr,
      'date': fmt.format(createdAt),
      'completed': true,
    });

    if (status == 'cancelled') {
      trackingSteps.add({
        'title': 'tracking.steps.cancelled'.tr,
        'date': cancelledAt != null ? fmt.format(cancelledAt) : 'tracking.steps.cancelled_date'.tr,
        'completed': true,
      });
    } else {
      trackingSteps.add({
        'title': 'tracking.steps.confirmed'.tr,
        'date': confirmedAt != null ? fmt.format(confirmedAt) : 'tracking.steps.pending'.tr,
        'completed': confirmedAt != null,
      });

      trackingSteps.add({
        'title': 'tracking.steps.awaiting_courier'.tr,
        'date': confirmedAt != null && shippedAt == null
            ? 'tracking.steps.couriers_notified'.tr
            : (shippedAt != null ? 'tracking.steps.courier_found'.tr : 'tracking.steps.pending'.tr),
        'completed': shippedAt != null,
      });

      trackingSteps.add({
        'title': 'tracking.steps.picked_up'.tr,
        'date': shippedAt != null
            ? '${fmt.format(shippedAt)}${deliveryPerson != null ? ' — ${deliveryPerson['name'] ?? ''}' : ''}'
            : 'tracking.steps.pending'.tr,
        'completed': shippedAt != null,
      });

      trackingSteps.add({
        'title': 'tracking.steps.in_transit'.tr,
        'date': shippedAt != null && deliveredAt == null ? 'tracking.steps.en_route'.tr : (shippedAt != null ? fmt.format(shippedAt) : 'tracking.steps.pending'.tr),
        'completed': shippedAt != null,
      });

      trackingSteps.add({
        'title': 'tracking.steps.delivered'.tr,
        'date': deliveredAt != null ? fmt.format(deliveredAt) : 'tracking.steps.pending'.tr,
        'completed': deliveredAt != null,
      });
    }

    // Suivi daté (P4) : remplace les étapes calculées quand il est fourni.
    final delivery = DeliveryInfo.fromMap(order['delivery']);

    // Localisation courante
    String currentLocation;
    if (status == 'delivered') {
      currentLocation = 'tracking.location.delivered'.tr;
    } else if (delivery != null &&
        delivery.isCarrier &&
        delivery.trackingStatusLabel != null &&
        status != 'cancelled') {
      final last = delivery.timeline.isNotEmpty ? delivery.timeline.last : null;
      currentLocation = [
        delivery.trackingStatusLabel!,
        if (last?.location != null) last!.location!,
      ].join(' — ');
    } else if (status == 'shipped') {
      currentLocation = deliveryPerson != null
          ? 'tracking.location.shipped_by'.trParams({'name': '${deliveryPerson['name']}'})
          : 'tracking.location.shipped'.tr;
    } else if (status == 'confirmed') {
      currentLocation = 'tracking.location.awaiting_courier'.tr;
    } else if (status == 'preparing') {
      currentLocation = 'tracking.location.preparing'.tr;
    } else if (status == 'cancelled') {
      currentLocation = 'tracking.location.cancelled'.tr;
    } else {
      currentLocation = 'tracking.location.pending'.tr;
    }

    final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0;

    return {
      'id': order['order_number'] ?? 'CMD-${order['id']}',
      'orderId': order['id'],
      'productName': productName,
      'productImage': productImage,
      'status': displayStatus,
      'statusKey': statusKey,
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
      'delivery': delivery,
      'deliveryFee': double.tryParse(order['delivery_fee']?.toString() ?? ''),
      // Course offerte par le vendeur : prix affiché barré.
      'freeDeliveryAmount': order['free_delivery'] == true
          ? double.tryParse(order['free_delivery_amount']?.toString() ?? '') ?? 0.0
          : 0.0,
    };
  }

  /// Commande transporteur : l'acheteur confirme lui-même la réception.
  Future<bool> confirmReception(Map<String, dynamic> shipment) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('tracking.receipt.title'.tr),
        content: Text(
          'tracking.receipt.message'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('tracking.receipt.not_yet'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(
              'tracking.receipt.confirm'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return false;

    final orderId = int.tryParse(shipment['orderId']?.toString() ?? '');
    if (orderId == null) return false;
    final response = await OrderService.confirmReception(orderId);
    if (response.success) {
      Get.snackbar(
        'tracking.receipt.thanks_title'.tr,
        'tracking.receipt.thanks_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      await loadOrders();
      return true;
    }
    Get.snackbar(
      'tracking.errors.error'.tr,
      response.message.isNotEmpty
          ? response.message
          : 'tracking.errors.confirm_receipt_failed'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
    return false;
  }

  List<Map<String, dynamic>> get filteredShipments {
    var results = shipments.toList();

    if (selectedFilter.value != 'tracking.filters.all') {
      results = results.where((s) => s['statusKey'] == selectedFilter.value).toList();
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
      final defaultMessage = 'tracking.chat.default_message'.trParams({'order': orderRef});

      if (sellerId != null) {
        // ── Conversation avec le vendeur ──
        final response = await ConversationService.startConversation(
          userId: sellerId,
          productId: productId,
        );

        if (!response.success || response.data == null) {
          Get.snackbar(
            'tracking.errors.error'.tr,
            'tracking.errors.chat_seller_failed'.tr,
            snackPosition: SnackPosition.BOTTOM,
          );
          return;
        }

        final conversation = response.data!['conversation'] ?? response.data!;
        final conversationId =
            conversation['id'] ?? conversation['conversation_id'];
        if (conversationId == null) {
          Get.snackbar('tracking.errors.error'.tr, 'tracking.errors.chat_unavailable'.tr,
              snackPosition: SnackPosition.BOTTOM);
          return;
        }

        final otherUser = conversation['other_user'] as Map<String, dynamic>?;
        final sellerNameRaw = shipment['sellerName']?.toString() ?? '';
        final userName = (otherUser?['name']?.toString().isNotEmpty == true)
            ? otherUser!['name'].toString()
            : (sellerNameRaw.isNotEmpty ? sellerNameRaw : 'tracking.chat.seller'.tr);

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
          'tracking.errors.support_unavailable_title'.tr,
          'tracking.errors.support_unavailable_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final response =
          await ConversationService.startConversation(userId: supportUserId);
      if (!response.success || response.data == null) {
        Get.snackbar(
          'tracking.errors.error'.tr,
          'tracking.errors.chat_support_failed'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      final conversation = response.data!['conversation'];
      final conversationId = conversation?['id'];
      if (conversationId == null) {
        Get.snackbar('tracking.errors.error'.tr, 'tracking.errors.chat_unavailable'.tr,
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
      Get.snackbar('tracking.errors.error'.tr, 'tracking.errors.generic'.trParams({'error': '$e'}),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      openingChatOrderId.value = '';
    }
  }

  void contactSupport() {
    Get.snackbar(
      'tracking.support.title'.tr,
      'tracking.support.in_progress'.tr,
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
