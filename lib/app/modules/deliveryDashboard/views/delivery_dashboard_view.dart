import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/delivery_dashboard_controller.dart';
import 'delivery_map_fullscreen_view.dart';
import '../models/delivery_models.dart';
import '../../shipConfig/models/sync_models.dart';

class DeliveryDashboardView extends GetView<DeliveryDashboardController> {
  const DeliveryDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      // Le clavier du dialogue « code de confirmation » ne doit pas comprimer
      // le tableau de bord derrière lui (sinon la liste déborde).
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value && controller.stats.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // L'en-tête (carte, société, statistiques) défile AVEC la liste :
          // en colonne fixe il mangeait la hauteur et ne laissait qu'une
          // fenêtre de défilement minuscule aux livraisons. Les onglets
          // restent épinglés en haut pendant le défilement.
          return RefreshIndicator(
            onRefresh: controller.loadDeliveries,
            child: CustomScrollView(
              // La carte en tête capte les gestes verticaux : sans cela le
              // « tirer pour rafraîchir » ne se déclenche jamais.
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildMapSection(context)),
                SliverToBoxAdapter(child: _buildCompanySection(context)),
                SliverToBoxAdapter(child: _buildStatsSection(context)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabsHeaderDelegate(
                    backgroundColor: context.backgroundColor,
                    child: _buildTabs(context),
                  ),
                ),
                SliverToBoxAdapter(child: _buildTourSummary(context)),
                _buildDeliveriesSliver(context),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Épingle de carte (départ / arrivée).
  Widget _mapPin(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  /// Bandeau d'information du trajet, posé sur la carte.
  ///
  /// Quand plusieurs courses sont en main, les flèches font défiler les étapes.
  Widget _routeBanner(
    BuildContext context,
    Widget leading,
    String label,
    VoidCallback? onClose, {
    VoidCallback? onPrevious,
    VoidCallback? onNext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (onPrevious != null)
            GestureDetector(
              onTap: onPrevious,
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.chevron_left, size: 20),
              ),
            ),
          leading,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onNext != null)
            GestureDetector(
              onTap: onNext,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right, size: 20),
              ),
            ),
          if (onClose != null)
            GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close, size: 16),
            ),
        ],
      ),
    );
  }

  /// Section carte avec bouton ONLINE/OFFLINE
  Widget _buildMapSection(BuildContext context) {
    return SizedBox(
      // Carte volontairement compacte : l'essentiel de l'écran doit rester
      // aux livraisons à effectuer.
      height: 200,
      child: Stack(
        children: [
          // Map OSM
          Obx(() {
            final position = controller.currentPosition.value;
            if (position == null) {
              return Container(
                color: AppThemeSystem.grey200,
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            return FlutterMap(
              mapController: controller.mapController,
              options: MapOptions(
                initialCenter: position,
                initialZoom: 14.0,
                // Un appui sur la carte rafraîchit la position GPS du livreur
                // et zoome dessus : il se voit immédiatement.
                onTap: (tapPosition, point) => controller.locateMe(),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.asso.delivery',
                  additionalOptions: {
                    'attribution': '© OpenStreetMap contributors',
                  },
                ),

                // Trajet réel de la course en cours (boutique -> client).
                Obx(
                  () => PolylineLayer(
                    polylines: controller.routePoints.length < 2
                        ? const <Polyline<Object>>[]
                        : <Polyline<Object>>[
                            Polyline<Object>(
                              points: controller.routePoints.toList(),
                              strokeWidth: 5,
                              color: AppThemeSystem.primaryColor.withValues(
                                alpha: 0.85,
                              ),
                            ),
                          ],
                  ),
                ),

                Obx(() {
                  final tracked = controller.trackedRequest.value;
                  final route = controller.routePoints;

                  return MarkerLayer(
                    markers: [
                      // Position du livreur (GPS si connue, sinon centre de zone).
                      Marker(
                        point: controller.myPosition.value ?? position,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppThemeSystem.primaryColor,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.delivery_dining,
                            color: AppThemeSystem.primaryColor,
                            size: 26,
                          ),
                        ),
                      ),

                      // Départ (boutique) et arrivée (client) de la course suivie.
                      if (tracked != null && route.length >= 2) ...[
                        Marker(
                          point: route.first,
                          width: 40,
                          height: 40,
                          child: _mapPin(
                            Icons.storefront,
                            AppThemeSystem.infoColor,
                          ),
                        ),
                        Marker(
                          point: route.last,
                          width: 40,
                          height: 40,
                          child: _mapPin(
                            Icons.person_pin_circle,
                            AppThemeSystem.successColor,
                          ),
                        ),
                      ],
                    ],
                  );
                }),
              ],
            );
          }),

          // Résumé du trajet calculé, par-dessus la carte.
          Obx(() {
            if (controller.isRoutingLoading.value) {
              return Positioned(
                bottom: 74,
                left: 16,
                right: 16,
                child: _routeBanner(
                  context,
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  'Calcul de l\'itinéraire...',
                  null,
                ),
              );
            }

            final tracked = controller.trackedRequest.value;
            if (tracked == null || controller.routePoints.length < 2) {
              return const SizedBox.shrink();
            }

            final runs = controller.ongoingDeliveries;
            final index = controller.activeRunIndex;
            final km = controller.routeDistanceKm.value;
            final min = controller.routeDurationMin.value;
            final details = [
              '${km.toStringAsFixed(1)} km',
              if (min > 0) '~${min.round()} min',
            ].join(' · ');

            // Plusieurs courses acceptées : on navigue d'une étape à l'autre
            // avec les flèches, sans quitter la carte.
            final hasSeveral = runs.length > 1;
            final label = hasSeveral
                ? 'Étape ${index + 1}/${runs.length} · #${tracked.orderId} · $details'
                : 'Course #${tracked.orderId} · $details';

            return Positioned(
              bottom: 74,
              left: 16,
              right: 16,
              child: _routeBanner(
                context,
                Icon(Icons.route, size: 16, color: AppThemeSystem.primaryColor),
                label,
                controller.stopTracking,
                onPrevious: hasSeveral ? controller.showPreviousRun : null,
                onNext: hasSeveral ? controller.showNextRun : null,
              ),
            );
          }),

          // Bouton « me localiser » (en haut à droite, sous ONLINE/OFFLINE).
          Positioned(
            top: 70,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Obx(
                () => IconButton(
                  icon: controller.isLocating.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 20),
                  onPressed: () => controller.locateMe(),
                  tooltip: 'Ma position',
                ),
              ),
            ),
          ),

          // Agrandir la carte en plein écran (trajet lisible).
          Positioned(
            top: 70,
            right: 74,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.fullscreen, size: 20),
                onPressed: () async {
                  await Get.to(() => const DeliveryMapFullscreenView());
                  // Au retour, la carte compacte doit se redessiner.
                  controller.currentPosition.refresh();
                },
                tooltip: 'Agrandir la carte',
              ),
            ),
          ),

          // Bouton retour (en haut à gauche)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              // Même flèche que partout ailleurs : l'icône maison ne se lisait
              // pas comme une sortie. Le tableau de bord est ouvert sans rien
              // derrière lui, on retourne donc explicitement à l'accueil.
              child: AppBackButton(
                color: AppDesign.neutral900,
                tooltip: 'Retour à l\'accueil',
                onPressed: () => Get.offAllNamed('/home'),
              ),
            ),
          ),

          // Bouton ONLINE/OFFLINE (en haut à droite)
          Positioned(
            top: 16,
            right: 16,
            child: Obx(
              () => GestureDetector(
                onTap: controller.toggleOnlineStatus,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: controller.isOnline.value
                        ? AppDesign.success
                        : AppThemeSystem.grey500,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        controller.isOnline.value ? 'ONLINE' : 'OFFLINE',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Sélecteur de zone (en bas de la carte)
          Positioned(
            bottom: 8,
            left: 16,
            right: 16,
            child: Obx(() {
              if (controller.deliveryZones.isEmpty) {
                return const SizedBox.shrink();
              }

              // Si une seule zone, afficher juste le nom
              if (controller.deliveryZones.length == 1) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.warehouse,
                          size: 20,
                          color: AppThemeSystem.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Dépôt actuel',
                              style: context.caption.copyWith(
                                color: context.secondaryTextColor,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              controller.selectedZone.value?.name ?? '',
                              style: TextStyle(
                                color: AppThemeSystem.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Si plusieurs zones, afficher un sélecteur élégant
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppThemeSystem.primaryColor.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.warehouse,
                            size: 18,
                            color: AppThemeSystem.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Sélectionner un dépôt',
                          style: context.caption.copyWith(
                            color: context.secondaryTextColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.grey100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<DeliveryZone>(
                        value: controller.selectedZone.value,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        icon: Icon(
                          Icons.expand_more,
                          color: AppThemeSystem.primaryColor,
                        ),
                        style: TextStyle(
                          color: AppThemeSystem.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        dropdownColor: Colors.white,
                        items: controller.deliveryZones.map((zone) {
                          return DropdownMenuItem<DeliveryZone>(
                            value: zone,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: zone == controller.selectedZone.value
                                      ? AppThemeSystem.primaryColor
                                      : context.secondaryTextColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    zone.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight:
                                          zone == controller.selectedZone.value
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (zone) {
                          if (zone != null) {
                            controller.selectZone(zone);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Section entreprise
  Widget _buildCompanySection(BuildContext context) {
    return Obx(() {
      final companyData = controller.company.value;
      if (companyData == null) return const SizedBox.shrink();

      return Container(
        margin: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding,
          vertical: 12,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppDesign.accent,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          boxShadow: [
            BoxShadow(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Logo de l'entreprise
            if (companyData.logo != null && companyData.logo!.isNotEmpty)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: context.borderRadius(BorderRadiusType.small),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: context.borderRadius(BorderRadiusType.small),
                  child: Image.network(
                    companyData.logo!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.business,
                        size: 30,
                        color: AppThemeSystem.primaryColor,
                      );
                    },
                  ),
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: context.borderRadius(BorderRadiusType.small),
                ),
                child: Icon(
                  Icons.business,
                  size: 30,
                  color: AppThemeSystem.primaryColor,
                ),
              ),

            const SizedBox(width: 16),

            // Infos de l'entreprise
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vous livrez pour',
                    style: context.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    companyData.name,
                    style: context.h6.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (companyData.description != null &&
                      companyData.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      companyData.description!,
                      style: context.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Actions de droite
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Badge actif
                if (companyData.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppThemeSystem.successColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Actif',
                          style: context.caption.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Bouton de désynchronisation
                GestureDetector(
                  onTap: controller.unsyncProfile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.logout,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Se désynchroniser',
                          style: context.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  /// Section statistiques
  Widget _buildStatsSection(BuildContext context) {
    return Obx(() {
      final stats = controller.stats.value;
      if (stats == null) return const SizedBox.shrink();

      return Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        color: context.surfaceColor,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.pending_actions,
                    label: 'En attente',
                    value: '${stats.pendingDeliveries}',
                    color: AppThemeSystem.warningColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.local_shipping,
                    label: 'En cours',
                    value: '${stats.inProgressDeliveries}',
                    color: AppThemeSystem.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    icon: Icons.check_circle,
                    label: 'Livrés',
                    value: '${stats.completedDeliveries}',
                    color: AppThemeSystem.successColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: controller.openWallet,
                    child: _buildStatItem(
                      context,
                      icon: Icons.account_balance_wallet,
                      label: 'Commissions',
                      value: controller.formatPrice(stats.totalCommissions),
                      color: AppThemeSystem.primaryColor,
                      isCompact: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isCompact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: context.borderRadius(BorderRadiusType.small),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: context.body2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: context.caption.copyWith(
                    color: context.secondaryTextColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Onglets de filtre (épinglés en haut pendant le défilement)
  Widget _buildTabs(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding),
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabChip(context, null, 'Tout'),
                    const SizedBox(width: 8),
                    _buildTabChip(
                      context,
                      DeliveryStatus.pending,
                      'En attente',
                    ),
                    const SizedBox(width: 8),
                    _buildTabChip(
                      context,
                      DeliveryStatus.inProgress,
                      'En cours',
                    ),
                    const SizedBox(width: 8),
                    _buildTabChip(context, DeliveryStatus.delivered, 'Livrés'),
                    const SizedBox(width: 8),
                    _buildTabChip(context, DeliveryStatus.cancelled, 'Annulés'),
                  ],
                ),
              ),
            ),
          ),
          // Actualisation explicite : la carte en tête rend le « tirer pour
          // rafraîchir » peu fiable.
          Obx(
            () => IconButton(
              onPressed: controller.isLoading.value
                  ? null
                  : controller.loadDeliveries,
              icon: controller.isLoading.value
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20),
              tooltip: 'Actualiser',
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  /// Récapitulatif de la tournée : les courses acceptées, dans l'ordre, avec
  /// accès direct à l'itinéraire de chacune.
  ///
  /// Le coursier peut prendre plusieurs commandes ; sans ce bloc elles se
  /// perdent au milieu des demandes en attente.
  Widget _buildTourSummary(BuildContext context) {
    return Obx(() {
      final runs = controller.ongoingDeliveries;
      if (runs.isEmpty) return const SizedBox.shrink();

      final activeId = controller.trackedRequest.value?.id;

      return Container(
        margin: EdgeInsets.fromLTRB(
          context.horizontalPadding,
          0,
          context.horizontalPadding,
          8,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppThemeSystem.primaryColor.withValues(alpha: 0.06),
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.alt_route,
                  size: 18,
                  color: AppThemeSystem.primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ma tournée',
                    style: context.body2.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${runs.length}/${controller.maxActiveRuns.value}',
                  style: context.caption.copyWith(
                    color: AppThemeSystem.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < runs.length; i++)
              _buildTourStep(context, runs[i], i + 1, runs[i].id == activeId),
            if (controller.isAtRunCapacity) ...[
              const SizedBox(height: 4),
              Text(
                'Tournée complète — livrez une commande pour en accepter une autre.',
                style: context.caption.copyWith(
                  color: AppThemeSystem.warningColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  /// Une étape de la tournée : rang, destinataire, gain, accès à l'itinéraire.
  Widget _buildTourStep(
    BuildContext context,
    DeliveryRequest run,
    int position,
    bool isActive,
  ) {
    return InkWell(
      onTap: () async {
        await controller.startTracking(run);
        await Get.to(() => const DeliveryMapFullscreenView());
        controller.currentPosition.refresh();
      },
      borderRadius: context.borderRadius(BorderRadiusType.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive
                    ? AppThemeSystem.primaryColor
                    : AppThemeSystem.primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$position',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppThemeSystem.primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    run.dropoff?.name ?? run.customerName,
                    style: context.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.primaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    run.dropoff?.fullAddress.isNotEmpty == true
                        ? run.dropoff!.fullAddress
                        : run.deliveryAddress,
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              controller.formatPrice(run.commission),
              style: context.caption.copyWith(
                color: AppThemeSystem.successColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.map_outlined,
              size: 16,
              color: AppThemeSystem.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  /// Liste des livraisons, en sliver pour profiter de toute la hauteur restante.
  Widget _buildDeliveriesSliver(BuildContext context) {
    return Obx(() {
      if (controller.filteredRequests.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delivery_dining,
                  size: 80,
                  color: AppThemeSystem.grey300,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune demande',
                  style: context.body1.copyWith(color: AppThemeSystem.grey500),
                ),
              ],
            ),
          ),
        );
      }

      return SliverPadding(
        padding: EdgeInsets.all(context.horizontalPadding),
        sliver: SliverList.builder(
          itemCount: controller.filteredRequests.length,
          itemBuilder: (context, index) {
            final request = controller.filteredRequests[index];
            return _DeliveryCard(request: request);
          },
        ),
      );
    });
  }

  Widget _buildTabChip(
    BuildContext context,
    DeliveryStatus? status,
    String label,
  ) {
    final isSelected = controller.selectedStatus.value == status;

    return GestureDetector(
      onTap: () => controller.selectedStatus.value = status,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeSystem.primaryColor
              : AppThemeSystem.grey100,
          borderRadius: context.borderRadius(BorderRadiusType.small),
          border: Border.all(
            color: isSelected
                ? AppThemeSystem.primaryColor
                : AppThemeSystem.grey300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.secondaryTextColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Carte de demande de livraison
class _DeliveryCard extends GetView<DeliveryDashboardController> {
  final DeliveryRequest request;

  const _DeliveryCard({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withValues(alpha: 0.1),
                  borderRadius: context.borderRadius(BorderRadiusType.small),
                ),
                child: Text(
                  request.status.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.customerName} • ${request.distance.toStringAsFixed(1)} km',
                      style: context.body2.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        // Course d'une tournée : on rappelle son rang pour
                        // que le coursier situe la commande d'un coup d'œil.
                        final runs = controller.ongoingDeliveries;
                        final position = runs.indexWhere(
                          (r) => r.id == request.id,
                        );
                        final prefix = position >= 0 && runs.length > 1
                            ? 'Étape ${position + 1}/${runs.length} · '
                            : '';

                        return Text(
                          '${prefix}Commande #${request.orderId}',
                          style: context.caption.copyWith(
                            color: context.secondaryTextColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppThemeSystem.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.formatPrice(request.commission),
                  style: TextStyle(
                    color: AppThemeSystem.successColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // La course se joue en deux temps : retirer chez le vendeur, puis
          // livrer chez le client. Les deux bouts sont détaillés (qui, où,
          // quel téléphone) pour que le livreur décide en connaissance de cause.
          _buildStopBlock(
            context,
            icon: Icons.storefront_outlined,
            step: '1. Retrait',
            color: AppThemeSystem.infoColor,
            name: request.pickup?.name,
            phone: request.pickup?.phone,
            address: request.pickup?.fullAddress.isNotEmpty == true
                ? request.pickup!.fullAddress
                : request.pickupAddress,
          ),
          const SizedBox(height: 10),
          _buildStopBlock(
            context,
            icon: Icons.person_pin_circle_outlined,
            step: '2. Livraison',
            color: AppThemeSystem.successColor,
            name: request.dropoff?.name ?? request.customerName,
            phone: request.dropoff?.phone ?? request.customerPhone,
            address: request.dropoff?.fullAddress.isNotEmpty == true
                ? request.dropoff!.fullAddress
                : [
                    request.deliveryAddress,
                    request.addressDetails,
                  ].where((e) => e != null && e.trim().isNotEmpty).join(' — '),
          ),

          // Contenu du colis : nature et quantité des articles à transporter.
          if (request.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildAddressRow(
              context,
              Icons.inventory_2_outlined,
              request.items.map((i) => '${i.name} x${i.quantity}').join(', '),
              label: 'Colis',
            ),
          ],

          if (request.leadTime != null &&
              request.leadTime!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildAddressRow(
              context,
              Icons.schedule_outlined,
              request.leadTime!,
              label: 'Délai',
            ),
          ],

          // Valeur de la commande : le livreur transporte ce montant de marchandise.
          if (request.orderTotal > 0) ...[
            const SizedBox(height: 8),
            _buildAddressRow(
              context,
              Icons.receipt_long_outlined,
              controller.formatPrice(request.orderTotal),
              label: 'Valeur commande',
            ),
          ],

          const SizedBox(height: 12),

          // Actions
          _buildActions(context),
        ],
      ),
    );
  }

  /// Une étape de la course (retrait ou livraison) : qui, où, et de quoi appeler.
  Widget _buildStopBlock(
    BuildContext context, {
    required IconData icon,
    required String step,
    required Color color,
    String? name,
    String? phone,
    String? address,
  }) {
    final hasPhone = phone != null && phone.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: context.borderRadius(BorderRadiusType.small),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step,
                  style: context.caption.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (name != null && name.trim().isNotEmpty)
                  Text(
                    name,
                    style: context.body2.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (address != null && address.trim().isNotEmpty)
                  Text(
                    address,
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (hasPhone)
                  Text(
                    phone,
                    style: context.caption.copyWith(
                      color: context.secondaryTextColor,
                    ),
                  ),
              ],
            ),
          ),
          if (hasPhone)
            IconButton(
              onPressed: () => controller.callCustomer(phone),
              icon: Icon(Icons.phone, size: 18, color: color),
              tooltip: 'Appeler',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildAddressRow(
    BuildContext context,
    IconData icon,
    String address, {
    String? label,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: context.secondaryTextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null)
                Text(
                  label,
                  style: context.caption.copyWith(
                    color: context.secondaryTextColor,
                    fontSize: 10,
                  ),
                ),
              Text(
                address,
                style: context.caption.copyWith(
                  color: context.primaryTextColor,
                ),
                // Une adresse tronquée ne permet pas de décider : on la montre
                // en entier (deux lignes au plus).
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    if (request.status == DeliveryStatus.pending) {
      // Tournée pleine : le serveur refuserait de toute façon, autant griser
      // le bouton. Obx pour qu'il se réactive dès qu'une course est livrée.
      return Obx(() {
        final full = controller.isAtRunCapacity;

        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => controller.rejectRequest(request.id),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: BorderSide(color: AppThemeSystem.errorColor),
                ),
                child: const Text('Refuser', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: full
                    ? null
                    : () => controller.acceptRequest(request.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.successColor,
                  disabledBackgroundColor: AppThemeSystem.grey300,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  full ? 'Tournée pleine' : 'Accepter',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        );
      });
    } else if (request.status == DeliveryStatus.inProgress) {
      return Column(
        children: [
          // Trace le trajet boutique -> client sur la carte, en haut de l'écran.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await controller.startTracking(request);
                // Le trajet s'ouvre directement en grand : c'est ce que le
                // coursier veut voir après l'avoir demandé.
                await Get.to(() => const DeliveryMapFullscreenView());
                // Au retour, la carte compacte doit se redessiner.
                controller.currentPosition.refresh();
              },
              icon: const Icon(Icons.route, size: 16),
              label: const Text(
                'Voir l\'itinéraire',
                style: TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                foregroundColor: AppThemeSystem.primaryColor,
                side: BorderSide(color: AppThemeSystem.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.callCustomer(
                    request.dropoff?.phone ?? request.customerPhone,
                  ),
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Appeler', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => controller.markAsDelivered(request.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeSystem.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Livré', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Pour delivered et cancelled, afficher juste la date
    return Text(
      request.deliveredDate != null
          ? 'Livré le ${DateFormat('dd/MM/yyyy à HH:mm').format(request.deliveredDate!)}'
          : 'Annulé le ${DateFormat('dd/MM/yyyy à HH:mm').format(request.requestDate)}',
      style: context.caption.copyWith(color: context.secondaryTextColor),
    );
  }

  Color _getStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return AppThemeSystem.warningColor;
      case DeliveryStatus.inProgress:
        return AppThemeSystem.primaryColor;
      case DeliveryStatus.delivered:
        return AppThemeSystem.successColor;
      case DeliveryStatus.cancelled:
        return AppThemeSystem.errorColor;
    }
  }
}

/// En-tête épinglé des onglets de filtre du tableau de bord livreur.
class _TabsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TabsHeaderDelegate({
    required this.child,
    required this.backgroundColor,
  });

  final Widget child;
  final Color backgroundColor;

  static const double _height = 64;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: backgroundColor, height: _height, child: child);
  }

  @override
  bool shouldRebuild(_TabsHeaderDelegate oldDelegate) =>
      oldDelegate.child != child ||
      oldDelegate.backgroundColor != backgroundColor;
}
