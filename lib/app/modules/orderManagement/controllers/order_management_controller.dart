import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/order_model.dart';
import '../models/cameroon_cities.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/vendor_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/delivery_details_widgets.dart';
import '../../../data/models/delivery_info.dart';

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
      final delivery = DeliveryInfo.fromMap(order['delivery']);

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
        orderNumber: order['order_number']?.toString() ?? '',
        deliveryPhone:
            (order['customer_phone'] ?? customer?['phone'] ?? '').toString(),
        addressDetails: order['delivery_address_details']?.toString(),
        paymentStatus: order['payment_status']?.toString() ?? 'paid',
        // Prix du vendeur (hors majoration ASSO payée par le client).
        vendorAmount:
            double.tryParse(
              (order['vendor_amount'] ?? order['subtotal'] ?? order['total'])
                      ?.toString() ??
                  '0',
            ) ??
            0,
        deliveryCompanyName: order['delivery_company']?['name']?.toString() ??
            delivery?.companyName,
        // Transporteur : « preparing » ne signifie pas qu'un livreur est assigné.
        deliveryAssigned:
            order['status'] == 'preparing' && delivery?.isCarrier != true,
        rawStatus: order['status']?.toString() ?? '',
        delivery: delivery,
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
        productImage: orderItem['product_image']?.toString() ?? '',
        variantLabel: orderItem['variant_label']?.toString(),
        tierLabel: orderItem['tier_label']?.toString(),
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
            'Voulez-vous valider la commande #${order.id} de ${order.clientName} ?\n\nLes fonds seront crédités sur votre wallet et disponibles immédiatement.',
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
            order.isCarrier
                ? 'Déposez le colis à l’agence ${order.delivery?.companyName ?? 'du transporteur'} puis appuyez sur « Remettre au transporteur ».'
                : 'Fonds crédités et disponibles. Le livreur a été notifié.',
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
                'Voulez-vous refuser la commande #${order.id} de ${order.clientName} ?\n\nLe client sera intégralement remboursé.',
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
            'Le client a été notifié et remboursé.',
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

  // ================================
  // TRANSPORTEUR (SOLEX, DHL, FedEx…)
  // ================================

  final RxBool isSubmittingTracking = false.obs;

  InputDecoration _fieldDecoration(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
      );

  /// Remise du colis au transporteur : numéro de suivi obligatoire.
  Future<void> handToCarrier(OrderModel order) async {
    final orderId = int.tryParse(order.id);
    if (orderId == null) return;
    final numberCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final error = RxnString();
    final company = order.delivery?.companyName ?? 'transporteur';

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Remettre à $company'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Déposez le colis à l’agence $company puis saisissez le numéro de suivi figurant sur le bordereau. Le client pourra suivre son colis.',
                style: const TextStyle(fontSize: 13),
              ),
              if (order.delivery?.routeLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Trajet : ${order.delivery!.routeLabel}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 14),
              Obx(() => TextField(
                    controller: numberCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _fieldDecoration(
                      'Numéro de suivi *',
                      hint: 'Ex. SLX123456',
                      icon: Icons.qr_code_2_rounded,
                    ).copyWith(errorText: error.value),
                  )),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: _fieldDecoration(
                  'Agence de dépôt (facultatif)',
                  hint: 'Ex. Agence SOLEX Douala Akwa',
                  icon: Icons.store_mall_directory_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: _fieldDecoration('Note (facultatif)', icon: Icons.notes_rounded),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (numberCtrl.text.trim().isEmpty) {
                error.value = 'Le numéro de suivi est obligatoire';
                return;
              }
              Get.back(result: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppThemeSystem.primaryColor),
            child: const Text('Confirmer la remise', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _submitTracking(
      () => VendorService.handToCarrier(
        orderId,
        trackingNumber: numberCtrl.text.trim(),
        location: locationCtrl.text.trim(),
        note: noteCtrl.text.trim(),
      ),
      successTitle: 'Colis remis au transporteur',
      successMessage: 'Le client a reçu le numéro de suivi.',
    );
  }

  /// Nouvelle étape de suivi d'une commande transporteur expédiée.
  Future<void> addTrackingStep(OrderModel order) async {
    final orderId = int.tryParse(order.id);
    if (orderId == null) return;
    final step = RxnString();
    final error = RxnString();
    final locationCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Ajouter une étape'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (order.delivery?.carrierTrackingNumber != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'N° de suivi : ${order.delivery!.carrierTrackingNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              Obx(() => DropdownButtonFormField<String>(
                    initialValue: step.value,
                    isExpanded: true,
                    decoration: _fieldDecoration('Étape *', icon: Icons.timeline_rounded)
                        .copyWith(errorText: error.value),
                    items: DeliveryInfo.vendorTrackingSteps.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (value) {
                      step.value = value;
                      error.value = null;
                    },
                  )),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: _fieldDecoration(
                  'Lieu (facultatif)',
                  hint: 'Ex. Agence SOLEX Yaoundé',
                  icon: Icons.place_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: _fieldDecoration('Note (facultatif)', icon: Icons.notes_rounded),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (step.value == null) {
                error.value = 'Choisissez une étape';
                return;
              }
              Get.back(result: true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppThemeSystem.primaryColor),
            child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || step.value == null) return;

    await _submitTracking(
      () => VendorService.addTrackingStep(
        orderId,
        step: step.value!,
        location: locationCtrl.text.trim(),
        note: noteCtrl.text.trim(),
      ),
      successTitle: 'Suivi mis à jour',
      successMessage:
          '« ${DeliveryInfo.vendorTrackingSteps[step.value]} » ajouté. Le client est informé.',
    );
  }

  Future<void> _submitTracking(
    Future<ApiResponse> Function() call, {
    required String successTitle,
    required String successMessage,
  }) async {
    if (isSubmittingTracking.value) return;
    isSubmittingTracking.value = true;
    try {
      final response = await call();
      if (response.success) {
        await loadOrders();
        Get.snackbar(
          successTitle,
          successMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Action impossible',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (_) {
      Get.snackbar(
        'Erreur',
        'Action impossible pour le moment',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSubmittingTracking.value = false;
    }
  }

  /// Afficher les détails d'une commande
  void showOrderDetails(OrderModel order) {
    final context = Get.context!;
    final phone = order.deliveryPhone.isNotEmpty
        ? order.deliveryPhone
        : order.clientPhone;

    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.subtitle1.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );

    Widget line(IconData icon, String text, {VoidCallback? onCopy}) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.secondaryTextColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: context.body2)),
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded, size: 18),
              ),
            ),
        ],
      ),
    );

    void copy(String value, String what) {
      Clipboard.setData(ClipboardData(text: value));
      Get.snackbar('Copié', '$what copié', snackPosition: SnackPosition.BOTTOM);
    }

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Commande ${order.displayNumber}',
                        style: context.h5.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Chip(label: Text(order.status.label)),
                  ],
                ),
                Text(
                  order.isPaid
                      ? 'Paiement reçu'
                      : 'Paiement du client en attente',
                  style: context.caption.copyWith(
                    color: order.isPaid
                        ? AppThemeSystem.successColor
                        : AppThemeSystem.warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                section('À préparer', [
                  for (final item in order.items)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: item.productImage.isNotEmpty
                                  ? Image.network(
                                      item.productImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Icon(Icons.image_outlined),
                                    )
                                  : const Icon(Icons.inventory_2_outlined),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: context.body1.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.variantLabel != null)
                                  Text(
                                    item.variantLabel!,
                                    style: context.body2.copyWith(
                                      color: AppThemeSystem.primaryColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                if (item.tierLabel != null)
                                  Text(item.tierLabel!, style: context.caption),
                              ],
                            ),
                          ),
                          Text(
                            '×${item.quantity}',
                            style: context.h6.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ]),

                section('Client et livraison', [
                  line(Icons.person_outline, order.clientName),
                  if (phone.isNotEmpty)
                    line(
                      Icons.phone_outlined,
                      phone,
                      onCopy: () => copy(phone, 'Numéro'),
                    ),
                  if (order.address.isNotEmpty)
                    line(
                      Icons.place_outlined,
                      order.address,
                      onCopy: () => copy(order.address, 'Adresse'),
                    ),
                  if (order.addressDetails?.isNotEmpty == true)
                    line(Icons.info_outline, order.addressDetails!),
                  if (order.deliveryCompanyName != null)
                    line(
                      Icons.local_shipping_outlined,
                      'Livraison : ${order.deliveryCompanyName}',
                    ),
                  if (order.deliveryPersonName != null)
                    line(
                      Icons.delivery_dining_outlined,
                      'Livreur : ${order.deliveryPersonName}',
                    ),
                ]),

                if (order.delivery != null)
                  section('Livraison et suivi', [
                    OrderDeliveryDetails(
                      delivery: order.delivery!,
                      formatPrice: (v) => formatPrice(v),
                    ),
                    if (order.canHandToCarrier || order.canAddTrackingStep)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Get.back();
                              order.canHandToCarrier
                                  ? handToCarrier(order)
                                  : addTrackingStep(order);
                            },
                            icon: Icon(
                              order.canHandToCarrier
                                  ? Icons.local_shipping_rounded
                                  : Icons.add_location_alt_outlined,
                              color: Colors.white,
                            ),
                            label: Text(
                              order.canHandToCarrier
                                  ? 'Remettre au transporteur'
                                  : 'Ajouter une étape',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeSystem.primaryColor,
                            ),
                          ),
                        ),
                      ),
                  ]),

                if (order.notes?.isNotEmpty == true)
                  section('Note du client', [
                    line(Icons.sticky_note_2_outlined, order.notes!),
                  ]),

                if (order.cancelReason?.isNotEmpty == true)
                  section('Motif d’annulation', [
                    line(Icons.cancel_outlined, order.cancelReason!),
                  ]),

                section('Montants', [
                  line(
                    Icons.payments_outlined,
                    'Pour vous : ${formatPrice(order.vendorAmount > 0 ? order.vendorAmount : order.totalAmount)}',
                  ),
                  line(
                    Icons.receipt_long_outlined,
                    'Total payé par le client : ${formatPrice(order.totalAmount)}',
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
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
