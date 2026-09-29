import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/delivery_dashboard_controller.dart';

/// Carte en plein écran : l'itinéraire d'une course occupe tout l'espace.
///
/// Le tableau de bord garde une carte compacte pour laisser la place aux
/// livraisons ; quand le coursier veut lire son trajet, il l'ouvre ici.
class DeliveryMapFullscreenView extends GetView<DeliveryDashboardController> {
  const DeliveryMapFullscreenView({super.key});

  @override
  Widget build(BuildContext context) {
    // Carte distincte de celle du tableau de bord : un MapController ne peut
    // piloter qu'une seule carte montée à la fois.
    final mapController = MapController();

    return Scaffold(
      body: Obx(() {
        final me =
            controller.myPosition.value ?? controller.currentPosition.value;
        final route = controller.routePoints.toList();
        final center = route.isNotEmpty ? route.first : me;

        if (center == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
                // Cadre le trajet entier dès l'ouverture.
                onMapReady: () {
                  if (route.length >= 2) {
                    try {
                      mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(route),
                          padding: const EdgeInsets.all(60),
                        ),
                      );
                    } catch (_) {
                      // Cadrage impossible : la carte reste centrée par défaut.
                    }
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.asso.delivery',
                  additionalOptions: const {
                    'attribution': '© OpenStreetMap contributors',
                  },
                ),
                if (route.length >= 2)
                  PolylineLayer(
                    polylines: <Polyline<Object>>[
                      Polyline<Object>(
                        points: route,
                        strokeWidth: 6,
                        color: AppThemeSystem.primaryColor.withValues(
                          alpha: 0.85,
                        ),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (me != null)
                      Marker(
                        point: me,
                        width: 46,
                        height: 46,
                        child: _pin(
                          Icons.delivery_dining,
                          AppThemeSystem.primaryColor,
                        ),
                      ),
                    if (route.length >= 2) ...[
                      Marker(
                        point: route.first,
                        width: 46,
                        height: 46,
                        child: _pin(Icons.storefront, AppThemeSystem.infoColor),
                      ),
                      Marker(
                        point: route.last,
                        width: 46,
                        height: 46,
                        child: _pin(
                          Icons.person_pin_circle,
                          AppThemeSystem.successColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // Fermer
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              // Même flèche de retour que le reste de l'application.
              child: DecoratedBox(
                decoration: _roundDecoration,
                child: const AppBackButton(color: AppDesign.neutral900),
              ),
            ),

            // Recentrer sur ma position
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: _roundButton(
                icon: Icons.my_location,
                tooltip: 'delivery_dashboard.map.my_position'.tr,
                onTap: () async {
                  await controller.locateMe(zoom: false);
                  final position = controller.myPosition.value;
                  if (position != null) {
                    mapController.move(position, 16);
                  }
                },
              ),
            ),

            // Cadrer tout le trajet
            if (route.length >= 2)
              Positioned(
                top: MediaQuery.of(context).padding.top + 76,
                right: 16,
                child: _roundButton(
                  icon: Icons.fullscreen,
                  tooltip: 'delivery_dashboard.map.fit_route'.tr,
                  onTap: () {
                    try {
                      mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(route),
                          padding: const EdgeInsets.all(60),
                        ),
                      );
                    } catch (_) {
                      // Sans conséquence : la carte garde sa position.
                    }
                  },
                ),
              ),

            // Résumé du trajet
            if (route.length >= 2)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: _summary(context),
              ),
          ],
        );
      }),
    );
  }

  Widget _summary(BuildContext context) {
    final tracked = controller.trackedRequest.value;
    final km = controller.routeDistanceKm.value;
    final min = controller.routeDurationMin.value;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 18, color: AppThemeSystem.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tracked != null
                      ? 'delivery_dashboard.map.run_title'.trParams({'order': '${tracked.orderId}'})
                      : 'delivery_dashboard.map.route'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                [
                  '${km.toStringAsFixed(1)} km',
                  if (min > 0) '~${min.round()} min',
                ].join(' · '),
                style: TextStyle(
                  color: AppThemeSystem.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (tracked?.pickup?.name != null) ...[
            const SizedBox(height: 8),
            _leg(
              Icons.storefront,
              AppThemeSystem.infoColor,
              'delivery_dashboard.map.pickup'.tr,
              tracked!.pickup!.name!,
            ),
          ],
          if (tracked?.dropoff?.name != null) ...[
            const SizedBox(height: 4),
            _leg(
              Icons.person_pin_circle,
              AppThemeSystem.successColor,
              'delivery_dashboard.map.dropoff'.tr,
              tracked!.dropoff!.name!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _leg(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text('delivery_dashboard.map.label_colon'.trParams({'label': label}), style: const TextStyle(fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _pin(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4),
        ],
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }

  /// Pastille blanche des boutons posés sur la carte.
  static final _roundDecoration = BoxDecoration(
    color: Colors.white,
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Container(
      decoration: _roundDecoration,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onTap,
        tooltip: tooltip,
      ),
    );
  }
}
