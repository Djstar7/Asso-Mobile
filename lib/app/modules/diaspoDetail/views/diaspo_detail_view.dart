import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/diaspo_detail_controller.dart';
import '../../../core/widgets/scoped_controller_page.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_ui.dart';

/// Page ouverte par la route : chaque offre empilée a son propre
/// [DiaspoDetailController] (voir [ScopedControllerPage]).
class DiaspoDetailPage extends StatelessWidget {
  const DiaspoDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScopedControllerPage<DiaspoDetailController>(
      create: DiaspoDetailController.new,
      builder: (controller) => DiaspoDetailView(pageController: controller),
    );
  }
}

class DiaspoDetailView extends GetView<DiaspoDetailController> {
  const DiaspoDetailView({super.key, this.pageController});

  /// Contrôleur propre à la page ; sans lui, celui enregistré dans GetX.
  final DiaspoDetailController? pageController;

  @override
  DiaspoDetailController get controller => pageController ?? super.controller;

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : AppDesign.neutral50,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('diaspo_detail.title'.tr),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final offer = controller.offer.value;
        if (offer == null) {
          return Center(child: Text('diaspo_detail.not_found'.tr));
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserCard(context, offer, isDark),
                    const SizedBox(height: 16),
                    if (!offer.profileVerified) ...[
                      _buildUnverifiedNotice(offer, isDark),
                      const SizedBox(height: 16),
                    ],
                    _buildRouteCard(context, offer, isDark),
                    const SizedBox(height: 16),
                    _buildDatesCard(context, offer, isDark),
                    const SizedBox(height: 16),
                    _buildPricingCard(context, offer, isDark),
                  ],
                ),
              ),
            ),
            _buildActionButtons(context, isDark),
          ],
        );
      }),
    );
  }

  // --- Helpers de style partagés ---
  Color _card(bool isDark) => isDark ? AppThemeSystem.darkCardColor : Colors.white;
  Color _muted(bool isDark) => isDark ? Colors.white70 : AppDesign.neutral500;
  Color _titleColor(bool isDark) => isDark ? Colors.white : AppDesign.neutral900;

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : AppDesign.neutral200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      );

  Widget _sectionTitle(String text, bool isDark) => Text(
        text,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _titleColor(isDark)),
      );

  /// Carte voyageur
  Widget _buildUserCard(BuildContext context, offer, bool isDark) {
    final verified = offer.profileVerified;
    const unverifiedColor = AppDesign.accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(isDark),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppThemeSystem.primaryColor,
            child: Text(
              (offer.user?.firstName?.isNotEmpty == true
                  ? offer.user!.firstName[0].toUpperCase()
                  : '?'),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        offer.user?.fullName ?? 'diaspo_detail.anonymous'.tr,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _titleColor(isDark)),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 18, color: AppDesign.info),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (verified ? AppDesign.success : unverifiedColor).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    verified
                        ? 'diaspo_detail.verified_traveler'.tr
                        : 'diaspo_detail.unverified_profile'.tr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: verified ? AppDesign.success : unverifiedColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Explication de la mention « Profil non vérifié » (acheteur ou voyageur).
  Widget _buildUnverifiedNotice(offer, bool isDark) {
    const color = AppDesign.accent;
    final deadline = offer.formattedVerificationDeadline;
    final text = controller.isMyOffer.value
        ? '${'diaspo_detail.notice.owner'.tr} '
            '${deadline != null ? 'diaspo_detail.notice.owner_deadline'.trParams({'date': '$deadline'}) : 'diaspo_detail.notice.owner_no_deadline'.tr}'
        : 'diaspo_detail.notice.buyer'.tr;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gpp_maybe_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('diaspo_detail.unverified_profile'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(text, style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte itinéraire (timeline)
  Widget _buildRouteCard(BuildContext context, offer, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('diaspo_detail.route'.tr, isDark),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.flight_takeoff, color: AppDesign.success, size: 22),
                  Container(
                    width: 2,
                    height: 30,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: _muted(isDark).withValues(alpha: 0.3),
                  ),
                  const Icon(Icons.flight_land, color: AppDesign.danger, size: 22),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('diaspo_detail.departure'.tr, style: TextStyle(fontSize: 11, color: _muted(isDark))),
                    const SizedBox(height: 2),
                    Text('${offer.departureCity}, ${offer.departureCountry}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _titleColor(isDark))),
                    const SizedBox(height: 18),
                    Text('diaspo_detail.arrival'.tr, style: TextStyle(fontSize: 11, color: _muted(isDark))),
                    const SizedBox(height: 2),
                    Text('${offer.arrivalCity}, ${offer.arrivalCountry}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _titleColor(isDark))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Carte dates
  Widget _buildDatesCard(BuildContext context, offer, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('diaspo_detail.dates'.tr, isDark),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today_outlined, 'diaspo_detail.departure'.tr, _formatDateTime(offer.departureDateTime), isDark),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.event_available_outlined, 'diaspo_detail.arrival'.tr, _formatDateTime(offer.arrivalDateTime), isDark),
          if (offer.tripDurationHours != null) ...[
            const SizedBox(height: 14),
            _buildInfoRow(Icons.schedule, 'diaspo_detail.trip_duration'.tr, 'diaspo_detail.hours'.trParams({'hours': '${offer.tripDurationHours?.toStringAsFixed(1)}'}), isDark),
          ],
        ],
      ),
    );
  }

  /// Carte tarification
  Widget _buildPricingCard(BuildContext context, offer, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('diaspo_detail.pricing'.tr, isDark),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('diaspo_detail.price_per_kg'.tr, style: TextStyle(fontSize: 14, color: _muted(isDark))),
              Text(
                '${offer.formattedPricePerKg} ${offer.currencySymbol}/kg',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppThemeSystem.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDesign.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: AppDesign.success),
                    const SizedBox(width: 8),
                    Text('diaspo_detail.availability'.tr, style: TextStyle(fontWeight: FontWeight.w600, color: _titleColor(isDark))),
                  ],
                ),
                Text('${offer.remainingKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppDesign.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppThemeSystem.primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: _muted(isDark))),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _titleColor(isDark))),
            ],
          ),
        ),
      ],
    );
  }

  /// Boutons d'action (bas d'écran)
  Widget _buildActionButtons(BuildContext context, bool isDark) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Obx(() {
      Container wrap(Widget child) => Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPadding > 0 ? bottomPadding + 8 : 12),
            decoration: BoxDecoration(
              color: _card(isDark),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: child,
          );

      if (controller.isMyOffer.value) {
        // La suppression est masquée dès qu'une réservation payée/confirmée existe
        // (drapeau can_delete du backend) : on ne peut plus supprimer une offre achetée.
        final canDelete = controller.offer.value?.canDelete ?? true;
        return wrap(Row(
          children: [
            if (canDelete) ...[
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: controller.isDeleting.value ? null : controller.deleteOffer,
                    icon: controller.isDeleting.value
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline, color: AppDesign.danger),
                    label: Text('diaspo_detail.delete'.tr,
                        style: TextStyle(color: controller.isDeleting.value ? Colors.grey : AppDesign.danger)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: controller.isDeleting.value ? Colors.grey : AppDesign.danger),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: controller.isDeleting.value ? null : controller.editOffer,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text('diaspo_detail.edit'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppThemeSystem.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ));
      }

      return wrap(Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: controller.openChat,
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text('diaspo_detail.chat'.tr),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppThemeSystem.primaryColor),
                  foregroundColor: AppThemeSystem.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                // Réservation fermée tant que le profil n'est pas vérifié.
                onPressed: (controller.offer.value?.profileVerified ?? false) ? controller.openBooking : null,
                icon: Icon((controller.offer.value?.profileVerified ?? false)
                    ? Icons.shopping_bag_outlined
                    : Icons.lock_clock_outlined),
                label: Text((controller.offer.value?.profileVerified ?? false)
                    ? 'diaspo_detail.order'.tr
                    : 'diaspo_detail.after_verification'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ));
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return 'diaspo_detail.date_at_time'.trParams({
      'date': '${dateTime.day}/${dateTime.month}/${dateTime.year}',
      'time':
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
    });
  }
}
