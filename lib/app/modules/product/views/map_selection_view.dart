import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../../core/utils/app_theme_system.dart';

class MapSelectionView extends StatefulWidget {
  const MapSelectionView({super.key});

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

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
        setState(() {
          _showSearchResults = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingAddress = true;
    });

    // Simuler un délai de récupération GPS
    await Future.delayed(Duration(seconds: 1));

    setState(() {
      _selectedPosition = LatLng(4.0511, 9.7679); // Position de Douala
      _isLoadingAddress = false;
    });

    // Récupérer l'adresse via reverse geocoding
    await _reverseGeocode(_selectedPosition);

    // Centrer la carte sur la position
    _mapController.move(_selectedPosition, 15.0);
  }

  Future<void> _reverseGeocode(LatLng position) async {
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
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=$query&'
        'format=json&'
        'addressdetails=1&'
        'limit=5&'
        'countrycodes=cm' // Limiter au Cameroun
      );

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
          'Choisir la position',
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
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedPosition = point;
                });
                _reverseGeocode(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.asso.app',
                maxZoom: 19,
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

          // Barre de recherche
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

          // Résultats de recherche
          if (_showSearchResults)
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
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _getCurrentLocation,
              child: Icon(
                Icons.my_location_rounded,
                color: AppThemeSystem.primaryColor,
              ),
            ),
          ),

          // Bouton de zoom +
          Positioned(
            right: 16,
            top: 70,
            child: FloatingActionButton(
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
                                  'Position sélectionnée',
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

                      SizedBox(height: 20),

                      // Bouton de validation
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
}
