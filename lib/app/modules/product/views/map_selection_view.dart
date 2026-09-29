import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/utils/address_search.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/device_location.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/map_search_results.dart';
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
  String _selectedAddress = 'product.map.default_address'.tr;
  bool _isLoadingAddress = false;
  bool _isLocating = false;
  bool _isSearching = false;
  bool _searchFailed = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;
  Timer? _searchDebounce;
  int _searchRequest = 0;

  /// Incrémenté à chaque déplacement du repère. Une position GPS ou une
  /// adresse arrivée après un nouveau choix de l'utilisateur est ignorée :
  /// avant, le GPS lancé à l'ouverture ramenait le repère sur la position du
  /// téléphone, et l'adresse d'un ancien point remplaçait celle du nouveau.
  int _selection = 0;

  void _moveSelection(LatLng position) {
    _selection++;
    _selectedPosition = position;
    _isLocating = false;
  }

  /// Saisie en cours ou résultats affichés : la carte laisse toute la place
  /// à la recherche (panneau du bas et boutons masqués).
  bool get _isSearchMode =>
      !widget.readOnly && (_searchFocusNode.hasFocus || _showSearchResults);

  // Couverture de livraison autour de la position (quartiers, zones, partenaires).
  Map<String, dynamic>? _coverage;
  bool _isLoadingCoverage = false;
  bool _coverageFailed = false;
  Timer? _coverageDebounce;
  int _coverageRequest = 0;

  /// Mêmes couleurs de zone que l'admin (Partenaires logistiques).
  static const List<Color> _zoneColors = [
    Color(0xFFEF4444),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFEAB308),
    Color(0xFF6366F1),
    Color(0xFF84CC16),
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
        if (!_coverageFailed)
          _coverage = Map<String, dynamic>.from(coverage as Map);
      });
    });
  }

  List<Map<String, dynamic>> _coverageList(String key) =>
      ((_coverage?[key] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  LatLng _latLng(Map p) =>
      LatLng(_toDouble(p['latitude']), _toDouble(p['longitude']));

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
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(40, 140, 40, 300),
        maxZoom: 15,
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Si des coordonnées initiales sont fournies, les utiliser
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPosition = LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      if (widget.locationName != null && widget.locationName!.isNotEmpty) {
        _selectedAddress = widget.locationName!;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadCoverage(_selectedPosition),
        );
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
      // Reconstruit à chaque prise/perte de focus : c'est elle qui fait
      // entrer la carte en mode recherche ou l'en fait sortir.
      _searchFocusNode.addListener(() {
        if (!mounted) return;
        setState(() {
          if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
            _showSearchResults = false;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _coverageDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_isLocating) return;
    final selection = _selection;
    setState(() => _isLocating = true);

    final result = await DeviceLocation.current();
    // L'utilisateur a placé le repère entre-temps : son choix l'emporte.
    if (!mounted || selection != _selection) return;

    final position = result.position;
    if (position == null) {
      setState(() => _isLocating = false);
      DeviceLocation.showFailure(
        result,
        hint: 'product.map.locate_failed_hint'.tr,
      );
      return;
    }

    final point = LatLng(position.latitude, position.longitude);
    setState(() => _moveSelection(point));
    _mapController.move(point, 16.0);
    await _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng position) async {
    _loadCoverage(position);
    final selection = _selection;
    setState(() {
      _isLoadingAddress = true;
    });

    final data = await AddressSearch.reverse(
      position.latitude,
      position.longitude,
    );
    if (!mounted || selection != _selection) return;
    setState(() {
      _selectedAddress =
          data?['display_name']?.toString() ?? _coordinatesLabel(position);
      _isLoadingAddress = false;
    });
  }

  static String _coordinatesLabel(LatLng position) =>
      'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';

  /// Lance la recherche une fois la frappe posée.
  ///
  /// Sans délai, chaque lettre partait vers le service de recherche et une
  /// réponse ancienne pouvait écraser la plus récente : la liste changeait
  /// sous les yeux sans correspondre à la saisie.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().length <= 2) {
      _searchRequest++;
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
        _isSearching = false;
        _searchFailed = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
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
      _showSearchResults = false;
      _isSearching = false;
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    final request = ++_searchRequest;
    setState(() {
      _isSearching = true;
      _searchFailed = false;
      _showSearchResults = true;
    });

    // Les lieux proches de la zone affichée passent devant.
    final near = _searchCenter();
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
      _searchResults = results;
      _searchFailed = failed;
      _isSearching = false;
    });
  }

  LatLng _searchCenter() {
    try {
      return _mapController.camera.center;
    } catch (_) {
      return _selectedPosition;
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final position = LatLng(result['lat'], result['lon']);
    _searchDebounce?.cancel();
    _searchRequest++;

    setState(() {
      _moveSelection(position);
      _selectedAddress = result['display_name'];
      _isLoadingAddress = false;
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
      // Le clavier passe par-dessus la carte au lieu de la comprimer : sinon
      // le panneau du bas remontait avec lui et couvrait les résultats.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        elevation: 0,
        leading: const AppBackButton(),
        title: Text(
          widget.readOnly
              ? 'product.map.title_readonly'.tr
              : 'product.map.title_pick'.tr,
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
              onTap: widget.readOnly
                  ? null
                  : (tapPosition, point) {
                      // Pendant une recherche, toucher la carte la referme
                      // sans déplacer le repère.
                      if (_isSearchMode) {
                        _closeSearch();
                        return;
                      }
                      setState(() => _moveSelection(point));
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
                    .map(
                      (q) => CircleMarker(
                        point: _latLng(q),
                        radius: 700,
                        useRadiusInMeter: true,
                        color: _zoneColor(q['zone']).withValues(alpha: 0.18),
                      ),
                    )
                    .toList(),
              ),
              PolygonLayer(
                polygons: _coverageList('zone_areas')
                    .where(
                      (a) => ((a['polygon'] as List?) ?? const []).length >= 3,
                    )
                    .map(
                      (a) => Polygon(
                        points: ((a['polygon'] as List))
                            .whereType<Map>()
                            .map(_latLng)
                            .toList(),
                        color: _zoneColor(a['zone']).withValues(alpha: 0.18),
                        borderColor: _zoneColor(a['zone']),
                        borderStrokeWidth: 2,
                      ),
                    )
                    .toList(),
              ),
              // Zones des livreurs (rayon autour du centre).
              CircleLayer(
                circles: _coverageList('zones')
                    .map(
                      (z) => CircleMarker(
                        point: LatLng(
                          _toDouble(z['latitude']),
                          _toDouble(z['longitude']),
                        ),
                        radius: _toDouble(z['radius_km']) * 1000,
                        useRadiusInMeter: true,
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                        borderColor: const Color(
                          0xFF3B82F6,
                        ).withValues(alpha: 0.6),
                        borderStrokeWidth: 1.5,
                      ),
                    )
                    .toList(),
              ),
              // Quartiers desservis, colorés par zone (ex. SOLEX Douala).
              MarkerLayer(
                markers: _coverageList('quarters')
                    .map(
                      (q) => Marker(
                        width: 16,
                        height: 16,
                        point: LatLng(
                          _toDouble(q['latitude']),
                          _toDouble(q['longitude']),
                        ),
                        child: Tooltip(
                          message:
                              '${q['name']} · ${q['zone_label']} (${q['company_name']})',
                          child: Container(
                            decoration: BoxDecoration(
                              color: _zoneColor(
                                q['zone'],
                              ).withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    )
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _zoneColor(a['zone']),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '${a['label']} · ${a['company_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            '${z['name']} · ${z['company_name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
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
                            color: AppThemeSystem.primaryColor.withValues(
                              alpha: 0.4,
                            ),
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
              // Pleine largeur en recherche : les boutons de droite sont
              // masqués et les adresses longues ont besoin de la place.
              right: _isSearchMode ? 16 : 80,
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
                    hintText: 'product.map.search_hint'.tr,
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
                              _onSearchChanged('');
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
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) {
                    _searchDebounce?.cancel();
                    if (value.trim().isNotEmpty) _searchLocation(value);
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
              !_isSearchMode &&
              (_coverageList('zone_areas').isNotEmpty ||
                  _coverageList('zones').isNotEmpty))
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.layers_rounded,
                          size: 18,
                          color: AppThemeSystem.primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'product.map.all_zones'.trParams({
                            'count':
                                '${_coverageList('zone_areas').length + _coverageList('zones').length}',
                          }),
                          style: context.textStyle(
                            FontSizeType.caption,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Contrôles et panneau du bas : masqués pendant la recherche, où
          // ils ne servent à rien et prendraient la place des résultats.
          if (!_isSearchMode) ...[
            // Bouton de recentrage GPS
            Positioned(
              right: 16,
              top: 16,
              child: FloatingActionButton(
                heroTag: 'map_gps_button',
                mini: true,
                backgroundColor: Colors.white,
                onPressed: widget.readOnly ? null : _getCurrentLocation,
                child: _isLocating
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppThemeSystem.primaryColor,
                        ),
                      )
                    : Icon(
                        Icons.my_location_rounded,
                        color: widget.readOnly
                            ? AppThemeSystem.grey400
                            : AppThemeSystem.primaryColor,
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
                child: Icon(Icons.add, color: AppThemeSystem.grey700),
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
                child: Icon(Icons.remove, color: AppThemeSystem.grey700),
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
                                color: AppThemeSystem.primaryColor.withValues(
                                  alpha: 0.1,
                                ),
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
                                    widget.readOnly
                                        ? 'product.map.location'.tr
                                        : 'product.map.selected_position'.tr,
                                    style: context.textStyle(
                                      FontSizeType.caption,
                                      color: AppThemeSystem.grey600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  _isLoadingAddress || _isLocating
                                      ? Row(
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      AppThemeSystem
                                                          .primaryColor,
                                                    ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              _isLoadingAddress
                                                  ? 'product.map.fetching_address'.tr
                                                  : 'product.map.detecting_position'.tr,
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
                              color: AppThemeSystem.primaryColor.withValues(
                                alpha: 0.05,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppThemeSystem.primaryColor.withValues(
                                  alpha: 0.2,
                                ),
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
                                Get.back(
                                  result: {
                                    // Adresse encore en chargement : les
                                    // coordonnées plutôt que celle du point
                                    // précédent.
                                    'address': _isLoadingAddress
                                        ? _coordinatesLabel(_selectedPosition)
                                        : _selectedAddress,
                                    'latitude': _selectedPosition.latitude,
                                    'longitude': _selectedPosition.longitude,
                                  },
                                );
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
                                'product.map.confirm_position'.tr,
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

          // Résultats en dernier : rien ne doit les recouvrir.
          if (_isSearchMode && _showSearchResults)
            MapSearchResults(
              top: 76,
              isSearching: _isSearching,
              failed: _searchFailed,
              results: _searchResults,
              onSelected: _selectSearchResult,
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
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppThemeSystem.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'product.map.searching_couriers'.tr,
            style: context.textStyle(
              FontSizeType.caption,
              color: AppThemeSystem.grey600,
            ),
          ),
        ],
      );
    }
    if (_coverage == null) {
      if (!_coverageFailed) return const SizedBox.shrink();
      return Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: AppThemeSystem.grey600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'product.map.zones_unavailable'.tr,
              style: context.textStyle(
                FontSizeType.caption,
                color: AppThemeSystem.grey600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _loadCoverage(_selectedPosition),
            child: Text('product.retry'.tr),
          ),
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
            if (s['quarter'] != null)
              'product.map.quarter'.trParams({'name': '${s['quarter']}'}),
            if (s['zone'] != null)
              'product.map.zone'.trParams({'zone': '${s['zone']}'})
            else
              s['zone_label']?.toString() ?? '',
            if ((s['vehicles'] as List?)?.isNotEmpty ?? false)
              (s['vehicles'] as List).join(', '),
          ].where((e) => e.isNotEmpty).join(' · '),
          dotColor: s['zone'] != null ? _zoneColor(s['zone']) : null,
        ),
      for (final a in agencies)
        _coverageLine(
          context,
          Icons.warehouse_rounded,
          'product.map.agency_in'.trParams({
            'company': '${a['company_name']}',
            'city': '${a['city']}',
          }),
          (((a['destinations'] as List?) ?? const [])
              .whereType<Map>()
              .map(
                (d) => d['lead_time'] != null
                    ? '${d['city']} (${d['lead_time']})'
                    : '${d['city']}',
              )
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
              Icon(
                served
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  served
                      ? 'product.map.couriers_here'.tr
                      : agencies.isNotEmpty
                      ? 'product.map.agency_pickup_here'.tr
                      : 'product.map.no_courier_here'.tr,
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_isLoadingCoverage)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppThemeSystem.primaryColor,
                  ),
                ),
            ],
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'product.map.offers_depend_on_shop'.tr,
              style: context.textStyle(
                FontSizeType.caption,
                color: AppThemeSystem.grey600,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lines,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'product.map.move_to_zone_hint'.tr,
              style: context.textStyle(
                FontSizeType.caption,
                color: AppThemeSystem.grey600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coverageLine(
    BuildContext context,
    IconData icon,
    String title,
    String detail, {
    Color? dotColor,
  }) {
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
                Text(
                  title,
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: AppThemeSystem.grey600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (dotColor != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4, left: 6),
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
