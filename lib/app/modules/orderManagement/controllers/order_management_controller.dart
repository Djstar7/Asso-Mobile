import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import '../models/cameroon_cities.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/vendor_service.dart';
import '../../../core/utils/app_theme_system.dart';

class OrderManagementController extends GetxController {
  // Liste complète des commandes
  final RxList<OrderModel> allOrders = <OrderModel>[].obs;

  // Liste filtrée des commandes
  final RxList<OrderModel> filteredOrders = <OrderModel>[].obs;

  // Filtres
  final Rx<OrderStatus?> selectedStatus = Rx<OrderStatus?>(null);
  final RxString selectedCity = 'Toutes les villes'.obs;
  final Rx<DateTime?> selectedDate = Rx<DateTime?>(null);

  // État de chargement
  final RxBool isLoading = false.obs;

  // Recherche
  final RxString searchQuery = ''.obs;
  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadOrders();

    // Écouter les changements de filtres
    ever(selectedStatus, (_) => applyFilters());
    ever(selectedCity, (_) => applyFilters());
    ever(selectedDate, (_) => applyFilters());
    ever(searchQuery, (_) => applyFilters());
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  /// Charge les commandes depuis l'API
  Future<void> loadOrders() async {
    isLoading.value = true;

    try {
      // Essayer de charger depuis l'API
      final response = await ApiProvider.get('/v1/vendor/orders');

      if (response.success && response.data != null) {
        final data = response.data!['data'] ?? response.data!;

        // Parser les commandes depuis l'API
        if (data is List) {
          allOrders.value = _parseOrdersFromApi(data);
        } else if (data is Map && data['orders'] is List) {
          allOrders.value = _parseOrdersFromApi(data['orders']);
        } else {
          allOrders.value = [];
        }
      } else {
        allOrders.value = [];
      }

      applyFilters();
    } catch (e) {
      allOrders.value = [];
      applyFilters();

      Get.snackbar(
        'Erreur',
        'Impossible de charger les commandes',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Parse orders from API response
  List<OrderModel> _parseOrdersFromApi(List<dynamic> rawOrders) {
    return rawOrders.map((item) {
      final order = item as Map<String, dynamic>;
      // L'API retourne 'user' (objet) pour le client, pas des champs plats
      final customer = order['customer'] as Map<String, dynamic>?
          ?? order['user'] as Map<String, dynamic>?;

      return OrderModel(
        id: (order['id'] ?? '').toString(),
        clientId: (customer?['id'] ?? order['user_id'] ?? '').toString(),
        clientName: customer?['name']
            ?? '${customer?['first_name'] ?? ''} ${customer?['last_name'] ?? ''}'.trim(),
        clientPhone: (customer?['phone'] ?? '').toString(),
        clientAvatar: (customer?['avatar'] ?? '').toString(),
        items: _parseOrderItems(order['items'] ?? []),
        totalAmount: double.tryParse(order['total']?.toString() ?? '0') ?? 0,
        status: _parseOrderStatus(order['status']),
        city: order['city'] ?? '',
        address: order['delivery_address'] ?? '',
        orderDate: _parseDate(order['created_at']),
        validatedDate: order['confirmed_at'] != null ? _parseDate(order['confirmed_at']) : null,
        cancelledDate: order['cancelled_at'] != null ? _parseDate(order['cancelled_at']) : null,
        cancelReason: order['cancel_reason'],
        deliveryPersonId: order['delivery_person_id']?.toString(),
        deliveryPersonName: order['delivery_person'] != null
            ? (order['delivery_person']['name'] ?? '${order['delivery_person']['first_name'] ?? ''} ${order['delivery_person']['last_name'] ?? ''}'.trim())
            : null,
        notes: order['notes'],
      );
    }).toList();
  }

  /// Parse order items
  List<OrderItem> _parseOrderItems(List<dynamic> rawItems) {
    return rawItems.map((item) {
      final orderItem = item as Map<String, dynamic>;
      // L'API retourne 'product' (objet) dans chaque item
      final product = orderItem['product'] as Map<String, dynamic>?;

      return OrderItem(
        productId: (orderItem['product_id'] ?? '').toString(),
        productName: orderItem['product_name'] ?? product?['name'] ?? 'Produit',
        quantity: orderItem['quantity'] ?? 1,
        unitPrice: double.tryParse(orderItem['unit_price']?.toString() ?? '0') ?? 0,
        totalPrice: double.tryParse(orderItem['total_price']?.toString() ?? '0') ?? 0,
      );
    }).toList();
  }

  /// Parse order status from backend
  OrderStatus _parseOrderStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
      case 'validated':
      case 'approved':
      case 'preparing':
        return OrderStatus.validated;
      case 'shipped':
        return OrderStatus.inDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  /// Parse ISO datetime string
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  /// Applique les filtres
  void applyFilters() {
    var orders = allOrders.toList();

    // Filtre par statut
    if (selectedStatus.value != null) {
      orders = orders.where((order) => order.status == selectedStatus.value).toList();
    }

    // Filtre par ville
    if (selectedCity.value != 'Toutes les villes') {
      orders = orders.where((order) => order.city == selectedCity.value).toList();
    }

    // Filtre par date
    if (selectedDate.value != null) {
      orders = orders.where((order) {
        return order.orderDate.year == selectedDate.value!.year &&
               order.orderDate.month == selectedDate.value!.month &&
               order.orderDate.day == selectedDate.value!.day;
      }).toList();
    }

    // Filtre par recherche
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      orders = orders.where((order) {
        return order.clientName.toLowerCase().contains(query) ||
               order.id.toLowerCase().contains(query) ||
               order.clientPhone.contains(query);
      }).toList();
    }

    filteredOrders.value = orders;
  }

  /// Réinitialise tous les filtres
  void resetFilters() {
    selectedStatus.value = null;
    selectedCity.value = 'Toutes les villes';
    selectedDate.value = null;
    searchQuery.value = '';
    searchController.clear();
  }

  /// Valide une commande (appel API réel)
  Future<void> validateOrder(OrderModel order) async {
    try {
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Valider la commande'),
          content: Text(
            'Voulez-vous valider la commande #${order.id} de ${order.clientName} ?\n\nLes fonds seront crédités sur votre wallet (bloqués jusqu\'à livraison).',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Valider'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        isLoading.value = true;

        final orderId = int.tryParse(order.id.toString());
        if (orderId == null) return;

        final response = await VendorService.validateOrder(orderId);

        if (response.success) {
          await loadOrders(); // Recharger depuis l'API
          Get.snackbar(
            'Commande validée',
            'Fonds crédités et bloqués. Le livreur a été notifié.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            'Erreur',
            response.message.isNotEmpty ? response.message : 'Impossible de valider la commande',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de valider la commande',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Rejette une commande (appel API réel)
  Future<void> cancelOrder(OrderModel order) async {
    try {
      final reasonController = TextEditingController();
      final confirm = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Refuser la commande'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Voulez-vous refuser la commande #${order.id} de ${order.clientName} ?\n\nLes fonds du client seront débloqués.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Raison du refus (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Non'),
            ),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Refuser la commande', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        isLoading.value = true;

        final orderId = int.tryParse(order.id.toString());
        if (orderId == null) return;

        final response = await VendorService.rejectOrder(
          orderId,
          reason: reasonController.text.isNotEmpty ? reasonController.text : null,
        );

        if (response.success) {
          await loadOrders();
          Get.snackbar(
            'Commande refusée',
            'Le client a été notifié et ses fonds débloqués.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        } else {
          Get.snackbar(
            'Erreur',
            response.message.isNotEmpty ? response.message : 'Impossible de refuser la commande',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
        }
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de refuser la commande',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Ouvre la conversation avec le client
  void openChat(OrderModel order) {
    // TODO: Implémenter l'ouverture du chat
    Get.snackbar(
      'Chat',
      'Conversation avec ${order.clientName}',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Affiche les livreurs de la company assignée à cette commande
  /// Le vendeur peut copier leur numéro pour les appeler directement
  final RxBool isLoadingDeliverers = false.obs;

  Future<void> contactDelivery(OrderModel order) async {
    isLoadingDeliverers.value = true;

    try {
      final orderId = int.tryParse(order.id);
      if (orderId == null) return;

      final response = await VendorService.getAvailableDeliveryPersons(orderId: orderId);

      if (response.success && response.data != null) {
        final data = response.data!['data'] ?? response.data!;
        final company = data['company'] as Map<String, dynamic>?;
        final persons = (data['delivery_persons'] as List?) ?? [];

        _showDeliverersSheet(company, persons);
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Impossible de charger les livreurs',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de charger les livreurs',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoadingDeliverers.value = false;
    }
  }

  void _showDeliverersSheet(Map<String, dynamic>? company, List<dynamic> persons) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: Get.height * 0.7,
        ),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Company header
            if (company != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    backgroundImage: company['logo'] != null
                        ? NetworkImage(company['logo'] as String)
                        : null,
                    child: company['logo'] == null
                        ? Icon(Icons.local_shipping, color: AppThemeSystem.primaryColor)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company['name'] ?? 'Entreprise de livraison',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${persons.length} livreur(s) disponible(s)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
            // Title
            const Text(
              'Livreurs disponibles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Appuyez sur le numéro pour le copier',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 12),
            // List
            if (persons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun livreur synchronisé',
                        style: TextStyle(color: Colors.grey[600], fontSize: 15),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: persons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final person = persons[index] as Map<String, dynamic>;
                    return _buildDelivererTile(person);
                  },
                ),
              ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildDelivererTile(Map<String, dynamic> person) {
    final name = person['name'] ?? 'Livreur';
    final phone = person['phone']?.toString() ?? '';
    final avatar = person['avatar'] as String?;
    final address = person['address']?.toString() ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
        backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
        child: avatar == null || avatar.isEmpty
            ? Icon(Icons.person, color: AppThemeSystem.primaryColor)
            : null,
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (address.isNotEmpty)
            Text(address, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          if (phone.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: phone));
                Get.snackbar(
                  'Copié !',
                  'Numéro $phone copié dans le presse-papier',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                  backgroundColor: AppThemeSystem.successColor,
                  colorText: Colors.white,
                );
              },
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, size: 14, color: AppThemeSystem.primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: TextStyle(
                        color: AppThemeSystem.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.copy, size: 14, color: AppThemeSystem.primaryColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Afficher les détails d'une commande
  void showOrderDetails(OrderModel order) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commande #${order.id}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('Client: ${order.clientName}'),
            Text('Téléphone: ${order.clientPhone}'),
            Text('Ville: ${order.city}'),
            Text('Adresse: ${order.address}'),
            const SizedBox(height: 16),
            const Text(
              'Articles:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('• ${item.productName} x${item.quantity} - ${item.totalPrice} XAF'),
            )),
            const SizedBox(height: 16),
            Text(
              'Total: ${order.totalAmount} XAF',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Génère des commandes de test
  List<OrderModel> _generateMockOrders() {
    final cities = ['Yaoundé', 'Douala', 'Bafoussam', 'Garoua', 'Bamenda'];
    final statuses = [OrderStatus.pending, OrderStatus.validated, OrderStatus.cancelled];
    final names = ['Jean Dupont', 'Marie Claire', 'Paul Kamga', 'Fatima Bello', 'André Tchuente'];

    return List.generate(20, (index) {
      final city = cities[index % cities.length];
      final status = statuses[index % statuses.length];
      final name = names[index % names.length];
      final date = DateTime.now().subtract(Duration(days: index));

      return OrderModel(
        id: 'CMD${1000 + index}',
        clientId: 'client_$index',
        clientName: name,
        clientPhone: '+237 6${70000000 + index}',
        clientAvatar: '',
        items: [
          OrderItem(
            productId: 'prod_1',
            productName: 'Smartphone Galaxy A54',
            quantity: 1,
            unitPrice: 250000,
            totalPrice: 250000,
          ),
          OrderItem(
            productId: 'prod_2',
            productName: 'Écouteurs Bluetooth',
            quantity: 2,
            unitPrice: 15000,
            totalPrice: 30000,
          ),
        ],
        totalAmount: 280000 + (index * 1000),
        status: status,
        city: city,
        address: '${index + 1} Avenue de la République, $city',
        orderDate: date,
        validatedDate: status == OrderStatus.validated ? date.add(const Duration(hours: 2)) : null,
        cancelledDate: status == OrderStatus.cancelled ? date.add(const Duration(hours: 1)) : null,
        cancelReason: status == OrderStatus.cancelled ? 'Produit non disponible' : null,
      );
    });
  }

  /// Obtient le nombre de commandes par statut
  int getOrderCountByStatus(OrderStatus status) {
    return allOrders.where((order) => order.status == status).length;
  }

  /// Obtient les villes disponibles
  List<String> get availableCities => CameroonCities.all;
}
