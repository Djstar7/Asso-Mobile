import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/tracking_controller.dart';

class TrackingView extends GetView<TrackingController> {
  const TrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildSearchBar(context),
          const SizedBox(height: 12),
          _buildFilters(context),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final shipments = controller.filteredShipments;

              if (shipments.isEmpty) {
                return _buildEmptyState(context);
              }

              return RefreshIndicator(
                onRefresh: () => controller.loadOrders(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: shipments.length,
                  itemBuilder: (context, index) {
                    return _buildShipmentCard(context, shipments[index]);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    return Container(
      padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppThemeSystem.getBorderColor(context).withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Text('Suivi de commandes',
            style: context.textStyle(FontSizeType.h4, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: AppThemeSystem.primaryColor),
            onPressed: () => controller.loadOrders(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller.searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher par numéro de commande...',
          hintStyle: context.textStyle(FontSizeType.body2, color: AppThemeSystem.grey600),
          prefixIcon: Icon(Icons.search_rounded, color: AppThemeSystem.grey600),
          suffixIcon: Obx(() => controller.searchQuery.value.isNotEmpty
              ? IconButton(icon: Icon(Icons.clear_rounded, color: AppThemeSystem.grey600), onPressed: controller.clearSearch)
              : const SizedBox.shrink()),
          filled: true,
          fillColor: AppThemeSystem.getSurfaceColor(context),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: context.textStyle(FontSizeType.body2),
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: controller.filters.length,
        itemBuilder: (context, index) {
          final filter = controller.filters[index];
          return Obx(() {
            final isSelected = controller.selectedFilter.value == filter;
            return GestureDetector(
              onTap: () => controller.selectFilter(filter),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isSelected ? AppThemeSystem.primaryColor : AppThemeSystem.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: isSelected ? AppThemeSystem.primaryColor : AppThemeSystem.getBorderColor(context)),
                ),
                alignment: Alignment.center,
                child: Text(filter,
                  style: context.textStyle(FontSizeType.body2,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : null)),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildShipmentCard(BuildContext context, Map<String, dynamic> shipment) {
    final statusColor = Color(shipment['statusColor']);
    final rawStatus = shipment['rawStatus'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showTrackingDetails(context, shipment),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(shipment['status'],
                        style: context.textStyle(FontSizeType.caption, fontWeight: FontWeight.w600, color: statusColor)),
                    ),
                    const Spacer(),
                    Text(shipment['id'],
                      style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600, fontWeight: FontWeight.w600)),
                  ],
                ),

                const SizedBox(height: 12),

                // Produit
                Row(
                  children: [
                    _buildProductImage(shipment['productImage'], 60),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(shipment['productName'],
                            style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                          if ((shipment['deliveryCompany'] ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.local_shipping_rounded, size: 14, color: AppThemeSystem.grey600),
                                const SizedBox(width: 4),
                                Text(shipment['deliveryCompany'],
                                  style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Infos selon statut
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: AppThemeSystem.grey600),
                    const SizedBox(width: 6),
                    Text('Commandé le ${shipment['orderDate']}',
                      style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
                  ],
                ),

                if (rawStatus == 'shipped' || rawStatus == 'confirmed' || rawStatus == 'preparing') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 16, color: AppThemeSystem.primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(shipment['currentLocation'],
                          style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.primaryColor, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],

                // Code de confirmation visible quand shipped
                if (rawStatus == 'shipped' && shipment['confirmationCode'] != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: shipment['confirmationCode']));
                      Get.snackbar('Copié', 'Code copié', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.key_rounded, color: Colors.amber.shade800, size: 18),
                          const SizedBox(width: 8),
                          Text('Code: ',
                            style: context.textStyle(FontSizeType.body2, color: Colors.amber.shade800)),
                          Text(shipment['confirmationCode'],
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.amber.shade800)),
                        ],
                      ),
                    ),
                  ),
                ],

                if (rawStatus == 'delivered') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Text('Livré le ${shipment['deliveredDate'] ?? ''}',
                        style: context.textStyle(FontSizeType.caption, color: Colors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],

                if (rawStatus == 'cancelled') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.cancel_rounded, size: 16, color: Colors.red),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Raison: ${shipment['cancelReason'] ?? 'Non spécifiée'}',
                          style: context.textStyle(FontSizeType.caption, color: Colors.red)),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Voir le suivi',
                      style: context.textStyle(FontSizeType.body2, color: AppThemeSystem.primaryColor, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: AppThemeSystem.primaryColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl, double size) {
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(imageUrl, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderImage(size)),
      );
    }
    return _buildPlaceholderImage(size);
  }

  Widget _buildPlaceholderImage(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: AppThemeSystem.grey200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.shopping_bag_outlined, color: AppThemeSystem.grey400, size: size * 0.5),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_shipping_outlined, size: 64, color: AppThemeSystem.primaryColor),
          ),
          const SizedBox(height: 24),
          Text('Aucune commande', style: context.textStyle(FontSizeType.h5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Vos commandes apparaîtront ici',
            style: context.textStyle(FontSizeType.body2, color: AppThemeSystem.grey600)),
        ],
      ),
    );
  }

  void _showTrackingDetails(BuildContext context, Map<String, dynamic> shipment) {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.85,
        decoration: BoxDecoration(
          color: AppThemeSystem.getBackgroundColor(context),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppThemeSystem.grey300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text('Suivi de commande', style: context.textStyle(FontSizeType.h5, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Get.back()),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOrderInfo(context, shipment),

                    // Code confirmation dans les détails
                    if (shipment['rawStatus'] == 'shipped' && shipment['confirmationCode'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.key_rounded, color: Colors.amber.shade800, size: 20),
                                const SizedBox(width: 8),
                                Text('Code de confirmation', style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(shipment['confirmationCode'],
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.amber.shade800)),
                            const SizedBox(height: 8),
                            Text('Communiquez ce code au livreur',
                              style: context.textStyle(FontSizeType.caption, color: Colors.amber.shade800)),
                          ],
                        ),
                      ),
                    ],

                    // Livreur info
                    if (shipment['deliveryPersonName'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppThemeSystem.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
                              child: Icon(Icons.person, color: AppThemeSystem.primaryColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Votre livreur', style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
                                  Text(shipment['deliveryPersonName'], style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            if (shipment['deliveryPersonPhone'] != null)
                              IconButton(
                                icon: const Icon(Icons.phone, color: Colors.green),
                                onPressed: () {},
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text('Suivi de livraison', style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTrackingTimeline(context, shipment['trackingSteps']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _buildOrderInfo(BuildContext context, Map<String, dynamic> shipment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppThemeSystem.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildProductImage(shipment['productImage'], 80),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shipment['productName'], style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600)),
                    if ((shipment['deliveryCompany'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(shipment['deliveryCompany'], style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
                    ],
                    const SizedBox(height: 8),
                    Text(shipment['price'], style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.bold, color: AppThemeSystem.primaryColor)),
                  ],
                ),
              ),
            ],
          ),
          if (shipment['deliveryAddress'] != null && (shipment['deliveryAddress'] as String).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.location_on_rounded, size: 20, color: AppThemeSystem.grey600),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Adresse de livraison', style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
                      const SizedBox(height: 4),
                      Text(shipment['deliveryAddress'], style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingTimeline(BuildContext context, List<dynamic> steps) {
    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        final isCompleted = step['completed'] == true;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppThemeSystem.primaryColor : AppThemeSystem.grey300,
                    shape: BoxShape.circle,
                  ),
                  child: isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
                if (!isLast)
                  Container(width: 2, height: 40, color: isCompleted ? AppThemeSystem.primaryColor : AppThemeSystem.grey300),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step['title'],
                      style: context.textStyle(FontSizeType.body2,
                        fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                        color: isCompleted ? null : AppThemeSystem.grey600)),
                    const SizedBox(height: 4),
                    Text(step['date'], style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
