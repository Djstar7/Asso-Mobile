import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/delivery_details_widgets.dart';
import '../../../data/models/delivery_info.dart';
import '../controllers/tracking_controller.dart';
import '../../../core/utils/app_design.dart';

class TrackingView extends GetView<TrackingController> {
  const TrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      // Onglet de l'accueil, la barre du haut et la navigation basse suffisent.
      // Ouvert depuis une commande, l'écran a besoin de son titre et de sa
      // sortie : sans barre, rien ne ramenait à la commande.
      appBar: AppNavigation.isHomeTab(context)
          ? null
          : AppBar(
              leading: const AppBackButton(),
              title: Text(
                'tracking.title'.tr,
                style: context.h5.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
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
                  // Faire défiler les commandes referme le clavier de la
                  // recherche, qui en masquait la moitié.
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
      padding: EdgeInsets.only(
        left: AppThemeSystem.getHorizontalPadding(context),
        right: AppThemeSystem.getHorizontalPadding(context),
        // top: MediaQuery.of(context).padding.top + 8,
        bottom: AppThemeSystem.getHorizontalPadding(context),
      ),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        border: Border(
          bottom: BorderSide(color: AppThemeSystem.getBorderColor(context).withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Le libellé de l'onglet actif sert déjà de titre dans la barre
          // du haut ; le répéter ici consommait une ligne pour rien.
          const Spacer(),
          GestureDetector(
            onTap: () async {
              await controller.loadOrders();
              Get.snackbar(
                'tracking.refreshed_title'.tr,
                'tracking.refreshed_message'.tr,
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 1),
              );
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.refresh_rounded, color: AppThemeSystem.primaryColor, size: 24),
            ),
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
          hintText: 'tracking.search_hint'.tr,
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
                child: Text(filter.tr,
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
                    Text('tracking.ordered_on'.trParams({'date': '${shipment['orderDate']}'}),
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
                      Get.snackbar('tracking.copied_title'.tr, 'tracking.code_copied'.tr, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppDesign.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppDesign.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.key_rounded, color: AppDesign.warning, size: 18),
                          const SizedBox(width: 8),
                          Text('Code: ',
                            style: context.textStyle(FontSizeType.body2, color: AppDesign.warning)),
                          Text(shipment['confirmationCode'],
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppDesign.warning)),
                        ],
                      ),
                    ),
                  ),
                ],

                if (shipment['delivery'] is DeliveryInfo &&
                    (shipment['delivery'] as DeliveryInfo).carrierTrackingNumber != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 16, color: AppThemeSystem.grey600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Suivi ${(shipment['delivery'] as DeliveryInfo).companyName ?? ''} : ${(shipment['delivery'] as DeliveryInfo).carrierTrackingNumber}',
                          style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],

                if (rawStatus == 'delivered') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppDesign.success),
                      const SizedBox(width: 6),
                      Text('tracking.delivered_on'.trParams({'date': '${shipment['deliveredDate'] ?? ''}'}),
                        style: context.textStyle(FontSizeType.caption, color: AppDesign.success, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],

                if (rawStatus == 'cancelled') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.cancel_rounded, size: 16, color: AppDesign.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('tracking.cancel_reason'.trParams({'reason': '${shipment['cancelReason'] ?? 'tracking.reason_unspecified'.tr}'}),
                          style: context.textStyle(FontSizeType.caption, color: AppDesign.danger)),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildChatButton(context, shipment),
                    Row(
                      children: [
                        Text('tracking.view_tracking'.tr,
                          style: context.textStyle(FontSizeType.body2, color: AppThemeSystem.primaryColor, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: AppThemeSystem.primaryColor),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bouton discret pour écrire un message à propos de la commande.
  /// Ouvre une conversation avec le vendeur si disponible, sinon avec le
  /// support ASSO. Réservé aux utilisateurs connectés (garde défensive).
  Widget _buildChatButton(BuildContext context, Map<String, dynamic> shipment) {
    return Obx(() {
      final isLoading = controller.openingChatOrderId.value == (shipment['id']?.toString() ?? '');
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: isLoading
              ? null
              : () {
                  // Garde d'auth défensive même si la page est réservée aux connectés.
                  if (!AuthGuard.checkAuthWithAlert(context, featureName: 'la messagerie')) {
                    return;
                  }
                  controller.openConversationForOrder(shipment);
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppThemeSystem.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppThemeSystem.primaryColor),
                  )
                else
                  Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppThemeSystem.primaryColor),
                const SizedBox(width: 6),
                Text('tracking.message'.tr,
                  style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.primaryColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildProductImage(String? imageUrl, double size) {
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        // Décodée à la taille de la vignette, pas en pleine résolution.
        child: Image(
          image: AppNetworkImage.provider(
            Get.context!,
            imageUrl,
            Size.square(size),
          ),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderImage(size),
        ),
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
          Text('tracking.empty.title'.tr, style: context.textStyle(FontSizeType.h5, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('tracking.empty.message'.tr,
            style: context.textStyle(FontSizeType.body2, color: AppThemeSystem.grey600)),
        ],
      ),
    );
  }

  void _showTrackingDetails(BuildContext context, Map<String, dynamic> shipment) {
    final delivery = shipment['delivery'] is DeliveryInfo ? shipment['delivery'] as DeliveryInfo : null;
    // Feuille standard : elle prend la hauteur de son contenu (bornée sous la
    // barre d'état) au lieu d'occuper d'office 85 % de l'écran.
    AppSheet.show(
      AppSheet(
        title: 'tracking.sheet_title'.tr,
        color: AppThemeSystem.getBackgroundColor(context),
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
                  color: AppDesign.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDesign.warning.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.key_rounded, color: AppDesign.warning, size: 20),
                        const SizedBox(width: 8),
                        Text('tracking.confirmation_code'.tr, style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600, color: AppDesign.warning)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(shipment['confirmationCode'],
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8, color: AppDesign.warning)),
                    const SizedBox(height: 8),
                    Text('tracking.code_hint'.tr,
                      style: context.textStyle(FontSizeType.caption, color: AppDesign.warning)),
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
                          Text('tracking.your_courier'.tr, style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
                          Text(shipment['deliveryPersonName'], style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (shipment['deliveryPersonPhone'] != null)
                      IconButton(
                        icon: const Icon(Icons.phone, color: AppDesign.success),
                        onPressed: () {},
                      ),
                  ],
                ),
              ),
            ],

            if (delivery != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppThemeSystem.getSurfaceColor(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('tracking.delivery'.tr, style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    OrderDeliveryDetails(
                      delivery: delivery,
                      deliveryFee: shipment['deliveryFee'] as double?,
                      freeDeliveryAmount:
                          shipment['freeDeliveryAmount'] as double? ?? 0,
                      formatPrice: (v) => controller.formatPrice(v),
                      showTimeline: false,
                    ),
                  ],
                ),
              ),
            ],

            if (delivery?.canConfirmReception == true) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final done = await controller.confirmReception(shipment);
                    if (done) Get.back();
                  },
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: Text('tracking.received_parcel'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text('tracking.delivery_tracking'.tr, style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (delivery != null && delivery.timeline.isNotEmpty)
              DeliveryTimelineView(steps: delivery.timeline)
            else
              _buildTrackingTimeline(context, shipment['trackingSteps']),
          ],
        ),
      ),
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
                      Text('tracking.delivery_address'.tr, style: context.textStyle(FontSizeType.caption, color: AppThemeSystem.grey600)),
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
