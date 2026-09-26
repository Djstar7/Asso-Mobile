import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../models/delivery_models.dart';
import '../../../data/providers/deliverer_service.dart';
import '../../../data/providers/delivery_service.dart';
import '../../../data/providers/vendor_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/services/fcm_service.dart';
import '../../shipConfig/models/sync_models.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/device_location.dart';

class DeliveryDashboardController extends GetxController {
  // Contrôleur de la carte
  final MapController mapController = MapController();

  // Statut du livreur
  final isOnline = false.obs;

  // Position affichée sur la carte : GPS si disponible, sinon centre de la zone.
  final currentPosition = Rx<LatLng?>(null);

  /// Position GPS réelle du livreur, distincte du centre de la zone.
  final myPosition = Rx<LatLng?>(null);
  final isLocating = false.obs;

  /// Tournée en cours : toutes les courses acceptées et pas encore livrées.
  ///
  /// Le coursier peut en prendre plusieurs ; elles sont présentées comme des
  /// étapes numérotées, dans l'ordre où il les a acceptées.
  List<DeliveryRequest> get ongoingDeliveries {
    final runs = allRequests
        .where((r) => r.status == DeliveryStatus.inProgress)
        .toList();

    // Ordre de prise en charge : la plus ancienne d'abord.
    runs.sort((a, b) {
      final left = a.acceptedDate ?? a.requestDate;
      final right = b.acceptedDate ?? b.requestDate;
      return left.compareTo(right);
    });

    return runs;
  }

  bool get hasOngoingDelivery => ongoingDeliveries.isNotEmpty;

  /// Nombre de courses transportables en même temps (renvoyé par l'API).
  final maxActiveRuns = 3.obs;

  /// Plafond atteint : les demandes en attente ne sont plus acceptables tant
  /// qu'une course n'a pas été livrée (règle appliquée aussi côté serveur).
  bool get isAtRunCapacity => ongoingDeliveries.length >= maxActiveRuns.value;

  /// Course dont l'itinéraire est affiché sur la carte, parmi la tournée.
  int get activeRunIndex {
    final runs = ongoingDeliveries;
    if (runs.isEmpty) return -1;

    final tracked = trackedRequest.value;
    if (tracked == null) return 0;

    final index = runs.indexWhere((r) => r.id == tracked.id);
    return index >= 0 ? index : 0;
  }

  /// Passe à l'étape suivante de la tournée sur la carte.
  Future<void> showNextRun() async {
    final runs = ongoingDeliveries;
    if (runs.length < 2) return;
    await startTracking(runs[(activeRunIndex + 1) % runs.length]);
  }

  /// Revient à l'étape précédente de la tournée sur la carte.
  Future<void> showPreviousRun() async {
    final runs = ongoingDeliveries;
    if (runs.length < 2) return;
    final previous = (activeRunIndex - 1 + runs.length) % runs.length;
    await startTracking(runs[previous]);
  }

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

  // ---------------------------------------------------------------------------
  // Itinéraire de la course en cours (boutique -> client), tracé sur la carte.
  // ---------------------------------------------------------------------------

  /// Course dont l'itinéraire est affiché.
  final trackedRequest = Rx<DeliveryRequest?>(null);

  /// Points du tracé routier renvoyé par OSRM (vide tant qu'il n'est pas calculé).
  final routePoints = <LatLng>[].obs;

  /// Distance (km) et durée (min) estimées du trajet.
  final routeDistanceKm = 0.0.obs;
  final routeDurationMin = 0.0.obs;
  final isRoutingLoading = false.obs;

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
    // Position réelle dès l'ouverture, sans déplacer la carte de force.
    locateMe(zoom: false);

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
                .map(
                  (zone) => DeliveryZone.fromJson(zone as Map<String, dynamic>),
                )
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
              print(
                '  └─ Position: (${selectedZone.value!.centerLatitude}, ${selectedZone.value!.centerLongitude})',
              );
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
      print(
        '  └─ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}',
      );
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
            type == 'delivery_taken' ||
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
          maxActiveRuns.value = stats.value!.maxActiveRuns;
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
      print(
        '  └─ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}',
      );

      Get.snackbar(
        'Erreur',
        'Impossible de charger les demandes de livraison',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Parse les statistiques depuis la réponse API
  DeliveryStats _parseStats(Map<String, dynamic> statsData) {
    return DeliveryStats(
      totalDeliveries: statsData['total_deliveries'] ?? statsData['total'] ?? 0,
      pendingDeliveries: statsData['pending'] ?? 0,
      inProgressDeliveries: statsData['in_progress'] ?? 0,
      completedDeliveries: statsData['completed'] ?? 0,
      cancelledDeliveries: statsData['cancelled'] ?? 0,
      // Le plafond vient du serveur : une seule source de vérité.
      maxActiveRuns: int.tryParse('${statsData['max_active_runs'] ?? 3}') ?? 3,
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

      // Le backend peut retourner 'customer' comme objet ou des champs plats
      final customer = request['customer'] as Map<String, dynamic>?;
      final customerName =
          request['customer_name'] ?? customer?['name'] ?? 'Client';
      final customerPhone =
          request['customer_phone']?.toString() ??
          customer?['phone']?.toString() ??
          '';

      // Commission = delivery_fee
      final commission =
          double.tryParse(
            (request['commission'] ?? request['delivery_fee'] ?? 0).toString(),
          ) ??
          0.0;

      // Latitude/longitude de livraison
      final deliveryLat = double.tryParse(
        request['delivery_latitude']?.toString() ?? '',
      );
      final deliveryLng = double.tryParse(
        request['delivery_longitude']?.toString() ?? '',
      );

      return DeliveryRequest(
        id: (request['id'] ?? 'DEL${DateTime.now().millisecondsSinceEpoch}')
            .toString(),
        orderId:
            (request['order_id'] ??
                    request['order_number'] ??
                    request['id'] ??
                    '')
                .toString(),
        status: _parseDeliveryStatus(request['status']),
        customerName: customerName,
        customerPhone: customerPhone,
        pickupAddress: request['pickup_address'] ?? '',
        pickupLocation:
            request['pickup_latitude'] != null &&
                request['pickup_longitude'] != null
            ? LatLng(
                double.tryParse(request['pickup_latitude'].toString()) ??
                    4.0511,
                double.tryParse(request['pickup_longitude'].toString()) ??
                    9.7679,
              )
            : const LatLng(4.0511, 9.7679),
        deliveryAddress: request['delivery_address'] ?? '',
        deliveryLocation: deliveryLat != null && deliveryLng != null
            ? LatLng(deliveryLat, deliveryLng)
            : const LatLng(4.0511, 9.7679),
        distance: (request['distance'] ?? 0).toDouble(),
        commission: commission,
        requestDate: _parseDate(request['created_at']),
        acceptedDate: request['shipped_at'] != null
            ? _parseDate(request['shipped_at'])
            : null,
        deliveredDate: request['delivered_at'] != null
            ? _parseDate(request['delivered_at'])
            : null,
        notes: request['notes'] ?? '',
        orderNumber: request['order_number']?.toString(),
        orderTotal: double.tryParse((request['total'] ?? 0).toString()) ?? 0,
        items:
            (request['items'] as List?)
                ?.map(
                  (i) =>
                      DeliveryItem.fromMap(Map<String, dynamic>.from(i as Map)),
                )
                .toList() ??
            const [],
        leadTime: (request['delivery'] as Map?)?['lead_time']?.toString(),
        addressDetails: request['delivery_address_details']?.toString(),
        pickup: DeliveryStop.fromMap(request['pickup']),
        dropoff: DeliveryStop.fromMap(request['dropoff']),
      );
    }).toList();
  }

  /// Parse delivery status string to enum
  DeliveryStatus _parseDeliveryStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
      case 'confirmed':
      case 'preparing':
        return DeliveryStatus.pending;
      case 'shipped':
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
      requests = requests
          .where((r) => r.status == selectedStatus.value)
          .toList();
    }

    // Trier par date (plus récent en premier)
    requests.sort((a, b) => b.requestDate.compareTo(a.requestDate));

    filteredRequests.value = requests;
  }

  /// Calcule les statistiques
  DeliveryStats _calculateStats() {
    final pending = allRequests
        .where((r) => r.status == DeliveryStatus.pending)
        .length;
    final inProgress = allRequests
        .where((r) => r.status == DeliveryStatus.inProgress)
        .length;
    final completed = allRequests
        .where((r) => r.status == DeliveryStatus.delivered)
        .length;
    final cancelled = allRequests
        .where((r) => r.status == DeliveryStatus.cancelled)
        .length;

    final totalCommissions = allRequests
        .where((r) => r.status == DeliveryStatus.delivered)
        .fold(0.0, (sum, r) => sum + r.commission);

    final today = DateTime.now();
    final todayCommissions = allRequests
        .where(
          (r) =>
              r.status == DeliveryStatus.delivered &&
              r.deliveredDate != null &&
              r.deliveredDate!.year == today.year &&
              r.deliveredDate!.month == today.month &&
              r.deliveredDate!.day == today.day,
        )
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
      backgroundColor: isOnline.value ? AppDesign.success : AppDesign.accent,
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
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty
              ? response.message
              : 'Impossible d\'accepter',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible d\'accepter la demande',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
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
        backgroundColor: AppDesign.accent,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de refuser la demande',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  /// Complète une livraison avec le code secret du client
  Future<void> markAsDelivered(String requestId) async {
    final codeController = TextEditingController();

    final confirm = await Get.dialog<bool>(
      AlertDialog(
        // Clavier ouvert sur un petit écran : le contenu défile, le bouton
        // Confirmer reste visible au-dessus du clavier.
        scrollable: true,
        title: const Text('Confirmer la livraison'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le code secret à 6 chiffres communiqué par le client :',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
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
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Erreur',
          response.message.isNotEmpty ? response.message : 'Code incorrect',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de confirmer la livraison',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
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

  /// Appelle un contact de la course (boutique ou client).
  Future<void> callCustomer(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: cleaned);
    if (!await launchUrl(uri)) {
      Get.snackbar(
        'Appel',
        'Impossible de lancer l\'appel vers $phone',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Position du livreur
  // ---------------------------------------------------------------------------

  /// Récupère la position GPS et centre la carte dessus.
  ///
  /// Appelée au chargement puis à chaque appui sur la carte : le livreur se voit
  /// et sa position est rafraîchie.
  Future<void> locateMe({bool zoom = true}) async {
    if (isLocating.value) return;
    isLocating.value = true;

    try {
      final result = await DeviceLocation.current();
      final position = result.position;
      if (position == null) {
        if (zoom) {
          DeviceLocation.showFailure(
            result,
            hint: 'Vous n’apparaissez pas sur la carte pour le moment.',
          );
        }
        return;
      }

      final point = LatLng(position.latitude, position.longitude);
      myPosition.value = point;
      currentPosition.value = point;

      if (zoom) {
        try {
          mapController.move(point, 16.0);
        } catch (_) {
          // Carte pas encore montée : sans conséquence.
        }
      }
    } finally {
      isLocating.value = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Itinéraire de la course
  // ---------------------------------------------------------------------------

  /// Trace sur la carte le trajet réel « boutique -> client » de cette course.
  ///
  /// L'itinéraire vient d'OSRM (service public de routage sur données
  /// OpenStreetMap). Si le service est indisponible, on retombe sur une ligne
  /// directe entre les deux points : la course reste lisible.
  Future<void> startTracking(DeliveryRequest request) async {
    final pickup = _stopLatLng(request.pickup) ?? request.pickupLocation;
    final dropoff = _stopLatLng(request.dropoff) ?? request.deliveryLocation;

    trackedRequest.value = request;
    isRoutingLoading.value = true;
    routePoints.clear();

    try {
      final route = await _fetchRoute(pickup, dropoff);
      routePoints.value = route['points'] as List<LatLng>;
      routeDistanceKm.value = route['distance_km'] as double;
      routeDurationMin.value = route['duration_min'] as double;
    } catch (_) {
      // Repli : tracé direct, sans distance routière fiable.
      routePoints.value = [pickup, dropoff];
      routeDistanceKm.value = const Distance()
          .as(LengthUnit.Kilometer, pickup, dropoff)
          .toDouble();
      routeDurationMin.value = 0;
    } finally {
      isRoutingLoading.value = false;
    }

    _fitRoute(routePoints);
  }

  /// Efface l'itinéraire affiché.
  void stopTracking() {
    trackedRequest.value = null;
    routePoints.clear();
    routeDistanceKm.value = 0;
    routeDurationMin.value = 0;
  }

  LatLng? _stopLatLng(DeliveryStop? stop) {
    if (stop?.latitude == null || stop?.longitude == null) return null;
    return LatLng(stop!.latitude!, stop.longitude!);
  }

  /// Interroge OSRM et décode la géométrie du trajet.
  Future<Map<String, Object>> _fetchRoute(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Routage indisponible (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body['routes'] as List?;
    if (routes == null || routes.isEmpty) {
      throw Exception('Aucun itinéraire trouvé');
    }

    final route = routes.first as Map<String, dynamic>;
    final coordinates =
        (route['geometry'] as Map<String, dynamic>)['coordinates'] as List;

    return {
      // GeoJSON donne [longitude, latitude] : l'ordre est inversé.
      'points': coordinates
          .map((c) => LatLng((c as List)[1].toDouble(), c[0].toDouble()))
          .toList(),
      'distance_km': ((route['distance'] as num?) ?? 0) / 1000,
      'duration_min': ((route['duration'] as num?) ?? 0) / 60,
    };
  }

  /// Cadre la carte sur l'ensemble du trajet.
  void _fitRoute(List<LatLng> points) {
    if (points.length < 2) return;
    try {
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(40),
        ),
      );
    } catch (_) {
      // La carte n'est pas encore montée : sans conséquence.
    }
  }

  /// Ouvre le wallet
  void openWallet() {
    // Réutiliser le wallet créé précédemment
    Get.toNamed('/wallet');
  }

  /// Change la zone de livraison sélectionnée
  void selectZone(DeliveryZone zone) {
    selectedZone.value = zone;
    final newPosition = LatLng(zone.centerLatitude, zone.centerLongitude);
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
      backgroundColor: AppDesign.info,
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
            style: ElevatedButton.styleFrom(backgroundColor: AppDesign.danger),
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
          backgroundColor: AppDesign.success,
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
          response.message.isNotEmpty
              ? response.message
              : 'Impossible de se désynchroniser',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.danger,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Erreur lors de la désynchronisation: $e');
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue lors de la désynchronisation',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
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
