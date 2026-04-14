import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../models/delivery_models.dart';
import '../../../data/providers/deliverer_service.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/vendor_service.dart';
import '../../../data/services/fcm_service.dart';
import '../../shipConfig/models/sync_models.dart';

class DeliveryDashboardController extends GetxController {
  // Contrôleur de la carte
  final MapController mapController = MapController();

  // Statut du livreur
  final isOnline = false.obs;

  // Position actuelle du livreur (basée sur la zone sélectionnée)
  final currentPosition = Rx<LatLng?>(null);

  // Liste de toutes les demandes
  final allRequests = <DeliveryRequest>[].obs;

  // Liste filtrée
  final filteredRequests = <DeliveryRequest>[].obs;

  // Filtre actuel
  final selectedStatus = Rx<DeliveryStatus?>(null);

  // Statistiques
  final stats = Rx<DeliveryStats?>(null);

  // Entreprise du livreur
  final company = Rx<DelivererCompany?>(null);

  // Zones de livraison (dépôts/entrepôts)
  final deliveryZones = <DeliveryZone>[].obs;
  final selectedZone = Rx<DeliveryZone?>(null);

  // État de chargement
  final isLoading = false.obs;
  final isLoadingCompany = false.obs;

  StreamSubscription? _orderFcmSubscription;

  @override
  void onInit() {
    super.onInit();
    loadCompanyInfo();
    loadDeliveries();
    _listenToDeliveryNotifications();

    ever(selectedStatus, (_) => _applyFilter());
  }

  /// Charge les informations de l'entreprise du livreur
  Future<void> loadCompanyInfo() async {
    isLoadingCompany.value = true;
    try {
      print('🏢 Chargement des infos de l\'entreprise...');
      final response = await DelivererService.getMyCompany();

      if (response.success && response.data != null) {
        final data = response.data!;

        if (data['company'] != null) {
          company.value = DelivererCompany.fromJson(
            data['company'] as Map<String, dynamic>,
          );
          print('✅ Entreprise chargée: ${company.value!.name}');

          // Charger les zones de livraison
          if (data['company']['zones'] != null) {
            final zonesData = data['company']['zones'] as List<dynamic>;
            deliveryZones.value = zonesData
                .map((zone) => DeliveryZone.fromJson(zone as Map<String, dynamic>))
                .toList();

            print('  └─ ${deliveryZones.length} zones de livraison chargées');

            // Sélectionner la première zone par défaut
            if (deliveryZones.isNotEmpty) {
              selectedZone.value = deliveryZones.first;
              print('  └─ Zone par défaut: ${selectedZone.value!.name}');

              // Utiliser la position de la première zone comme position par défaut
              currentPosition.value = LatLng(
                selectedZone.value!.centerLatitude,
                selectedZone.value!.centerLongitude,
              );
              print('  └─ Position: (${selectedZone.value!.centerLatitude}, ${selectedZone.value!.centerLongitude})');
            }
          }
        } else {
          print('⚠️  Pas d\'entreprise dans la réponse');
        }
      } else {
        print('⚠️  Erreur API: ${response.message}');
      }
    } catch (e, stackTrace) {
      print('❌ Erreur lors du chargement de l\'entreprise: $e');
      print('  └─ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
    } finally {
      isLoadingCompany.value = false;
    }
  }

  @override
  void onClose() {
    _orderFcmSubscription?.cancel();
    super.onClose();
  }

  /// Écoute les notifications FCM pour auto-refresh du dashboard livreur
  void _listenToDeliveryNotifications() {
    try {
      final fcmService = Get.find<FcmService>();
      _orderFcmSubscription = fcmService.orderNotificationStream.listen((data) {
        final type = data['type'] as String? ?? '';
        // Rafraîchir quand une nouvelle livraison arrive ou qu'un statut change
        if (type == 'new_delivery_request' ||
            type == 'delivery_assigned' ||
            type == 'order_confirmed' ||
            type.startsWith('order_')) {
          loadDeliveries();
        }
      });
    } catch (e) {
      // FcmService pas encore initialisé
    }
  }

  /// Charge les demandes de livraison depuis l'API
  Future<void> loadDeliveries() async {
    isLoading.value = true;
    try {
      print('🚚 Chargement des livraisons depuis l\'API...');
      final response = await VendorService.getDeliveryDashboard();

      print('  └─ Response success: ${response.success}');
      print('  └─ Response status: ${response.statusCode}');

      if (response.success && response.data != null) {
        final data = response.data!;

        print('  └─ Response data keys: ${data.keys}');
        print('  └─ Deliveries data: ${data['deliveries']}');
        print('  └─ Stats data: ${data['stats']}');

        // Parser les demandes de livraison depuis l'API
        if (data['deliveries'] is List) {
          allRequests.value = _parseDeliveryRequests(data['deliveries']);
          print('✅ ${allRequests.length} livraisons chargées depuis l\'API');
        } else {
          // Pas de livraisons, initialiser liste vide
          allRequests.value = [];
          print('ℹ️  Aucune livraison trouvée');
        }

        // Parser les stats si disponibles
        if (data['stats'] != null) {
          stats.value = _parseStats(data['stats']);
        } else {
          stats.value = _calculateStats();
        }
      } else {
        // Si l'API échoue, initialiser avec liste vide
        allRequests.value = [];
        stats.value = _calculateStats();
        print('⚠️  API failed: ${response.message}');
      }

      // Appliquer le filtre
      _applyFilter();
    } catch (e, stackTrace) {
      // En cas d'erreur, initialiser avec liste vide
      allRequests.value = [];
      stats.value = _calculateStats();
      _applyFilter();

      print('❌ Erreur lors du chargement des livraisons: $e');
      print('  └─ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');

      Get.snackbar(
        'Erreur',
        'Impossible de charger les demandes de livraison',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Parse les statistiques depuis la réponse API
  DeliveryStats _parseStats(Map<String, dynamic> statsData) {
    return DeliveryStats(
      totalDeliveries: statsData['total'] ?? 0,
      pendingDeliveries: statsData['pending'] ?? 0,
      inProgressDeliveries: statsData['in_progress'] ?? 0,
      completedDeliveries: statsData['completed'] ?? 0,
      cancelledDeliveries: statsData['cancelled'] ?? 0,
      totalCommissions: (statsData['total_commissions'] is String
          ? double.tryParse(statsData['total_commissions']) ?? 0.0
          : (statsData['total_commissions'] ?? 0).toDouble()),
      todayCommissions: (statsData['today_commissions'] is String
          ? double.tryParse(statsData['today_commissions']) ?? 0.0
          : (statsData['today_commissions'] ?? 0).toDouble()),
      averageRating: (statsData['average_rating'] is String
          ? double.tryParse(statsData['average_rating']) ?? 0.0
          : (statsData['average_rating'] ?? 0).toDouble()),
    );
  }

  /// Parse les demandes de livraison depuis la réponse API
  List<DeliveryRequest> _parseDeliveryRequests(List<dynamic> rawRequests) {
    return rawRequests.map((item) {
      final request = item as Map<String, dynamic>;
      return DeliveryRequest(
        id: request['id'] ?? 'DEL${DateTime.now().millisecondsSinceEpoch}',
        orderId: request['order_id'] ?? '',
        status: _parseDeliveryStatus(request['status']),
        customerName: request['customer_name'] ?? 'Client',
        customerPhone: request['customer_phone'] ?? '',
        pickupAddress: request['pickup_address'] ?? '',
        pickupLocation: request['pickup_latitude'] != null && request['pickup_longitude'] != null
            ? LatLng(request['pickup_latitude'], request['pickup_longitude'])
            : const LatLng(4.0511, 9.7679),
        deliveryAddress: request['delivery_address'] ?? '',
        deliveryLocation: request['delivery_latitude'] != null && request['delivery_longitude'] != null
            ? LatLng(request['delivery_latitude'], request['delivery_longitude'])
            : const LatLng(4.0511, 9.7679),
        distance: (request['distance'] ?? 0).toDouble(),
        commission: (request['commission'] ?? 0).toDouble(),
        requestDate: _parseDate(request['created_at']),
        acceptedDate: request['accepted_at'] != null ? _parseDate(request['accepted_at']) : null,
        deliveredDate: request['delivered_at'] != null ? _parseDate(request['delivered_at']) : null,
        notes: request['notes'] ?? '',
      );
    }).toList();
  }

  /// Parse delivery status string to enum
  DeliveryStatus _parseDeliveryStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return DeliveryStatus.pending;
      case 'accepted':
      case 'in_progress':
        return DeliveryStatus.inProgress;
      case 'delivered':
        return DeliveryStatus.delivered;
      case 'cancelled':
        return DeliveryStatus.cancelled;
      default:
        return DeliveryStatus.pending;
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

  /// Applique le filtre
  void _applyFilter() {
    var requests = allRequests.toList();

    if (selectedStatus.value != null) {
      requests = requests.where((r) => r.status == selectedStatus.value).toList();
    }

    // Trier par date (plus récent en premier)
    requests.sort((a, b) => b.requestDate.compareTo(a.requestDate));

    filteredRequests.value = requests;
  }

  /// Calcule les statistiques
  DeliveryStats _calculateStats() {
    final pending = allRequests.where((r) => r.status == DeliveryStatus.pending).length;
    final inProgress = allRequests.where((r) => r.status == DeliveryStatus.inProgress).length;
    final completed = allRequests.where((r) => r.status == DeliveryStatus.delivered).length;
    final cancelled = allRequests.where((r) => r.status == DeliveryStatus.cancelled).length;

    final totalCommissions = allRequests
        .where((r) => r.status == DeliveryStatus.delivered)
        .fold(0.0, (sum, r) => sum + r.commission);

    final today = DateTime.now();
    final todayCommissions = allRequests
        .where((r) =>
            r.status == DeliveryStatus.delivered &&
            r.deliveredDate != null &&
            r.deliveredDate!.year == today.year &&
            r.deliveredDate!.month == today.month &&
            r.deliveredDate!.day == today.day)
        .fold(0.0, (sum, r) => sum + r.commission);

    return DeliveryStats(
      totalDeliveries: allRequests.length,
      pendingDeliveries: pending,
      inProgressDeliveries: inProgress,
      completedDeliveries: completed,
      cancelledDeliveries: cancelled,
      totalCommissions: totalCommissions,
      todayCommissions: todayCommissions,
      averageRating: 4.7,
    );
  }

  /// Toggle le statut online/offline
  void toggleOnlineStatus() {
    isOnline.value = !isOnline.value;

    Get.snackbar(
      isOnline.value ? 'Vous êtes en ligne' : 'Vous êtes hors ligne',
      isOnline.value
          ? 'Vous pouvez recevoir des demandes de livraison'
          : 'Vous ne recevrez plus de demandes',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isOnline.value ? Colors.green : Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  /// Accepte une demande de livraison (appel API réel)
  Future<void> acceptRequest(String requestId) async {
    try {
      final orderId = int.tryParse(requestId.toString());
      if (orderId == null) return;

      final response = await DeliveryService.acceptDelivery(orderId);

      if (response.success) {
        await loadDeliveries();
        Get.snackbar(
          'Livraison acceptée',
          'Course démarrée — dirigez-vous vers le point de retrait',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Impossible d\'accepter',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible d\'accepter la demande',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Refuse une demande de livraison
  Future<void> rejectRequest(String requestId) async {
    try {
      final index = allRequests.indexWhere((r) => r.id == requestId);
      if (index == -1) return;

      // TODO: Appel API pour refuser la demande

      await Future.delayed(const Duration(milliseconds: 300));

      // Mettre à jour le statut
      final request = allRequests[index];
      allRequests[index] = DeliveryRequest(
        id: request.id,
        orderId: request.orderId,
        status: DeliveryStatus.cancelled,
        customerName: request.customerName,
        customerPhone: request.customerPhone,
        pickupAddress: request.pickupAddress,
        pickupLocation: request.pickupLocation,
        deliveryAddress: request.deliveryAddress,
        deliveryLocation: request.deliveryLocation,
        distance: request.distance,
        commission: request.commission,
        requestDate: request.requestDate,
        acceptedDate: request.acceptedDate,
        notes: request.notes,
      );

      stats.value = _calculateStats();
      _applyFilter();

      Get.snackbar(
        'Demande refusée',
        'La demande a été refusée',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de refuser la demande',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Complète une livraison avec le code secret du client
  Future<void> markAsDelivered(String requestId) async {
    final codeController = TextEditingController();

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Confirmer la livraison'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Entrez le code secret à 6 chiffres communiqué par le client :'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: const InputDecoration(
                hintText: '000000',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true || codeController.text.length != 6) return;

    try {
      final orderId = int.tryParse(requestId.toString());
      if (orderId == null) return;

      final response = await DeliveryService.completeDelivery(
        orderId,
        confirmationCode: codeController.text,
      );

      if (response.success) {
        await loadDeliveries();
        Get.snackbar(
          'Livraison confirmée !',
          'Commission créditée sur votre wallet.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Code incorrect',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de confirmer la livraison',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Ouvre le chat avec le client
  void openChat(String requestId) {
    // TODO: Implémenter le chat
    Get.snackbar(
      'Chat',
      'Fonctionnalité en cours de développement',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Appelle le client
  void callCustomer(String phone) {
    // TODO: Implémenter l'appel
    Get.snackbar(
      'Appel',
      'Appel vers $phone',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  /// Ouvre le wallet
  void openWallet() {
    // Réutiliser le wallet créé précédemment
    Get.toNamed('/wallet');
  }

  /// Change la zone de livraison sélectionnée
  void selectZone(DeliveryZone zone) {
    selectedZone.value = zone;
    final newPosition = LatLng(
      zone.centerLatitude,
      zone.centerLongitude,
    );
    currentPosition.value = newPosition;

    // Animer la caméra vers la nouvelle position
    try {
      mapController.move(newPosition, 14.0);

      // Animation de rotation et zoom pour un effet dynamique
      Future.delayed(const Duration(milliseconds: 100), () {
        mapController.rotate(0); // Reset rotation
      });
    } catch (e) {
      print('⚠️ Erreur lors de l\'animation de la caméra: $e');
    }

    Get.snackbar(
      'Zone changée',
      'Vous êtes maintenant à ${zone.name}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      icon: const Icon(Icons.warehouse, color: Colors.white),
    );
  }

  /// Désynchronise le profil du livreur
  Future<void> unsyncProfile() async {
    // Demander confirmation
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Désynchronisation'),
        content: const Text(
          'Êtes-vous sûr de vouloir vous désynchroniser ?\n\n'
          'Cela supprimera votre rôle de livreur et vous ne pourrez plus recevoir de demandes de livraison.\n\n'
          'Le code de synchronisation sera libéré et pourra être utilisé par une autre personne.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Désynchroniser'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      print('🔴 Désynchronisation en cours...');

      final response = await DelivererService.unsyncProfile();

      if (response.success) {
        Get.snackbar(
          'Désynchronisation réussie',
          'Vous n\'êtes plus livreur',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );

        // Rediriger vers la page d'accueil après un court délai
        Future.delayed(const Duration(seconds: 1), () {
          Get.offAllNamed('/home');
        });
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Impossible de se désynchroniser',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la désynchronisation: $e');
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue lors de la désynchronisation',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
