import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../storeManagement/models/store_models.dart';
import '../controllers/inventory_list_controller.dart';

class InventoryListView extends GetView<InventoryListController> {
  const InventoryListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: context.primaryTextColor,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Historique d\'inventaire',
          style: context.h5.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filtres
          _buildFilters(context),
          SizedBox(height: context.elementSpacing),

          // Liste complète
          Expanded(
            child: Obx(() {
              final entries = controller.filteredInventory;

              if (entries.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: context.horizontalPadding,
                  vertical: context.verticalPadding,
                ),
                itemCount: entries.length,
                separatorBuilder: (context, index) => SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _buildInventoryItem(context, entry);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: context.horizontalPadding),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Obx(() => _FilterChip(
            label: 'Tout',
            isSelected: controller.selectedFilter.value == null,
            onTap: () => controller.changeFilter(null),
          )),
          SizedBox(width: 8),
          Obx(() => _FilterChip(
            label: 'Entrées',
            isSelected: controller.selectedFilter.value == InventoryType.entry,
            onTap: () => controller.changeFilter(InventoryType.entry),
          )),
          SizedBox(width: 8),
          Obx(() => _FilterChip(
            label: 'Sorties',
            isSelected: controller.selectedFilter.value == InventoryType.exit,
            onTap: () => controller.changeFilter(InventoryType.exit),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.horizontalPadding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    AppThemeSystem.tertiaryColor.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: context.sectionSpacing),
            Text(
              'Aucune entrée d\'inventaire',
              style: context.h4.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.elementSpacing),
            Text(
              'Vos entrées et sorties de stock\napparaîtront ici',
              style: context.body2.copyWith(
                color: context.secondaryTextColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItem(BuildContext context, InventoryEntry entry) {
    final isEntry = entry.type == InventoryType.entry;

    return InkWell(
      onTap: () => controller.viewEntryDetails(entry),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.borderColor,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isEntry
                    ? AppThemeSystem.successColor.withValues(alpha: 0.1)
                    : AppThemeSystem.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEntry ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: isEntry ? AppThemeSystem.successColor : AppThemeSystem.errorColor,
                size: 24,
              ),
            ),
            SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.productName,
                    style: context.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        entry.type.label,
                        style: context.caption.copyWith(
                          color: isEntry
                              ? AppThemeSystem.successColor
                              : AppThemeSystem.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '•',
                        style: context.caption,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _formatDate(entry.date),
                        style: context.caption,
                      ),
                    ],
                  ),
                  if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      entry.notes!,
                      style: context.caption.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Quantité
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isEntry
                    ? AppThemeSystem.successColor.withValues(alpha: 0.1)
                    : AppThemeSystem.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${isEntry ? '+' : '-'}${entry.quantity}',
                style: context.body1.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isEntry ? AppThemeSystem.successColor : AppThemeSystem.errorColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppThemeSystem.primaryColor : AppThemeSystem.grey100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppThemeSystem.primaryColor : AppThemeSystem.grey300,
          ),
        ),
        child: Text(
          label,
          style: context.caption.copyWith(
            color: isSelected ? Colors.white : context.secondaryTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
