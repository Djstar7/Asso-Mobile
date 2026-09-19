import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/delivery_service.dart';

class MapSelectionView extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final bool readOnly;
  final String? locationName;

  const MapSelectionView({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.readOnly = false,
    this.locationName,
  });

  @override
  State<MapSelectionView> createState() => _MapSelectionViewState();
}

class _MapSelectionViewState extends State<MapSelectionView> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  LatLng _selectedPosition = LatLng(4.0511, 9.7679); // Douala par défaut
  String _selectedAddress = 'Douala, Cameroun';
  bool _isLoadingAddress = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;

  // Couverture de livraison autour de la position (quartiers, zones, partenaires).
  Map<String, dynamic>? _coverage;
  bool _isLoadingCoverage = false;
  bool _coverageFailed = false;
  Timer? _coverageDebounce;
  int _coverageRequest = 0;

  /// Mêmes couleurs de zone que l'admin (Partenaires logistiques).
  static const List<Color> _zoneColors = [
    Color(0xFFEF4444), Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFF3B82F6), Color(0xFF8B5CF6),
    Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFFEAB308), Color(0xFF6366F1), Color(0xFF84CC16),
  ];

  Color _zoneColor(dynamic zone) {
    final code = zone is num ? zone.toInt() : int.tryParse('$zone') ?? 1;
    return _zoneColors[(code - 1).clamp(0, 1 << 20) % _zoneColors.length];
  }

  void _loadCoverage(LatLng position) {
    if (widget.readOnly) return;
    _coverageDebounce?.cancel();
    setState(() => _isLoadingCoverage = true);
    _coverageDebounce = Timer(const Duration(milliseconds: 400), () async {
      final request = ++_coverageRequest;
      final response = await DeliveryService.getCoverage(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted || request != _coverageRequest) return;
      setState(() {
        _isLoadingCoverage = false;
        final coverage = response.data?['coverage'];
        _coverageFailed = !(response.success && coverage is Map);
        if (!_coverageFailed) _coverage = Map<String, dynamic>.from(coverage as Map);
      });
    });
  }

  List<Map<String, dynamic>> _coverageList(String key) =>
      ((_coverage?[key] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  double _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  LatLng _latLng(Map p) => LatLng(_toDouble(p['latitude']), _toDouble(p['longitude']));

  /// Cadre la carte sur toutes les zones de livraison.
  void _showAllZones() {
    final points = [
      ..._coverageList('quarters').map(_latLng),
      ..._coverageList('zones').map(_latLng),
    ];
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 13);
      return;
    }
    _mapController.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(40, 140, 40, 300),
      maxZoom: 15,
    ));
  }

  @override
  void initState() {
    super.initState();

    // Si des coordonnées initiales sont fournies, les utiliser
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      if (widget.locationName != null && widget.locationName!.isNotEmpty) {
        _selectedAddress = widget.locationName!;
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadCoverage(_selectedPosition));
      } else {
        _reverseGeocode(_selectedPosition);
      }
      // Centrer immédiatement sur la position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_selectedPosition, 15.0);
      });
    } else {
      _getCurrentLocation();
    }

    if (!widget.readOnly) {
      _searchFocusNode.addListener(() {
        if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
          setState(() {
            _showSearchResults = false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _coverageDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingAddress = true;
    });

    String? problem;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = 'La localisation de votre téléphone est désactivée.';
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          problem = 'Autorisez l’accès à votre position dans les réglages.';
        } else {
          Position? position;
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 15),
              ),
            );
          } catch (_) {
            position = await Geolocator.getLastKnownPosition();
          }
          if (position == null) {
            problem = 'Votre position n’a pas pu être détectée.';
          } else {
            _selectedPosition = LatLng(position.latitude, position.longitude);
          }
        }
      }
    } catch (_) {
      problem = 'Votre position n’a pas pu être détectée.';
    }

    if (!mounted) return;
    if (problem != null) {
      setState(() => _isLoadingAddress = false);
      Get.snackbar(
        'Position indisponible',
        '$problem Déplacez le repère sur la carte ou recherchez votre adresse.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    _mapController.move(_selectedPosition, 16.0);
    await _reverseGeocode(_selectedPosition);
  }

  Future<void> _reverseGeocode(LatLng position) async {
    _loadCoverage(position);
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'format=json&'
        'lat=${position.latitude}&'
        'lon=${position.longitude}&'
        'zoom=18&'
        'addressdetails=1'
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'AssoApp/1.0',
        },
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _selectedAddress = data['display_name'] ?? 'Adresse inconnue';
          _isLoadingAddress = false;
        });
      } else {
        setState(() {
          _selectedAddress = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedAddress = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
        _isLoadingAddress = false;
      });
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '5',
        'countrycodes': 'cm', // Limiter au Cameroun
      });

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'AssoApp/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data.map((item) => {
            'display_name': item['display_name'],
            'lat': double.parse(item['lat']),
            'lon': double.parse(item['lon']),
          }).toList();
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final position = LatLng(result['lat'], result['lon']);

    setState(() {
      _selectedPosition = position;
      _selectedAddress = result['display_name'];
      _showSearchResults = false;
      _searchController.clear();
    });

    _searchFocusNode.unfocus();
    _mapController.move(position, 16.0);
    _loadCoverage(position);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppThemeSystem.getPrimaryTextColor(context),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          widget.readOnly ? 'Localisation du produit' : 'Choisir la position',
          style: context.textStyle(
            FontSizeType.h5,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Carte OpenStreetMap
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition,
              initialZoom: 15.0,
              onTap: widget.readOnly ? null : (tapPosition, point) {
                setState(() {
                  _selectedPosition = point;
                });
                _reverseGeocode(point);
              },
              interactionOptions: InteractionOptions(
                flags: widget.readOnly
                    ? InteractiveFlag.drag | InteractiveFlag.pinchZoom
                    : InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.asso.app',
                maxZoom: 19,
              ),
              // Surface de chaque zone urbaine (ex. SOLEX Douala), couleur de la zone.
              CircleLayer(
                circles: _coverageList('quarters')
                    .map((q) => CircleMarker(
                          point: _latLng(q),
                          radius: 700,
                          useRadiusInMeter: true,
                          color: _zoneColor(q['zone']).withValues(alpha: 0.18),
                        ))
                    .toList(),
              ),
              PolygonLayer(
                polygons: _coverageList('zone_areas')
                    .where((a) => ((a['polygon'] as List?) ?? const []).length >= 3)
                    .map((a) => Polygon(
                          points: ((a['polygon'] as List)).whereType<Map>().map(_latLng).toList(),
                          color: _zoneColor(a['zone']).withValues(alpha: 0.18),
                          borderColor: _zoneColor(a['zone']),
                          borderStrokeWidth: 2,
                        ))
                    .toList(),
              ),
              // Zones des livreurs (rayon autour du centre).
              CircleLayer(
                circles: _coverageList('zones')
                    .map((z) => CircleMarker(
                          point: LatLng(_toDouble(z['latitude']), _toDouble(z['longitude'])),
                          radius: _toDouble(z['radius_km']) * 1000,
                          useRadiusInMeter: true,
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                          borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.6),
                          borderStrokeWidth: 1.5,
                        ))
                    .toList(),
              ),
              // Quartiers desservis, colorés par zone (ex. SOLEX Douala).
              MarkerLayer(
                markers: _coverageList('quarters')
                    .map((q) => Marker(
                          width: 16,
                          height: 16,
                          point: LatLng(_toDouble(q['latitude']), _toDouble(q['longitude'])),
                          child: Tooltip(
                            message: '${q['name']} · ${q['zone_label']} (${q['company_name']})',
                            child: Container(
                              decoration: BoxDecoration(
                                color: _zoneColor(q['zone']).withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
              ),
              MarkerLayer(
                markers: [
                  for (final a in _coverageList('zone_areas'))
                    Marker(
                      width: 120,
                      height: 26,
                      point: _latLng(a),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _zoneColor(a['zone']),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '${a['label']} · ${a['company_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  for (final z in _coverageList('zones'))
                    Marker(
                      width: 140,
                      height: 26,
                      point: _latLng(z),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '${z['name']} · ${z['company_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 50.0,
                    height: 50.0,
                    point: _selectedPosition,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppThemeSystem.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: AppThemeSystem.primaryColor,
                        size: 50,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Barre de recherche (seulement si pas en lecture seule)
          if (!widget.readOnly)
            Positioned(
              top: 16,
              left: 16,
              right: 80,
              child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Rechercher une adresse...',
                  hintStyle: context.textStyle(
                    FontSizeType.body2,
                    color: AppThemeSystem.grey600,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppThemeSystem.primaryColor,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: AppThemeSystem.grey600,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _showSearchResults = false;
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: context.textStyle(FontSizeType.body2),
                onChanged: (value) {
                  if (value.length > 2) {
                    _searchLocation(value);
                  } else {
                    setState(() {
                      _searchResults = [];
                      _showSearchResults = false;
                    });
                  }
                },
                onTap: () {
                  if (_searchController.text.isNotEmpty) {
                    setState(() {
                      _showSearchResults = true;
                    });
                  }
                },
              ),
            ),
          ),

          // Voir toutes les zones de livraison d'un coup.
          if (!widget.readOnly &&
              !_showSearchResults &&
              (_coverageList('zone_areas').isNotEmpty || _coverageList('zones').isNotEmpty))
            Positioned(
              top: 76,
              left: 16,
              child: Material(
                color: Colors.white,
                elevation: 3,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _showAllZones,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_rounded, size: 18, color: AppThemeSystem.primaryColor),
                        const SizedBox(width: 6),
                        Text(
                          'Toutes les zones de livraison (${_coverageList('zone_areas').length + _coverageList('zones').length})',
                          style: context.textStyle(FontSizeType.caption, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Résultats de recherche (seulement si pas en lecture seule)
          if (!widget.readOnly && _showSearchResults)
            Positioned(
              top: 76,
              left: 16,
              right: 80,
              child: Container(
                constraints: BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSearching
                    ? Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppThemeSystem.primaryColor,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Recherche en cours...',
                              style: context.textStyle(
                                FontSizeType.body2,
                                color: AppThemeSystem.grey600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  color: AppThemeSystem.grey400,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Aucun résultat trouvé',
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    color: AppThemeSystem.grey600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.symmetric(vertical: 8),
                            itemCount: _searchResults.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: AppThemeSystem.grey200,
                            ),
                            itemBuilder: (context, index) {
                              final result = _searchResults[index];
                              return ListTile(
                                leading: Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: AppThemeSystem.primaryColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  result['display_name'],
                                  style: context.textStyle(
                                    FontSizeType.body2,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectSearchResult(result),
                              );
                            },
                          ),
              ),
            ),

          // Bouton de recentrage GPS
          Positioned(
            right: 16,
            top: 16,
            child: FloatingActionButton(
              heroTag: 'map_gps_button',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: widget.readOnly ? null : _getCurrentLocation,
              child: Icon(
                Icons.my_location_rounded,
                color: widget.readOnly ? AppThemeSystem.grey400 : AppThemeSystem.primaryColor,
              ),
            ),
          ),

          // Bouton de zoom +
          Positioned(
            right: 16,
            top: 70,
            child: FloatingActionButton(
              heroTag: 'map_zoom_in_button',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom + 1,
                );
              },
              child: Icon(
                Icons.add,
                color: AppThemeSystem.grey700,
              ),
            ),
          ),

          // Bouton de zoom -
          Positioned(
            right: 16,
            top: 120,
            child: FloatingActionButton(
              heroTag: 'map_zoom_out_button',
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                _mapController.move(
                  _mapController.camera.center,
                  _mapController.camera.zoom - 1,
                );
              },
              child: Icon(
                Icons.remove,
                color: AppThemeSystem.grey700,
              ),
            ),
          ),

          // Bottom sheet avec adresse sélectionnée
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: AppThemeSystem.getBackgroundColor(context),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppThemeSystem.grey300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Titre
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: AppThemeSystem.primaryColor,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.readOnly ? 'Localisation' : 'Position sélectionnée',
                                  style: context.textStyle(
                                    FontSizeType.caption,
                                    color: AppThemeSystem.grey600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                _isLoadingAddress
                                    ? Row(
                                        children: [
                                          SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                AppThemeSystem.primaryColor,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Récupération de l\'adresse...',
                                            style: context.textStyle(
                                              FontSizeType.body2,
                                              color: AppThemeSystem.grey600,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        _selectedAddress,
                                        style: context.textStyle(
                                          FontSizeType.body1,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (!widget.readOnly) ...[
                        const SizedBox(height: 12),
                        _buildCoverageCard(context),
                      ],

                      // Afficher les coordonnées en mode lecture seule
                      if (widget.readOnly) ...[
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppThemeSystem.primaryColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.gps_fixed_rounded,
                                size: 16,
                                color: AppThemeSystem.primaryColor,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Lat: ${_selectedPosition.latitude.toStringAsFixed(5)}, Lng: ${_selectedPosition.longitude.toStringAsFixed(5)}',
                                style: context.textStyle(
                                  FontSizeType.caption,
                                  color: AppThemeSystem.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 20),

                      // Bouton de validation (seulement si pas en lecture seule)
                      if (!widget.readOnly)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Get.back(result: {
                                'address': _selectedAddress,
                                'latitude': _selectedPosition.latitude,
                                'longitude': _selectedPosition.longitude,
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeSystem.primaryColor,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: Text(
                              'Confirmer cette position',
                              style: context.textStyle(
                                FontSizeType.body1,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// « Livré ici par … » : partenaires qui livrent à domicile à ce point, sinon agences de la ville.
  Widget _buildCoverageCard(BuildContext context) {
    if (_isLoadingCoverage && _coverage == null) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppThemeSystem.primaryColor),
          ),
          const SizedBox(width: 8),
          Text('Recherche des livreurs…',
              style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
        ],
      );
    }
    if (_coverage == null) {
      if (!_coverageFailed) return const SizedBox.shrink();
      return Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: AppThemeSystem.grey600),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Zones de livraison indisponibles pour le moment.',
                style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
          ),
          TextButton(onPressed: () => _loadCoverage(_selectedPosition), child: const Text('Réessayer')),
        ],
      );
    }

    final servedBy = _coverageList('served_by');
    final agencies = _coverageList('agencies');
    final served = servedBy.isNotEmpty;
    final color = served ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    final lines = <Widget>[
      for (final s in servedBy)
        _coverageLine(
          context,
          Icons.local_shipping_rounded,
          s['company_name'].toString(),
          [
            if (s['quarter'] != null) 'Quartier ${s['quarter']}',
            if (s['zone'] != null) 'Zone ${s['zone']}' else s['zone_label']?.toString() ?? '',
            if ((s['vehicles'] as List?)?.isNotEmpty ?? false) (s['vehicles'] as List).join(', '),
          ].where((e) => e.isNotEmpty).join(' · '),
          dotColor: s['zone'] != null ? _zoneColor(s['zone']) : null,
        ),
      for (final a in agencies)
        _coverageLine(
          context,
          Icons.warehouse_rounded,
          '${a['company_name']} — agence à ${a['city']}',
          (((a['destinations'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((d) => d['lead_time'] != null ? '${d['city']} (${d['lead_time']})' : '${d['city']}')
                  .join(', ')),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(served ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  served
                      ? 'Livraison à domicile possible ici'
                      : agencies.isNotEmpty
                          ? 'Pas de livraison à domicile ici : retrait en agence'
                          : 'Aucun livreur ne dessert ce point',
                  style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600),
                ),
              ),
              if (_isLoadingCoverage)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppThemeSystem.primaryColor),
                ),
            ],
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Déplacez le repère vers une zone colorée, ou choisissez un autre mode de livraison.',
              style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coverageLine(BuildContext context, IconData icon, String title, String detail, {Color? dotColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppThemeSystem.grey600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600)),
                if (detail.isNotEmpty)
                  Text(detail,
                      style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (dotColor != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4, left: 6),
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
