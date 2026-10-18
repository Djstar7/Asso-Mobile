import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../data/models/maritime.dart';
import '../controllers/maritime_controller.dart';

/// Rubrique Maritime affichée dans Diaspo Exchange à la place des offres avion.
class MaritimeSection extends GetView<MaritimeController> {
  const MaritimeSection({super.key});

  @override
  Widget build(BuildContext context) {
    controller.ensureLoaded();
    final isDark = AppThemeSystem.isDarkMode(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Obx(
            () => SegmentedTabs(
              tabs: [
                SegmentedTab(label: 'maritime.tabs.departures'.tr, icon: Icons.directions_boat_outlined),
                SegmentedTab(label: 'maritime.tabs.my_shipments'.tr, icon: Icons.inventory_2_outlined),
              ],
              selectedIndex: controller.selectedTab.value,
              onChanged: controller.changeTab,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refreshAll,
            child: Obx(() => controller.selectedTab.value == 0
                ? _buildDepartures(context, isDark)
                : _buildMyBookings(context, isDark)),
          ),
        ),
      ],
    );
  }

  Color _card(bool isDark) => isDark ? AppThemeSystem.darkCardColor : Colors.white;
  Color _muted(bool isDark) => isDark ? Colors.white70 : AppDesign.neutral500;

  Widget _empty(IconData icon, String text, bool isDark) => ListView(
        children: [
          const SizedBox(height: 80),
          Icon(icon, size: 56, color: _muted(isDark)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: _muted(isDark))),
          ),
        ],
      );

  Widget _buildDepartures(BuildContext context, bool isDark) {
    if (controller.isLoading.value && controller.departures.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error.value != null && controller.departures.isEmpty) {
      return _empty(Icons.cloud_off, controller.error.value!, isDark);
    }
    if (controller.departures.isEmpty) {
      return _empty(Icons.directions_boat_outlined, 'maritime.no_departures'.tr, isDark);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) controller.loadMore();
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: controller.departures.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _departureCard(controller.departures[i], isDark),
      ),
    );
  }

  Widget _departureCard(MaritimeDeparture d, bool isDark) {
    final closed = !d.isBookable;
    final from = d.originHub;
    final to = d.destinationHub;

    return Opacity(
      opacity: closed ? 0.55 : 1,
      child: Material(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => controller.openDeparture(d),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.directions_boat, color: AppThemeSystem.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${from?.city ?? ''} → ${to?.city ?? ''}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${controller.formatAmount(d.pricePerKg, d.currency)}/kg',
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppThemeSystem.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(d.partnerName, style: TextStyle(fontSize: 12, color: _muted(isDark))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _info(Icons.event, 'maritime.departure_on'.trParams({'date': controller.formatDate(d.departureDate)}), isDark),
                    _info(Icons.scale_outlined, 'maritime.kg_left'.trParams({'kg': d.remainingKg.toStringAsFixed(0)}), isDark),
                    if (from != null) _info(Icons.warehouse_outlined, from.name, isDark),
                  ],
                ),
                const SizedBox(height: 10),
                closed
                    ? Text('maritime.trip_impossible'.tr,
                        style: const TextStyle(fontSize: 12, color: AppDesign.danger))
                    : Text(
                        d.daysLeftToBook == 0
                            ? 'maritime.last_day_to_book'.tr
                            : 'maritime.days_left_to_book'.trParams({'days': '${d.daysLeftToBook}'}),
                        style: const TextStyle(fontSize: 12, color: AppDesign.success, fontWeight: FontWeight.w600),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text, bool isDark) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _muted(isDark)),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: _muted(isDark))),
        ],
      );

  Widget _buildMyBookings(BuildContext context, bool isDark) {
    if (controller.isLoadingBookings.value && controller.myBookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.myBookings.isEmpty) {
      return _empty(Icons.inventory_2_outlined, 'maritime.no_shipments'.tr, isDark);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: controller.myBookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _bookingCard(controller.myBookings[i], isDark),
    );
  }

  Widget _bookingCard(MaritimeBooking b, bool isDark) {
    final d = b.departure;
    final color = switch (b.status) {
      'completed' => AppDesign.success,
      'cancelled' => AppDesign.danger,
      'paid' => AppDesign.accent,
      _ => AppDesign.info,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card(isDark), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${d?.originHub?.city ?? ''} → ${d?.destinationHub?.city ?? ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(b.statusLabel, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${b.kgBooked.toStringAsFixed(1)} kg · ${'maritime.parcels'.trParams({'count': '${b.parcelsCount}'})} · ${controller.formatAmount(b.totalPrice, b.currency)}',
            style: TextStyle(color: _muted(isDark)),
          ),
          Text('maritime.recipient_line'.trParams({'name': b.recipientName, 'phone': b.recipientPhone}),
              style: TextStyle(fontSize: 12, color: _muted(isDark))),
          if (b.status == 'paid' && d?.originHub != null && b.dropoffDeadline != null) ...[
            const SizedBox(height: 10),
            _notice(
              Icons.schedule,
              'maritime.dropoff_notice'.trParams({
                'hub': d!.originHub!.fullAddress,
                'date': controller.formatDate(b.dropoffDeadline!),
              }),
              AppDesign.accent,
            ),
          ],
          if (b.status == 'arrived' && d?.destinationHub != null) ...[
            const SizedBox(height: 10),
            _notice(Icons.place_outlined,
                'maritime.pickup_notice'.trParams({'hub': d!.destinationHub!.fullAddress}), AppDesign.info),
          ],
          if (b.status == 'cancelled' && b.refundedAmount != null) ...[
            const SizedBox(height: 10),
            _notice(Icons.account_balance_wallet_outlined,
                'maritime.refunded_notice'.trParams({'amount': controller.formatAmount(b.refundedAmount!, 'XAF')}),
                AppDesign.success),
          ],
          if (b.status != 'cancelled' && b.status != 'completed') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : AppDesign.neutral50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('maritime.code_label'.tr, style: TextStyle(fontSize: 11, color: _muted(isDark))),
                  const SizedBox(height: 4),
                  Text(b.confirmationCode,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
                  const SizedBox(height: 4),
                  Text('maritime.code_hint'.tr,
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _muted(isDark))),
                ],
              ),
            ),
          ],
          if (b.canCancel)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => controller.cancelBooking(b),
                icon: const Icon(Icons.close, size: 18, color: AppDesign.danger),
                label: Text('maritime.cancel_title'.tr, style: const TextStyle(color: AppDesign.danger)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notice(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.35))),
          ],
        ),
      );
}
