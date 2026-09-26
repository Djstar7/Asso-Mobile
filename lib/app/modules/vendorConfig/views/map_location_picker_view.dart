import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/address_search.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/device_location.dart';
import '../../../core/utils/location_label.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/map_search_results.dart';
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
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  bool _searchFailed = false;
  bool _showSearchResults = false;
  Timer? _searchDebounce;
  int _searchRequest = 0;

  /// Incrémenté à chaque déplacement du repère : l'adresse d'un point
  /// précédent, arrivée en retard, n'écrase plus celle du point choisi.
  int _selection = 0;

  /// Saisie en cours ou résultats affichés : la carte laisse toute la place
  /// à la recherche (légende et panneau du bas masqués).
  bool get _isSearchMode => _searchFocusNode.hasFocus || _showSearchResults;

  // Selected deliverer for info display
  DelivererModel? selectedDeliverer;

  String? selectedCity;
  String? selectedCountry;

  String _readableAddress(Map<String, dynamic> data, LatLng position) {
    final location = LocationLabel.fromNominatim(
      data,
      latitude: position.latitude,
      longitude: position.longitude,
    );
    selectedCity = location.city;
    selectedCountry = location.country;
    return location.address;
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

    // Reconstruit à chaque prise/perte de focus : c'est elle qui fait entrer
    // la carte en mode recherche ou l'en fait sortir.
    _searchFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        if (!_searchFocusNode.hasFocus && searchController.text.isEmpty) {
          _showSearchResults = false;
        }
      });
    });

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
    _searchDebounce?.cancel();
    _searchFocusNode.dispose();
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    // Pendant une recherche, toucher la carte la referme sans déplacer le
    // repère.
    if (_isSearchMode) {
      _closeSearch();
      return;
    }

    setState(() {
      _selection++;
      selectedPosition = position;
      selectedAddress = 'Chargement de l\'adresse...';
      searchResults = []; // Fermer les résultats de recherche
    });

    // Obtenir l'adresse via géocodage inverse
    _reverseGeocode(position);
  }

  /// Géocodage inverse : obtenir l'adresse depuis les coordonnées
  Future<void> _reverseGeocode(LatLng position) async {
    final selection = _selection;
    if (mounted) {
      setState(() {
        isGeocodingInProgress = true;
      });
    }

    final data = await AddressSearch.reverse(
      position.latitude,
      position.longitude,
    );
    if (!mounted || selection != _selection) return;
    setState(() {
      if (data != null) {
        selectedAddress = _readableAddress(data, position);
      } else {
        selectedCity = null;
        selectedCountry = null;
        selectedAddress =
            'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
      }
      isGeocodingInProgress = false;
    });
  }

  /// Rechercher une adresse
  /// Lance la recherche une fois la frappe posée.
  ///
  /// Sans délai, chaque lettre partait vers le service de recherche et une
  /// réponse ancienne pouvait écraser la plus récente.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length <= 2) {
      _searchRequest++;
      setState(() {
        searchResults = [];
        isSearching = false;
        _searchFailed = false;
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
      _searchFailed = false;
      _showSearchResults = true;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _searchLocation(value),
    );
  }

  /// Referme la recherche sans toucher à la position choisie.
  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchRequest++;
    _searchFocusNode.unfocus();
    setState(() {
      isSearching = false;
      _showSearchResults = false;
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          searchResults = [];
          _showSearchResults = false;
        });
      }
      return;
    }

    final request = ++_searchRequest;
    if (mounted) {
      setState(() {
        isSearching = true;
        _searchFailed = false;
        _showSearchResults = true;
      });
    }

    // Les lieux proches de la zone affichée passent devant.
    var near = selectedPosition;
    try {
      near = mapController.camera.center;
    } catch (_) {}

    var results = <Map<String, dynamic>>[];
    var failed = false;
    try {
      results = await AddressSearch.search(
        query,
        nearLatitude: near.latitude,
        nearLongitude: near.longitude,
      );
    } on AddressSearchException {
      failed = true;
    }
    // Une frappe plus récente a relancé la recherche : cette réponse
    // n'est plus celle attendue.
    if (!mounted || request != _searchRequest) return;
    setState(() {
      searchResults = results;
      _searchFailed = failed;
      isSearching = false;
    });
  }

  /// Sélectionner un résultat de recherche
  void _selectSearchResult(Map<String, dynamic> result) {
    final position = LatLng(result['lat'], result['lon']);
    _searchDebounce?.cancel();
    _searchRequest++;
    _searchFocusNode.unfocus();

    setState(() {
      _selection++;
      selectedPosition = position;
      selectedAddress = _readableAddress(result, position);
      isGeocodingInProgress = false;
      searchResults = [];
      _showSearchResults = false;
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
        'city': selectedCity,
        'country': selectedCountry,
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    if (isLoading) return;
    final selection = _selection;
    setState(() {
      isLoading = true;
    });

    final result = await DeviceLocation.current();
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
    if (selection != _selection) return;

    final position = result.position;
    if (position == null) {
      DeviceLocation.showFailure(
        result,
        hint: 'Touchez la carte ou recherchez l’adresse de votre boutique.',
      );
      return;
    }

    // Mettre à jour la position sélectionnée
    final newPosition = LatLng(position.latitude, position.longitude);
    setState(() {
      _selection++;
      selectedPosition = newPosition;
      selectedAddress = 'Chargement de l\'adresse...';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Le clavier passe par-dessus la carte au lieu de la comprimer : sinon
      // le panneau du bas remontait avec lui et couvrait les résultats.
      resizeToAvoidBottomInset: false,
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
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
                            color: AppDesign.danger,
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
                          color: AppDesign.danger,
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
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
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
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (value) {
                      _searchDebounce?.cancel();
                      _searchLocation(value);
                    },
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
          if (!_isSearchMode &&
              widget.deliveryPartners != null &&
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
                        Icon(Icons.location_pin, color: AppDesign.danger, size: 20),
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
                            color: AppDesign.accent,
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

          // Panneau d'information en bas, masqué pendant la recherche où il
          // prendrait la place des résultats.
          if (!_isSearchMode)
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
                          color: AppDesign.info.withValues(alpha: 0.1),
                          borderRadius: context.borderRadius(
                            BorderRadiusType.medium,
                          ),
                          border: Border.all(
                            color: AppDesign.info.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.touch_app, color: AppDesign.info, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Appuyez sur la carte pour choisir l\'emplacement de votre boutique',
                                style: context.body2.copyWith(
                                  color: AppDesign.info,
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

          // Résultats en dernier : rien ne doit les recouvrir.
          if (_isSearchMode && _showSearchResults)
            MapSearchResults(
              top: 68,
              left: 10,
              right: 10,
              isSearching: isSearching,
              failed: _searchFailed,
              results: searchResults,
              onSelected: _selectSearchResult,
            ),
        ],
      ),
    );
  }
}
