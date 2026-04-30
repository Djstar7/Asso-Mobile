import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/delivery_dashboard_controller.dart';
import '../models/delivery_models.dart';
import '../../shipConfig/models/sync_models.dart';

class DeliveryDashboardView extends GetView<DeliveryDashboardController> {
  const DeliveryDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value && controller.stats.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // Map Section
              _buildMapSection(context),

              // Company Info
              _buildCompanySection(context),

              // Stats & Wallet
              _buildStatsSection(context),

              // Tabs & List
              Expanded(
                child: _buildTabsAndList(context),
              ),
            ],
          );
        }),
      ),
    );
  }

  /// Section carte avec bouton ONLINE/OFFLINE
  Widget _buildMapSection(BuildContext context) {
    return SizedBox(
      height: 250,
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
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.asso.delivery',
                  additionalOptions: {
                    'attribution': '© OpenStreetMap contributors',
                  },
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: position,
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.delivery_dining,
                        color: AppThemeSystem.primaryColor,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),

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
              child: IconButton(
                icon: const Icon(Icons.home, size: 20),
                onPressed: () => Get.offAllNamed('/home'),
                tooltip: 'Retour à l\'accueil',
              ),
            ),
          ),

          // Bouton ONLINE/OFFLINE (en haut à droite)
          Positioned(
            top: 16,
            right: 16,
            child: Obx(() => GestureDetector(
                  onTap: controller.toggleOnlineStatus,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: controller.isOnline.value ? Colors.green : AppThemeSystem.grey500,
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
                )),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
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
                            color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                                      fontWeight: zone == controller.selectedZone.value
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
          gradient: LinearGradient(
            colors: [
              AppThemeSystem.primaryColor,
              AppThemeSystem.primaryColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
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

  /// Tabs et liste
  Widget _buildTabsAndList(BuildContext context) {
    return Column(
      children: [
        // Tabs
        Container(
          padding: EdgeInsets.all(context.horizontalPadding),
          child: Obx(() => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabChip(context, null, 'Tout'),
                    const SizedBox(width: 8),
                    _buildTabChip(context, DeliveryStatus.pending, 'En attente'),
                    const SizedBox(width: 8),
                    _buildTabChip(context, DeliveryStatus.inProgress, 'En cours'),
                    const SizedBox(width: 8),
                    _buildTabChip(context, DeliveryStatus.delivered, 'Livrés'),
                    const SizedBox(width: 8),
                    _buildTabChip(context, DeliveryStatus.cancelled, 'Annulés'),
                  ],
                ),
              )),
        ),

        // Liste
        Expanded(
          child: Obx(() {
            if (controller.filteredRequests.isEmpty) {
              return Center(
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
              );
            }

            return RefreshIndicator(
              onRefresh: controller.loadDeliveries,
              child: ListView.builder(
                padding: EdgeInsets.all(context.horizontalPadding),
                itemCount: controller.filteredRequests.length,
                itemBuilder: (context, index) {
                  final request = controller.filteredRequests[index];
                  return _DeliveryCard(request: request);
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildTabChip(BuildContext context, DeliveryStatus? status, String label) {
    final isSelected = controller.selectedStatus.value == status;

    return GestureDetector(
      onTap: () => controller.selectedStatus.value = status,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeSystem.primaryColor : AppThemeSystem.grey100,
          borderRadius: context.borderRadius(BorderRadiusType.small),
          border: Border.all(
            color: isSelected ? AppThemeSystem.primaryColor : AppThemeSystem.grey300,
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
                      style: context.body2.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Commande #${request.orderId}',
                      style: context.caption.copyWith(color: context.secondaryTextColor),
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

          // Addresses
          _buildAddressRow(context, Icons.store, request.pickupAddress),
          const SizedBox(height: 6),
          _buildAddressRow(context, Icons.location_on, request.deliveryAddress),

          const SizedBox(height: 12),

          // Actions
          _buildActions(context),
        ],
      ),
    );
  }

  Widget _buildAddressRow(BuildContext context, IconData icon, String address) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.secondaryTextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: context.caption.copyWith(color: context.secondaryTextColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    if (request.status == DeliveryStatus.pending) {
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
              onPressed: () => controller.acceptRequest(request.id),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.successColor,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Accepter', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      );
    } else if (request.status == DeliveryStatus.inProgress) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => controller.callCustomer(request.customerPhone),
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
