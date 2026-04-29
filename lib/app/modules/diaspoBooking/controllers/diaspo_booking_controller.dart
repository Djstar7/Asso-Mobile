import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/models/diaspo_booking.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/services/wallet_service.dart';

class DiaspoBookingController extends GetxController {
  final DiaspoService _diaspoService = Get.find<DiaspoService>();
  final WalletService _walletService = Get.find<WalletService>();

  final offer = Rx<DiaspoOffer?>(null);
  final wallet = Rxn<WalletModel>();
  final isLoading = false.obs;
  final isSubmitting = false.obs;

  // Kg selection
  final kgController = TextEditingController();
  final kgBooked = 1.0.obs;
  final minKg = 1.0;

  // Price calculation
  final subtotal = 0.0.obs;
  final commissionPercent = 5.0.obs; // Default 5%
  final commissionAmount = 0.0.obs;
  final totalPrice = 0.0.obs;

  double get remainingKg => offer.value?.remainingKg ?? 0;
  double get pricePerKg => offer.value?.pricePerKg ?? 0;
  double get walletBalance => wallet.value?.currentBalance ?? 0;
  bool get hasInsufficientFunds => totalPrice.value > walletBalance;

  @override
  void onInit() {
    super.onInit();
    _loadOffer();
    _loadWallet();

    // Initialize kg
    kgController.text = '1.0';
    kgBooked.value = 1.0;
    _calculatePrices();

    // Listen to kg changes
    kgController.addListener(() {
      final value = double.tryParse(kgController.text) ?? 0;
      if (value > 0 && value <= remainingKg) {
        kgBooked.value = value;
        _calculatePrices();
      }
    });
  }

  @override
  void onClose() {
    kgController.dispose();
    super.onClose();
  }

  void _loadOffer() {
    final args = Get.arguments;
    if (args != null && args['offer'] != null) {
      offer.value = args['offer'] as DiaspoOffer;
    } else {
      Get.snackbar('Erreur', 'Offre introuvable');
      Get.back();
    }
  }

  Future<void> _loadWallet() async {
    isLoading.value = true;
    try {
      final response = await _walletService.getWalletStats();
      wallet.value = response;
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de charger le portefeuille');
    } finally {
      isLoading.value = false;
    }
  }

  void _calculatePrices() {
    subtotal.value = kgBooked.value * pricePerKg;
    commissionAmount.value = subtotal.value * (commissionPercent.value / 100);
    totalPrice.value = subtotal.value + commissionAmount.value;
  }

  void incrementKg() {
    final newValue = kgBooked.value + 1.0;
    if (newValue <= remainingKg) {
      kgBooked.value = newValue;
      kgController.text = newValue.toStringAsFixed(1);
      _calculatePrices();
    }
  }

  void decrementKg() {
    final newValue = kgBooked.value - 1.0;
    if (newValue >= minKg) {
      kgBooked.value = newValue;
      kgController.text = newValue.toStringAsFixed(1);
      _calculatePrices();
    }
  }

  Future<void> submitBooking() async {
    if (offer.value == null) return;

    // Validation
    if (kgBooked.value < minKg) {
      Get.snackbar('Erreur', 'Le minimum est ${minKg.toStringAsFixed(1)} kg');
      return;
    }

    if (kgBooked.value > remainingKg) {
      Get.snackbar('Erreur', 'Seulement ${remainingKg.toStringAsFixed(1)} kg disponibles');
      return;
    }

    if (hasInsufficientFunds) {
      Get.snackbar(
        'Solde insuffisant',
        'Veuillez recharger votre portefeuille',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    isSubmitting.value = true;

    try {
      final booking = await _diaspoService.bookOffer(
        offerId: offer.value!.id,
        kgBooked: kgBooked.value,
      );

      isSubmitting.value = false;

      // Show success dialog
      _showSuccessDialog(booking);
    } catch (e) {
      isSubmitting.value = false;
      Get.snackbar(
        'Erreur',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showSuccessDialog(DiaspoBooking booking) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Réservation confirmée!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Votre réservation de ${booking.kgBooked.toStringAsFixed(1)} kg a été confirmée.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Code de confirmation',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      booking.confirmationCode,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Donnez ce code au vendeur pour confirmer la réception',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back(); // Close dialog
                    Get.back(); // Close booking screen
                    Get.back(); // Close detail screen
                    // Go back to list and refresh
                    Get.toNamed('/diaspo');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Terminer'),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }
}
