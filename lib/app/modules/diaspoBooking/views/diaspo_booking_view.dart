import 'package:asso/app/core/utils/app_theme_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/diaspo_booking_controller.dart';

class DiaspoBookingView extends GetView<DiaspoBookingController> {
  const DiaspoBookingView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    return Scaffold(
      backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Réserver des kilos'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: Obx(() {
        if (controller.offer.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRouteCard(context, isDark),
                    const SizedBox(height: 16),
                    _buildKgSelector(context, isDark),
                    const SizedBox(height: 16),
                    _buildPriceBreakdown(context, isDark),
                    const SizedBox(height: 12),
                    _buildInfoNote(context, isDark),
                  ],
                ),
              ),
            ),
            _buildConfirmButton(context, isDark),
          ],
        );
      }),
    );
  }

  Color _card(bool isDark) => isDark ? AppThemeSystem.darkCardColor : Colors.white;
  Color _muted(bool isDark) => isDark ? Colors.white70 : const Color(0xFF6B7280);
  Color _title(bool isDark) => isDark ? Colors.white : const Color(0xFF111827);

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
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: _title(isDark),
        ),
      );

  /// Carte trajet départ → arrivée + prix/dispo
  Widget _buildRouteCard(BuildContext context, bool isDark) {
    final offer = controller.offer.value!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline départ → arrivée
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.flight_takeoff, color: Color(0xFF16A34A), size: 20),
                  Container(
                    width: 2,
                    height: 26,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: _muted(isDark).withValues(alpha: 0.3),
                  ),
                  const Icon(Icons.flight_land, color: Color(0xFFDC2626), size: 20),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Départ', style: TextStyle(fontSize: 11, color: _muted(isDark))),
                    const SizedBox(height: 2),
                    Text(
                      '${offer.departureCity}, ${offer.departureCountry}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _title(isDark)),
                    ),
                    const SizedBox(height: 14),
                    Text('Arrivée', style: TextStyle(fontSize: 11, color: _muted(isDark))),
                    const SizedBox(height: 2),
                    Text(
                      '${offer.arrivalCity}, ${offer.arrivalCountry}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: _title(isDark)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: _muted(isDark).withValues(alpha: 0.15), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statTile(
                  isDark,
                  label: 'Prix par kilo',
                  value: '${offer.formattedPricePerKg} ${offer.currencySymbol}',
                  valueColor: AppThemeSystem.primaryColor,
                ),
              ),
              Container(width: 1, height: 34, color: _muted(isDark).withValues(alpha: 0.15)),
              Expanded(
                child: _statTile(
                  isDark,
                  label: 'Disponible',
                  value: '${offer.remainingKg.toStringAsFixed(1)} kg',
                  valueColor: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statTile(bool isDark, {required String label, required String value, required Color valueColor}) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: _muted(isDark))),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  /// Sélecteur de kilos
  Widget _buildKgSelector(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDeco(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Nombre de kilos', isDark),
          const SizedBox(height: 16),
          Row(
            children: [
              _roundBtn(Icons.remove, controller.decrementKg, isDark),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller.kgController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _title(isDark)),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  decoration: InputDecoration(
                    suffixText: 'kg',
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF5F6F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _roundBtn(Icons.add, controller.incrementKg, isDark),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Min ${controller.minKg.toStringAsFixed(1)} kg · Max ${controller.remainingKg.toStringAsFixed(1)} kg',
              style: TextStyle(fontSize: 12, color: _muted(isDark)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return Material(
      color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppThemeSystem.primaryColor, size: 26),
        ),
      ),
    );
  }

  /// Détails du paiement
  Widget _buildPriceBreakdown(BuildContext context, bool isDark) {
    return Obx(() => Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDeco(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Détails du paiement', isDark),
              const SizedBox(height: 16),
              _priceRow('Sous-total', controller.formatOfferAmount(controller.subtotal.value), isDark),
              const SizedBox(height: 10),
              _priceRow(
                'Commission (${controller.commissionPercent.value.toStringAsFixed(0)}%)',
                controller.formatOfferAmount(controller.commissionAmount.value),
                isDark,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: _muted(isDark).withValues(alpha: 0.15), height: 1),
              ),
              _priceRow('Total', controller.formatOfferAmount(controller.totalPrice.value), isDark, isTotal: true),
            ],
          ),
        ));
  }

  Widget _priceRow(String label, String value, bool isDark, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? _title(isDark) : _muted(isDark),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: FontWeight.w700,
            color: isTotal ? AppThemeSystem.primaryColor : _title(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoNote(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppThemeSystem.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 18, color: AppThemeSystem.primaryColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Vous recevrez un code de confirmation à remettre au voyageur. '
              'Les fonds ne sont débloqués qu\'à la confirmation de réception.',
              style: TextStyle(fontSize: 12, color: _muted(isDark), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton de confirmation (ouvre le sélecteur de paiement)
  Widget _buildConfirmButton(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
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
      child: Obx(() => SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: controller.isSubmitting.value ? null : controller.submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: controller.isSubmitting.value
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Payer ${controller.formatOfferAmount(controller.totalPrice.value)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          )),
    );
  }
}
