import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
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
                  // `hasScrollBody: false` laisse le bloc prendre sa hauteur
                  // naturelle et défiler avec la page. Sans cela, il était
                  // contraint à l'espace restant et débordait sous les
                  // filtres déployés.
                  return SliverToBoxAdapter(
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
        // Carte neutre plutôt qu'un aplat orange : ce bandeau affiche des
        // chiffres à lire, pas une action à déclencher. Les valeurs ressortent
        // par leur taille, et l'orange reste disponible pour les boutons.
        decoration: BoxDecoration(
          color: context.ds.surface,
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(color: context.ds.border),
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
              height: 36,
              color: context.ds.border,
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
              height: 36,
              color: context.ds.border,
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
          color: context.ds.textSecondary,
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.h4.copyWith(
            color: context.ds.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.caption.copyWith(
            color: context.ds.textSecondary,
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
    final hasFilters = controller.selectedStatus.value != null ||
        controller.selectedCity.value != 'Toutes les villes' ||
        controller.selectedDate.value != null ||
        controller.searchQuery.value.isNotEmpty;

    // Le message distingue « aucune commande » de « aucun résultat pour ces
    // filtres » : sans cette nuance, un vendeur croit n'avoir aucune vente
    // alors qu'il a simplement un filtre actif.
    return AppEmptyState(
      icon: Icons.inbox_outlined,
      title: hasFilters
          ? 'Aucune commande pour ces filtres'
          : 'Aucune commande pour le moment',
      message: hasFilters
          ? 'Aucune commande ne correspond à votre recherche.'
          : 'Vos commandes apparaîtront ici dès qu’un client aura acheté un de vos produits.',
      actionLabel: hasFilters ? 'Réinitialiser les filtres' : null,
      onAction: hasFilters ? controller.resetFilters : null,
    );
  }
}
