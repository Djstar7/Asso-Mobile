import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/models/deliverer_model.dart';

class MapLocationPickerView extends StatefulWidget {
  final LatLng? initialPosition;
  final String? initialAddress;
  final List<DelivererModel>? deliveryPartners;

  const MapLocationPickerView({
    super.key,
    this.initialPosition,
    this.initialAddress,
    this.deliveryPartners,
  });

  @override
  State<MapLocationPickerView> createState() => _MapLocationPickerViewState();
}

class _MapLocationPickerViewState extends State<MapLocationPickerView> {
  late MapController mapController;
  late LatLng selectedPosition;
  String selectedAddress = '';
  bool isLoading = false;
  bool isGeocodingInProgress =
      false; // Pour suivre si le géocodage est en cours
  bool showDeliveryPartners =
      true; // Toggle pour afficher/masquer les partenaires

  // Recherche
  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;

  // Selected deliverer for info display
  DelivererModel? selectedDeliverer;

  String _readableAddress(Map<String, dynamic> data, LatLng position) {
    final address = Map<String, dynamic>.from(data['address'] ?? const {});
    final locality =
        address['city'] ??
        address['town'] ??
        address['municipality'] ??
        address['village'] ??
        address['county'];
    final area =
        address['road'] ?? address['suburb'] ?? address['neighbourhood'];
    final country = address['country'];
    final parts = <String>{
      if (area != null && area.toString().trim().isNotEmpty) area.toString(),
      if (locality != null && locality.toString().trim().isNotEmpty)
        locality.toString(),
      if (country != null && country.toString().trim().isNotEmpty)
        country.toString(),
    }.toList();
    return parts.isNotEmpty
        ? parts.join(', ')
        : (data['display_name']?.toString() ??
              'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}');
  }

  // Calculer le centre et le zoom pour voir tous les marqueurs
  LatLng _calculateCenter() {
    if (widget.deliveryPartners == null || widget.deliveryPartners!.isEmpty) {
      return widget.initialPosition ?? const LatLng(4.0511, 9.7679);
    }

    // Calculer le centre entre tous les partenaires
    double sumLat = 0;
    double sumLng = 0;
    int count = widget.deliveryPartners!.length;

    for (var partner in widget.deliveryPartners!) {
      sumLat += partner.zone.latitude;
      sumLng += partner.zone.longitude;
    }

    return LatLng(sumLat / count, sumLng / count);
  }

  double _calculateZoom() {
    if (widget.deliveryPartners == null || widget.deliveryPartners!.isEmpty) {
      return 15.0;
    }

    // Trouver les limites (bbox) de tous les marqueurs
    double minLat = widget.deliveryPartners!.first.zone.latitude;
    double maxLat = widget.deliveryPartners!.first.zone.latitude;
    double minLng = widget.deliveryPartners!.first.zone.longitude;
    double maxLng = widget.deliveryPartners!.first.zone.longitude;

    for (var partner in widget.deliveryPartners!) {
      if (partner.zone.latitude < minLat) minLat = partner.zone.latitude;
      if (partner.zone.latitude > maxLat) maxLat = partner.zone.latitude;
      if (partner.zone.longitude < minLng) minLng = partner.zone.longitude;
      if (partner.zone.longitude > maxLng) maxLng = partner.zone.longitude;
    }

    // Calculer la distance approximative
    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    print('🔍 ZOOM CALCULATION:');
    print('  └─ Lat range: $minLat to $maxLat (diff: $latDiff)');
    print('  └─ Lng range: $minLng to $maxLng (diff: $lngDiff)');
    print('  └─ Max diff: $maxDiff');

    // Zoom adapté selon la distance
    if (maxDiff > 0.5) return 9.0; // Très grande zone
    if (maxDiff > 0.2) return 10.0; // Grande zone
    if (maxDiff > 0.1) return 11.0; // Zone moyenne
    if (maxDiff > 0.05) return 12.0; // Petite zone
    return 13.0; // Très petite zone
  }

  @override
  void initState() {
    super.initState();
    mapController = MapController();

    print('');
    print('========================================');
    print('🗺️ MAP LOCATION PICKER: INIT');
    print('========================================');
    print('📍 Initial Position: ${widget.initialPosition}');
    print('📌 Initial Address: ${widget.initialAddress}');
    print(
      '🚚 Delivery Partners Count: ${widget.deliveryPartners?.length ?? 0}',
    );

    if (widget.deliveryPartners != null &&
        widget.deliveryPartners!.isNotEmpty) {
      print('📋 Delivery Partners:');
      for (var partner in widget.deliveryPartners!) {
        print('  ├─ ${partner.name}');
        print('  │  └─ Zone: ${partner.zone.name}');
        print(
          '  │  └─ Position: (${partner.zone.latitude}, ${partner.zone.longitude})',
        );
      }
    } else {
      print('⚠️ No delivery partners provided!');
    }
    print('========================================');

    // Position initiale : soit celle passée en paramètre, soit Douala par défaut
    selectedPosition = widget.initialPosition ?? const LatLng(4.0511, 9.7679);
    selectedAddress = widget.initialAddress ?? '';

    // Si on a une position initiale, obtenir son adresse
    if (selectedAddress.isEmpty && widget.initialPosition != null) {
      _reverseGeocode(selectedPosition);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    setState(() {
      selectedPosition = position;
      selectedAddress = 'Chargement de l\'adresse...';
      searchResults = []; // Fermer les résultats de recherche
    });

    // Obtenir l'adresse via géocodage inverse
    _reverseGeocode(position);
  }

  /// Géocodage inverse : obtenir l'adresse depuis les coordonnées
  Future<void> _reverseGeocode(LatLng position) async {
    if (mounted) {
      setState(() {
        isGeocodingInProgress = true;
      });
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'format=json&'
        'lat=${position.latitude}&'
        'lon=${position.longitude}&'
        'zoom=18&'
        'addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'AssoApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            selectedAddress = _readableAddress(
              Map<String, dynamic>.from(data),
              position,
            );
            isGeocodingInProgress = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            selectedAddress =
                'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
            isGeocodingInProgress = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          selectedAddress =
              'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
          isGeocodingInProgress = false;
        });
      }
    }
  }

  /// Rechercher une adresse
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          searchResults = [];
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        isSearching = true;
      });
    }

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'format=json&'
        'q=$query&'
        'limit=5&'
        'addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'AssoApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            searchResults = data
                .map(
                  (item) => {
                    'display_name': item['display_name'],
                    'lat': double.parse(item['lat']),
                    'lon': double.parse(item['lon']),
                  },
                )
                .toList();
            isSearching = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            searchResults = [];
            isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          searchResults = [];
          isSearching = false;
        });
      }

      Get.snackbar(
        'Erreur',
        'Impossible de rechercher l\'adresse',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    }
  }

  /// Sélectionner un résultat de recherche
  void _selectSearchResult(Map<String, dynamic> result) {
    final position = LatLng(result['lat'], result['lon']);

    setState(() {
      selectedPosition = position;
      selectedAddress = result['display_name'];
      searchResults = [];
      searchController.clear();
    });

    // Animer vers la position
    mapController.move(position, 16.0);
  }

  void _confirmLocation() {
    Get.back(
      result: {
        'latitude': selectedPosition.latitude,
        'longitude': selectedPosition.longitude,
        'address': selectedAddress.isEmpty
            ? 'Position: ${selectedPosition.latitude.toStringAsFixed(4)}, ${selectedPosition.longitude.toStringAsFixed(4)}'
            : selectedAddress,
      },
    );
  }

  void _getCurrentLocation() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException(
          'Permission de localisation refusée',
        );
      }
      // Obtenir la position actuelle
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Mettre à jour la position sélectionnée
      final newPosition = LatLng(position.latitude, position.longitude);
      setState(() {
        selectedPosition = newPosition;
        selectedAddress = 'Chargement de l\'adresse...';
        isLoading = false;
        searchResults = [];
      });

      // Animer vers la position
      mapController.move(selectedPosition, 16.0);

      // Obtenir l'adresse
      _reverseGeocode(newPosition);

      Get.snackbar(
        'Position trouvée',
        'Votre position actuelle a été détectée',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppThemeSystem.successColor.withValues(alpha: 0.9),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } on LocationServiceDisabledException {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Localisation désactivée',
        'Activez la localisation de votre téléphone puis réessayez.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    } on PermissionDeniedException {
      if (mounted) setState(() => isLoading = false);
      Get.snackbar(
        'Permission requise',
        'Autorisez ASSO à accéder à votre position dans les paramètres.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      Get.snackbar(
        'Erreur',
        'Impossible de récupérer votre position actuelle',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.primaryTextColor),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Sélectionner la position',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
        actions: [
          // Toggle pour afficher/masquer les partenaires
          if (widget.deliveryPartners != null &&
              widget.deliveryPartners!.isNotEmpty)
            IconButton(
              icon: Icon(
                showDeliveryPartners ? Icons.visibility : Icons.visibility_off,
                color: AppThemeSystem.primaryColor,
              ),
              tooltip: showDeliveryPartners
                  ? 'Masquer les partenaires'
                  : 'Afficher les partenaires',
              onPressed: () {
                setState(() {
                  showDeliveryPartners = !showDeliveryPartners;
                });
              },
            ),
          IconButton(
            icon: Icon(Icons.my_location, color: AppThemeSystem.primaryColor),
            tooltip: 'Ma position actuelle',
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Carte OpenStreetMap
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: _calculateCenter(),
              initialZoom: _calculateZoom(),
              minZoom: 5.0,
              maxZoom: 18.0,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.asso',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  // Marqueur de la position sélectionnée (ma boutique)
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: selectedPosition,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Ma boutique',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 50,
                        ),
                      ],
                    ),
                  ),
                  // Marqueurs des partenaires de livraison
                  if (showDeliveryPartners && widget.deliveryPartners != null)
                    ...widget.deliveryPartners!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final deliverer = entry.value;

                      print(
                        '🚚 Adding marker for: ${deliverer.name} at (${deliverer.zone.latitude}, ${deliverer.zone.longitude})',
                      );

                      return Marker(
                        width: 100.0,
                        height: 100.0,
                        point: LatLng(
                          deliverer.zone.latitude,
                          deliverer.zone.longitude,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            print('📍 Marker tapped: ${deliverer.name}');
                            setState(() {
                              selectedDeliverer = deliverer;
                            });
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Badge avec numéro
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppThemeSystem.primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '#${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Icône du livreur
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppThemeSystem.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.local_shipping,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),

          // Barre de recherche en haut
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Champ de recherche
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Rechercher une adresse...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppThemeSystem.primaryColor,
                      ),
                      suffixIcon: searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  searchResults = [];
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      _searchLocation(value);
                    },
                    onSubmitted: (value) {
                      _searchLocation(value);
                    },
                  ),

                  // Résultats de recherche
                  if (isSearching)
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppThemeSystem.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (searchResults.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: searchResults.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final result = searchResults[index];
                          return ListTile(
                            leading: Icon(
                              Icons.location_on,
                              color: AppThemeSystem.primaryColor,
                            ),
                            title: Text(
                              result['display_name'],
                              style: const TextStyle(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _selectSearchResult(result),
                            dense: true,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Indicateur de chargement
          if (isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppThemeSystem.primaryColor,
                  ),
                ),
              ),
            ),

          // Légende des marqueurs (en bas à gauche)
          if (widget.deliveryPartners != null &&
              widget.deliveryPartners!.isNotEmpty &&
              showDeliveryPartners)
            Positioned(
              bottom: 200,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppThemeSystem.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Légende',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Ma boutique
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_pin, color: Colors.red, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'Ma boutique',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Livreurs
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppThemeSystem.primaryColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Partenaires (${widget.deliveryPartners!.length})',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Info card for selected deliverer
          if (selectedDeliverer != null)
            Positioned(
              top: 90,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Icône avec gradient
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppThemeSystem.primaryColor,
                                AppThemeSystem.primaryColor.withValues(
                                  alpha: 0.7,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppThemeSystem.primaryColor.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedDeliverer!.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppThemeSystem.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  selectedDeliverer!.zone.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppThemeSystem.primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                          onPressed: () {
                            setState(() {
                              selectedDeliverer = null;
                            });
                          },
                        ),
                      ],
                    ),
                    if (selectedDeliverer!.description != null &&
                        selectedDeliverer!.description!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          selectedDeliverer!.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Contact info
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.primaryColor.withValues(
                          alpha: 0.05,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            size: 16,
                            color: AppThemeSystem.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedDeliverer!.phone,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Panneau d'information en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(context.horizontalPadding),
              decoration: BoxDecoration(
                color: context.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre avec info
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Position de ma boutique',
                            style: context.subtitle1.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.deliveryPartners != null &&
                            widget.deliveryPartners!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppThemeSystem.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_shipping,
                                  size: 12,
                                  color: AppThemeSystem.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.deliveryPartners!.length} partenaires',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppThemeSystem.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: context.elementSpacing * 0.5),

                    // Message d'aide
                    if (selectedAddress.isEmpty)
                      Container(
                        padding: EdgeInsets.all(
                          context.horizontalPadding * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: context.borderRadius(
                            BorderRadiusType.medium,
                          ),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.touch_app, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Appuyez sur la carte pour choisir l\'emplacement de votre boutique',
                                style: context.body2.copyWith(
                                  color: Colors.blue[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Adresse ou coordonnées
                      Container(
                        padding: EdgeInsets.all(
                          context.horizontalPadding * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.successColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: context.borderRadius(
                            BorderRadiusType.medium,
                          ),
                          border: Border.all(
                            color: AppThemeSystem.successColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppThemeSystem.successColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedAddress,
                                style: context.body2.copyWith(
                                  color: context.primaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: context.elementSpacing),

                    // Bouton de confirmation
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (selectedAddress.isEmpty ||
                                isGeocodingInProgress ||
                                selectedAddress.contains('Chargement'))
                            ? null
                            : _confirmLocation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeSystem.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: context.verticalPadding * 0.75,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: context.borderRadius(
                              BorderRadiusType.medium,
                            ),
                          ),
                        ),
                        child: Text(
                          isGeocodingInProgress
                              ? 'Chargement de l\'adresse...'
                              : 'Confirmer cette position',
                          style: context.button.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
