import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/diaspo_detail_controller.dart';

class DiaspoDetailView extends GetView<DiaspoDetailController> {
  const DiaspoDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Détails de l\'offre'),
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
          return const Center(child: Text('Offre introuvable'));
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
  Color _muted(bool isDark) => isDark ? Colors.white70 : const Color(0xFF6B7280);
  Color _titleColor(bool isDark) => isDark ? Colors.white : const Color(0xFF111827);

  BoxDecoration _cardDeco(bool isDark) => BoxDecoration(
        color: _card(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFECECEF),
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
    final verified = offer.verificationStatus == 'verified';
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
                        offer.user?.fullName ?? 'Anonyme',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _titleColor(isDark)),
                      ),
                    ),
                    if (verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 18, color: Color(0xFF2563EB)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (verified ? const Color(0xFF16A34A) : _muted(isDark)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    verified ? 'Voyageur vérifié' : 'Voyageur',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: verified ? const Color(0xFF16A34A) : _muted(isDark),
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

  /// Carte itinéraire (timeline)
  Widget _buildRouteCard(BuildContext context, offer, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Itinéraire', isDark),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.flight_takeoff, color: Color(0xFF16A34A), size: 22),
                  Container(
                    width: 2,
                    height: 30,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: _muted(isDark).withValues(alpha: 0.3),
                  ),
                  const Icon(Icons.flight_land, color: Color(0xFFDC2626), size: 22),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Départ', style: TextStyle(fontSize: 11, color: _muted(isDark))),
                    const SizedBox(height: 2),
                    Text('${offer.departureCity}, ${offer.departureCountry}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _titleColor(isDark))),
                    const SizedBox(height: 18),
                    Text('Arrivée', style: TextStyle(fontSize: 11, color: _muted(isDark))),
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
          _sectionTitle('Dates et horaires', isDark),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.calendar_today_outlined, 'Départ', _formatDateTime(offer.departureDateTime), isDark),
          const SizedBox(height: 14),
          _buildInfoRow(Icons.event_available_outlined, 'Arrivée', _formatDateTime(offer.arrivalDateTime), isDark),
          if (offer.tripDurationHours != null) ...[
            const SizedBox(height: 14),
            _buildInfoRow(Icons.schedule, 'Durée du voyage', '${offer.tripDurationHours?.toStringAsFixed(1)} heures', isDark),
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
          _sectionTitle('Tarification', isDark),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Prix par kilo', style: TextStyle(fontSize: 14, color: _muted(isDark))),
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
              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF16A34A)),
                    const SizedBox(width: 8),
                    Text('Disponibilité', style: TextStyle(fontWeight: FontWeight.w600, color: _titleColor(isDark))),
                  ],
                ),
                Text('${offer.remainingKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
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
                        : const Icon(Icons.delete_outline, color: Colors.red),
                    label: Text('Supprimer',
                        style: TextStyle(color: controller.isDeleting.value ? Colors.grey : Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: controller.isDeleting.value ? Colors.grey : Colors.red),
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
                  label: const Text('Modifier'),
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
                label: const Text('Chatter'),
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
                onPressed: controller.openBooking,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Commander'),
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
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
