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
      backgroundColor: isDark ? AppThemeSystem.darkBackgroundColor : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Réserver des kilos'),
        centerTitle: true,
      ),
      body: Obx(() {
        if (controller.offer.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Offer summary
                    _buildOfferSummary(context, isDark),

                    // Kg selector
                    _buildKgSelector(context, isDark),

                    // Price breakdown
                    _buildPriceBreakdown(context, isDark),

                    // Wallet balance
                    _buildWalletBalance(context, isDark),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // Confirm button
            _buildConfirmButton(context, isDark),
          ],
        );
      }),
    );
  }

  /// Offer summary card
  Widget _buildOfferSummary(BuildContext context, bool isDark) {
    final offer = controller.offer.value!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé de l\'offre',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.flight_takeoff, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${offer.departureCity}, ${offer.departureCountry}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.flight_land, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${offer.arrivalCity}, ${offer.arrivalCountry}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Prix par kilo',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              Text(
                '${offer.pricePerKg} ${offer.currency}/kg',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppThemeSystem.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Disponible',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              Text(
                '${offer.remainingKg.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Kg selector
  Widget _buildKgSelector(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nombre de kilos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Decrement button
              IconButton(
                onPressed: controller.decrementKg,
                icon: const Icon(Icons.remove_circle_outline),
                iconSize: 40,
                color: AppThemeSystem.primaryColor,
              ),
              const SizedBox(width: 16),

              // Kg input
              Expanded(
                child: TextField(
                  controller: controller.kgController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                  ],
                  decoration: InputDecoration(
                    suffix: const Text('kg'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Increment button
              IconButton(
                onPressed: controller.incrementKg,
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 40,
                color: AppThemeSystem.primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Min: ${controller.minKg.toStringAsFixed(1)} kg - Max: ${controller.remainingKg.toStringAsFixed(1)} kg',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// Price breakdown
  Widget _buildPriceBreakdown(BuildContext context, bool isDark) {
    return Obx(() => Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Détails du paiement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              _buildPriceRow(
                'Sous-total',
                '${controller.subtotal.value.toStringAsFixed(0)} ${controller.offer.value?.currency ?? 'EUR'}',
                isDark,
              ),
              const SizedBox(height: 8),
              _buildPriceRow(
                'Commission (${controller.commissionPercent.value.toStringAsFixed(0)}%)',
                '${controller.commissionAmount.value.toStringAsFixed(0)} ${controller.offer.value?.currency ?? 'EUR'}',
                isDark,
              ),
              const Divider(height: 24),
              _buildPriceRow(
                'TOTAL',
                '${controller.totalPrice.value.toStringAsFixed(0)} ${controller.offer.value?.currency ?? 'EUR'}',
                isDark,
                isTotal: true,
              ),
            ],
          ),
        ));
  }

  Widget _buildPriceRow(String label, String value, bool isDark, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isDark ? (isTotal ? Colors.white : Colors.white70) : (isTotal ? Colors.black : Colors.grey[600]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppThemeSystem.primaryColor : (isDark ? Colors.white : Colors.black),
          ),
        ),
      ],
    );
  }

  /// Wallet balance
  Widget _buildWalletBalance(BuildContext context, bool isDark) {
    return Obx(() {
      final hasInsufficientFunds = controller.hasInsufficientFunds;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasInsufficientFunds
              ? Colors.orange.withOpacity(0.1)
              : (isDark ? AppThemeSystem.darkCardColor : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: hasInsufficientFunds
              ? Border.all(color: Colors.orange, width: 2)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              hasInsufficientFunds ? Icons.warning_amber : Icons.account_balance_wallet,
              color: hasInsufficientFunds ? Colors.orange : AppThemeSystem.primaryColor,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Solde du portefeuille',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${controller.walletBalance.toStringAsFixed(0)} FCFA',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: hasInsufficientFunds ? Colors.orange : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  if (hasInsufficientFunds) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Solde insuffisant',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasInsufficientFunds)
              TextButton(
                onPressed: () => Get.toNamed('/wallet'),
                child: const Text('Recharger'),
              ),
          ],
        ),
      );
    });
  }

  /// Confirm button
  Widget _buildConfirmButton(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Obx(() => SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: controller.isSubmitting.value ? null : controller.submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: controller.isSubmitting.value
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Confirmer la réservation (${controller.totalPrice.value.toStringAsFixed(0)} ${controller.offer.value?.currency ?? 'EUR'})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          )),
    );
  }
}
