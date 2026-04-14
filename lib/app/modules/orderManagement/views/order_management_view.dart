import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/order_management_controller.dart';
import '../widgets/filters_section.dart';
import '../widgets/order_card.dart';

class OrderManagementView extends GetView<OrderManagementController> {
  const OrderManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: context.primaryTextColor,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Gestion des commandes',
          style: context.h5.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Bouton rafraîchir
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: context.primaryTextColor,
            ),
            onPressed: controller.loadOrders,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.allOrders.isEmpty) {
          return _buildLoadingState(context);
        }

        return RefreshIndicator(
          onRefresh: controller.loadOrders,
          child: CustomScrollView(
            slivers: [
              // Statistiques rapides
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(context.horizontalPadding),
                  child: _buildQuickStats(context),
                ),
              ),

              // Section de filtres
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.horizontalPadding,
                  ),
                  child: const FiltersSection(),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(height: context.sectionSpacing),
              ),

              // Liste des commandes
              Obx(() {
                if (controller.filteredOrders.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(context),
                  );
                }

                return SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.horizontalPadding,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final order = controller.filteredOrders[index];
                        return OrderCard(
                          order: order,
                          onValidate: () => controller.validateOrder(order),
                          onCancel: () => controller.cancelOrder(order),
                          onChat: () => controller.openChat(order),
                          onContactDelivery: () => controller.contactDelivery(order),
                          onTap: () => controller.showOrderDetails(order),
                        );
                      },
                      childCount: controller.filteredOrders.length,
                    ),
                  ),
                );
              }),

              // Espace en bas
              SliverToBoxAdapter(
                child: SizedBox(height: context.sectionSpacing),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// Statistiques rapides
  Widget _buildQuickStats(BuildContext context) {
    return Obx(() {
      return Container(
        padding: EdgeInsets.all(context.horizontalPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppThemeSystem.primaryColor,
              AppThemeSystem.primaryColor.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          boxShadow: [
            BoxShadow(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.shopping_bag_outlined,
                label: 'Total',
                value: controller.allOrders.length.toString(),
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.access_time,
                label: 'En attente',
                value: controller
                    .allOrders
                    .where((order) => order.status.toString().contains('pending'))
                    .length
                    .toString(),
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            Expanded(
              child: _buildStatItem(
                context,
                icon: Icons.check_circle_outline,
                label: 'Validées',
                value: controller
                    .allOrders
                    .where((order) => order.status.toString().contains('validated'))
                    .length
                    .toString(),
              ),
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
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: context.h4.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// État de chargement
  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppThemeSystem.primaryColor,
          ),
          SizedBox(height: context.elementSpacing),
          Text(
            'Chargement des commandes...',
            style: context.body1.copyWith(
              color: context.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  /// État vide
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.horizontalPadding * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 60,
                color: AppThemeSystem.primaryColor,
              ),
            ),
            SizedBox(height: context.sectionSpacing),
            Text(
              'Aucune commande trouvée',
              style: context.h5.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.elementSpacing),
            Text(
              'Il n\'y a aucune commande correspondant à vos critères de recherche.',
              style: context.body2.copyWith(
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.sectionSpacing),
            if (controller.selectedStatus.value != null ||
                controller.selectedCity.value != 'Toutes les villes' ||
                controller.selectedDate.value != null ||
                controller.searchQuery.value.isNotEmpty)
              ElevatedButton.icon(
                onPressed: controller.resetFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Réinitialiser les filtres'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
