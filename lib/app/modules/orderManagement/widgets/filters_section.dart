import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_theme_system.dart';
import '../models/order_model.dart';
import '../controllers/order_management_controller.dart';
import '../../../core/utils/app_design.dart';

class FiltersSection extends GetView<OrderManagementController> {
  const FiltersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(context.horizontalPadding),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(
          color: context.borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec titre et bouton reset
          Row(
            children: [
              Icon(
                Icons.filter_list,
                color: AppThemeSystem.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Filtres',
                style: context.h6.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Obx(() {
                // Afficher le bouton reset seulement si des filtres sont actifs
                final hasFilters = controller.selectedStatus.value != null ||
                    controller.selectedCity.value != 'Toutes les villes' ||
                    controller.selectedDate.value != null ||
                    controller.searchQuery.value.isNotEmpty;

                if (!hasFilters) return const SizedBox.shrink();

                return TextButton.icon(
                  onPressed: controller.resetFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Réinitialiser'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppThemeSystem.errorColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                );
              }),
            ],
          ),

          SizedBox(height: context.elementSpacing),

          // Barre de recherche
          TextField(
            controller: controller.searchController,
            onChanged: (value) => controller.searchQuery.value = value,
            decoration: InputDecoration(
              hintText: 'Rechercher par nom, téléphone ou n° commande...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Obx(() {
                if (controller.searchQuery.value.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.searchController.clear();
                    controller.searchQuery.value = '';
                  },
                );
              }),
              border: OutlineInputBorder(
                borderRadius: context.borderRadius(BorderRadiusType.small),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),

          SizedBox(height: context.elementSpacing),

          // Filtre par statut
          _buildStatusFilter(context),

          SizedBox(height: context.elementSpacing),

          // Filtre par ville et date
          if (context.isTabletOrLarger)
            Row(
              children: [
                Expanded(child: _buildCityFilter(context)),
                SizedBox(width: context.elementSpacing),
                Expanded(child: _buildDateFilter(context)),
              ],
            )
          else ...[
            _buildCityFilter(context),
            SizedBox(height: context.elementSpacing),
            _buildDateFilter(context),
          ],

          // Compteur de résultats
          SizedBox(height: context.elementSpacing),
          Obx(() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
              borderRadius: context.borderRadius(BorderRadiusType.small),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppThemeSystem.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  '${controller.filteredOrders.length} commande(s) trouvée(s)',
                  style: context.caption.copyWith(
                    color: AppThemeSystem.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'État de la commande',
          style: context.body2.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip(
              context,
              label: 'Toutes',
              isSelected: controller.selectedStatus.value == null,
              onTap: () => controller.selectedStatus.value = null,
            ),
            _buildFilterChip(
              context,
              label: 'En attente',
              count: controller.getOrderCountByStatus(OrderStatus.pending),
              isSelected: controller.selectedStatus.value == OrderStatus.pending,
              onTap: () => controller.selectedStatus.value = OrderStatus.pending,
              color: AppThemeSystem.warningColor,
            ),
            _buildFilterChip(
              context,
              label: 'Validées',
              count: controller.getOrderCountByStatus(OrderStatus.validated),
              isSelected: controller.selectedStatus.value == OrderStatus.validated,
              onTap: () => controller.selectedStatus.value = OrderStatus.validated,
              color: AppThemeSystem.successColor,
            ),
            _buildFilterChip(
              context,
              label: 'Annulées',
              count: controller.getOrderCountByStatus(OrderStatus.cancelled),
              isSelected: controller.selectedStatus.value == OrderStatus.cancelled,
              onTap: () => controller.selectedStatus.value = OrderStatus.cancelled,
              color: AppThemeSystem.errorColor,
            ),
          ],
        )),
      ],
    );
  }

  Widget _buildCityFilter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ville',
          style: context.body2.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => DropdownButtonFormField<String>(
          value: controller.selectedCity.value,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.location_city, size: 20),
            border: OutlineInputBorder(
              borderRadius: context.borderRadius(BorderRadiusType.small),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          items: controller.availableCities.map((city) {
            return DropdownMenuItem(
              value: city,
              child: Text(
                city,
                style: context.body2,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              controller.selectedCity.value = value;
            }
          },
        )),
      ],
    );
  }

  Widget _buildDateFilter(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy', 'fr_FR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: context.body2.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Obx(() => InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: controller.selectedDate.value ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              locale: const Locale('fr', 'FR'),
            );
            if (date != null) {
              controller.selectedDate.value = date;
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: context.borderColor),
              borderRadius: context.borderRadius(BorderRadiusType.small),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: context.secondaryTextColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    controller.selectedDate.value != null
                        ? dateFormat.format(controller.selectedDate.value!)
                        : 'Toutes les dates',
                    style: context.body2,
                  ),
                ),
                if (controller.selectedDate.value != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    padding: EdgeInsets.zero,
                    // Cible tactile minimale conservée (recommandation Material/WCAG).
                      constraints: const BoxConstraints(
                        minWidth: AppDesign.minTapTarget,
                        minHeight: AppDesign.minTapTarget,
                      ),
                    onPressed: () => controller.selectedDate.value = null,
                  ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    int? count,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
  }) {
    final chipColor = color ?? AppThemeSystem.primaryColor;

    return InkWell(
      onTap: onTap,
      borderRadius: context.borderRadius(BorderRadiusType.small),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? chipColor
              : chipColor.withValues(alpha: 0.1),
          borderRadius: context.borderRadius(BorderRadiusType.small),
          border: Border.all(
            color: chipColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.caption.copyWith(
                color: isSelected ? Colors.white : chipColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : chipColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : chipColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
