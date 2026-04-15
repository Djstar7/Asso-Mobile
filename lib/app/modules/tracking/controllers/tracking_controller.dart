import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/services/fcm_service.dart';

class TrackingController extends GetxController {
  final TextEditingController searchController = TextEditingController();
  final RxList<Map<String, dynamic>> shipments = <Map<String, dynamic>>[].obs;
  final RxString selectedFilter = 'Tous'.obs;
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;

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
        shipments.value = ordersList
            .map((o) => _mapOrderToShipment(Map<String, dynamic>.from(o)))
            .where((s) => s != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
    } catch (e) {
      // Silently fail
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
    if (items.isNotEmpty) {
      final firstItem = items[0] as Map<String, dynamic>;
      productName = firstItem['product_name'] ?? 'Produit';
      productImage = firstItem['product_image'] ?? '';
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
    final numberFormat = NumberFormat('#,###', 'fr_FR');

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
      'seller': '',
      'price': '${numberFormat.format(total)} FCFA',
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

  void contactSupport() {
    Get.snackbar(
      'Support',
      'Fonction de contact support en développement',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
