import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/format_cbm.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../data/models/maritime.dart';
import '../controllers/maritime_controller.dart';
import 'maritime_contact_button.dart';
import 'freight_inquiries_view.dart';

/// Offres des partenaires, filtrées par transport aérien ou maritime.
class MaritimeSection extends GetView<MaritimeController> {
  const MaritimeSection({
    super.key,
    this.transportMode = 'sea',
    this.pageController,
  });

  final MaritimeController? pageController;

  @override
  MaritimeController get controller => pageController ?? super.controller;

  final String transportMode;

  @override
  Widget build(BuildContext context) {
    controller.ensureLoaded(transportMode: transportMode);
    final isDark = AppThemeSystem.isDarkMode(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Obx(
            () => SegmentedTabs(
              tabs: [
                SegmentedTab(
                  label: 'maritime.tabs.departures'.tr,
                  icon: transportMode == 'air'
                      ? Icons.flight_takeoff
                      : Icons.directions_boat_outlined,
                ),
                SegmentedTab(
                  label: 'maritime.tabs.my_shipments'.tr,
                  icon: Icons.inventory_2_outlined,
                ),
                if (transportMode == 'sea')
                  SegmentedTab(
                    label: 'freight_quote.tab'.tr,
                    icon: Icons.request_quote_outlined,
                  ),
              ],
              selectedIndex:
                  transportMode == 'air' && controller.selectedTab.value == 2
                  ? 0
                  : controller.selectedTab.value,
              onChanged: controller.changeTab,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refreshAll,
            child: Obx(
              () => controller.selectedTab.value == 2 && transportMode == 'sea'
                  ? const FreightInquiriesView()
                  : (controller.selectedTab.value == 0 ||
                        transportMode == 'air' &&
                            controller.selectedTab.value == 2)
                  ? _buildDepartures(context, isDark)
                  : _buildMyBookings(context, isDark),
            ),
          ),
        ),
      ],
    );
  }

  Color _card(bool isDark) =>
      isDark ? AppThemeSystem.darkCardColor : Colors.white;
  Color _muted(bool isDark) => isDark ? Colors.white70 : AppDesign.neutral500;

  Widget _empty(IconData icon, String text, bool isDark) => ListView(
    children: [
      const SizedBox(height: 80),
      Icon(icon, size: 56, color: _muted(isDark)),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted(isDark)),
        ),
      ),
    ],
  );

  Widget _buildDepartures(BuildContext context, bool isDark) {
    final departures = controller.filteredDepartures
        .where((d) => d.transportMode == transportMode)
        .toList();
    return Column(
      children: [
        _buildDepartureSearch(isDark),
        _buildDepartureFilters(isDark),
        Expanded(
          child: controller.isLoading.value && controller.departures.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : controller.error.value != null && controller.departures.isEmpty
              ? _empty(Icons.cloud_off, controller.error.value!, isDark)
              : controller.departures.isEmpty
              ? _empty(
                  Icons.directions_boat_outlined,
                  'maritime.no_departures'.tr,
                  isDark,
                )
              : departures.isEmpty
              ? _empty(
                  Icons.search_off,
                  'maritime.no_departure_matches'.tr,
                  isDark,
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) {
                      controller.loadMore();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount:
                        departures.length +
                        (controller.isLoadingMore.value ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i == departures.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return _departureCard(departures[i], isDark);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDepartureSearch(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          onChanged: (value) => controller.departureSearchQuery.value = value,
          decoration: InputDecoration(
            hintText: 'maritime.search_hint'.tr,
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.grey[500],
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: isDark ? Colors.white54 : Colors.grey[500],
            ),
            suffixIcon: Obx(
              () => controller.departureSearchQuery.value.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          controller.departureSearchQuery.value = '',
                    )
                  : const SizedBox.shrink(),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartureFilters(bool isDark) {
    return SizedBox(
      height: 54,
      child: Obx(
        () => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          scrollDirection: Axis.horizontal,
          children: [
            _departureFilterChip(
              label: 'maritime.filter_all'.tr,
              selected: !controller.bookableDeparturesOnly.value,
              isDark: isDark,
              onTap: () => controller.bookableDeparturesOnly.value = false,
            ),
            const SizedBox(width: 8),
            _departureFilterChip(
              label: 'maritime.filter_bookable'.tr,
              selected: controller.bookableDeparturesOnly.value,
              isDark: isDark,
              onTap: () => controller.bookableDeparturesOnly.value = true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _departureFilterChip({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final color = selected
        ? AppThemeSystem.primaryColor
        : (isDark ? AppThemeSystem.darkCardColor : Colors.white);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color,
      backgroundColor: color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : _muted(isDark),
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? AppThemeSystem.primaryColor : AppDesign.neutral200,
      ),
    );
  }

  Widget _departureCard(MaritimeDeparture d, bool isDark) {
    final closed = !d.isBookable;
    final from = d.originHub;
    final to = d.destinationHub;

    return Opacity(
      opacity: closed ? 0.85 : 1,
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
                Text(
                  d.commercialSummary,
                  style: TextStyle(color: _muted(isDark), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      d.transportMode == 'air'
                          ? Icons.flight
                          : Icons.directions_boat,
                      color: AppThemeSystem.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${from?.city ?? ''} → ${to?.city ?? ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      d.requiresQuote
                          ? 'freight_quote.on_request'.tr
                          : '${controller.formatAmount(d.isSea ? d.publicCbmRate : d.pricePerKg, d.currency)}/${d.isSea ? 'CBM' : 'kg'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppThemeSystem.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Diaspo Exchange',
                  style: TextStyle(fontSize: 12, color: _muted(isDark)),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _info(
                      Icons.event,
                      'maritime.departure_on'.trParams({
                        'date': controller.formatDate(d.departureDate),
                      }),
                      isDark,
                    ),
                    _info(
                      Icons.scale_outlined,
                      (d.isSea ? 'maritime.cbm_left' : 'maritime.kg_left')
                          .trParams({
                            'volume': formatCbm(d.remainingCbm),
                            'kg': d.remainingKg.toStringAsFixed(0),
                          }),
                      isDark,
                    ),
                    if (from != null)
                      _info(Icons.warehouse_outlined, from.name, isDark),
                  ],
                ),
                const SizedBox(height: 10),
                closed
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppDesign.neutral100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: _muted(isDark),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'maritime.reservations_closed'.tr,
                              style: TextStyle(
                                fontSize: 12,
                                color: _muted(isDark),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        d.daysLeftToBook == 0
                            ? 'maritime.last_day_to_book'.tr
                            : 'maritime.days_left_to_book'.trParams({
                                'days': '${d.daysLeftToBook}',
                              }),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppDesign.success,
                          fontWeight: FontWeight.w600,
                        ),
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
    final bookings = controller.myBookings
        .where(
          (booking) =>
              (booking.departure?.transportMode ?? 'sea') == transportMode,
        )
        .toList();
    if (controller.isLoadingBookings.value && bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (bookings.isEmpty) {
      return _empty(
        Icons.inventory_2_outlined,
        'maritime.no_shipments'.tr,
        isDark,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => buildBookingCard(bookings[i], isDark),
    );
  }

  Widget buildBookingCard(MaritimeBooking b, bool isDark) {
    final d = b.departure;
    final color = switch (b.status) {
      'completed' => AppDesign.success,
      'cancelled' => AppDesign.danger,
      'paid' => AppDesign.accent,
      _ => AppDesign.info,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${d?.originHub?.city ?? ''} → ${d?.destinationHub?.city ?? ''}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  b.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${b.departure?.isSea == true ? formatCbm(b.kgBooked / (b.departure?.kgPerCbm ?? 1000)) : b.kgBooked.toStringAsFixed(1)} ${b.departure?.isSea == true ? 'CBM' : 'kg'} · ${'maritime.parcels'.trParams({'count': '${b.parcelsCount}'})} · ${controller.formatAmount(b.freightTotal, b.currency)}',
            style: TextStyle(color: _muted(isDark)),
          ),
          Text(
            'maritime.recipient_line'.trParams({
              'name': b.recipientName,
              'phone': b.recipientPhone,
            }),
            style: TextStyle(fontSize: 12, color: _muted(isDark)),
          ),
          if (b.insuranceOptIn ||
              (b.insuranceStatus?.isNotEmpty ?? false) ||
              b.claimSummary != null ||
              b.claimHistory.isNotEmpty ||
              b.insuranceHistory.isNotEmpty) ...[
            const SizedBox(height: 10),
            _insuranceDetails(b, isDark),
          ],
          if (b.status == 'paid' &&
              d?.originHub != null &&
              b.dropoffDeadline != null) ...[
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
            _notice(
              Icons.place_outlined,
              'maritime.pickup_notice'.trParams({
                'hub': d!.destinationHub!.fullAddress,
              }),
              AppDesign.info,
            ),
          ],
          if (b.status == 'cancelled' && b.refundedAmount != null) ...[
            const SizedBox(height: 10),
            _notice(
              Icons.account_balance_wallet_outlined,
              'maritime.refunded_notice'.trParams({
                'amount': controller.formatAmount(b.refundedAmount!, 'XAF'),
              }),
              AppDesign.success,
            ),
          ],
          if (b.status != 'cancelled' && b.status != 'completed') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppDesign.neutral50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    'maritime.code_label'.tr,
                    style: TextStyle(fontSize: 11, color: _muted(isDark)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b.confirmationCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'maritime.code_hint'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: _muted(isDark)),
                  ),
                ],
              ),
            ),
          ],
          if (b.canCancel)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => controller.cancelBooking(b),
                icon: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppDesign.danger,
                ),
                label: Text(
                  'maritime.cancel_title'.tr,
                  style: const TextStyle(color: AppDesign.danger),
                ),
              ),
            ),
          if (b.canReportLoss)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => controller.reportLoss(b),
                icon: const Icon(Icons.report_problem_outlined, size: 18),
                label: Text('maritime.claim.report_action'.tr),
              ),
            ),
          const SizedBox(height: 10),
          MaritimeContactButton(booking: b, controller: controller),
        ],
      ),
    );
  }

  Widget _insuranceDetails(MaritimeBooking booking, bool isDark) {
    final summary = booking.claimSummary;
    final payout =
        summary?['payout_amount'] ?? summary?['insurance_payout_amount'];
    final claimStatus = summary?['status_label'] ?? summary?['status'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppDesign.neutral50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (booking.insuranceOptIn)
            Text(
              'maritime.insurance.insured'.tr,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          if (booking.insuranceStatus case final status? when status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'maritime.insurance.status'.trParams({'status': status}),
                style: TextStyle(fontSize: 12, color: _muted(isDark)),
              ),
            ),
          if (booking.insuranceOptIn)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'maritime.insurance.paid'.trParams({
                  'amount': controller.formatAmount(
                    booking.insuranceAmount,
                    booking.currency,
                  ),
                }),
                style: TextStyle(fontSize: 12, color: _muted(isDark)),
              ),
            ),
          if (payout != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'maritime.insurance.payout'.trParams({
                  'amount': controller.formatAmount(
                    double.tryParse(payout.toString()) ?? 0,
                    booking.currency,
                  ),
                }),
                style: const TextStyle(
                  color: AppDesign.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (claimStatus != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'maritime.claim.status'.trParams({
                  'status': claimStatus.toString(),
                }),
                style: TextStyle(fontSize: 12, color: _muted(isDark)),
              ),
            ),
          for (final claim in booking.claimHistory)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'maritime.claim.history_item'.trParams({
                  'status': (claim['status_label'] ?? claim['status'] ?? '')
                      .toString(),
                  'date': controller.formatHistoryDate(claim['created_at']),
                }),
                style: TextStyle(fontSize: 12, color: _muted(isDark)),
              ),
            ),
          for (final insurance in booking.insuranceHistory)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'maritime.insurance.history_item'.trParams({
                  'status':
                      (insurance['status_label'] ??
                              insurance['status'] ??
                              insurance['event'] ??
                              '')
                          .toString(),
                  'date': controller.formatHistoryDate(insurance['created_at']),
                }),
                style: TextStyle(fontSize: 12, color: _muted(isDark)),
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
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color, height: 1.35),
          ),
        ),
      ],
    ),
  );
}
