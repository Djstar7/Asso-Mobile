import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/providers/diaspo_service.dart';

class DiaspoEditController extends GetxController {
  final DiaspoService _diaspoService = Get.find<DiaspoService>();

  // Offer being edited
  late DiaspoOffer offer;

  // Step management
  final currentStep = 0.obs;
  final totalSteps = 3;

  // Form controllers
  final departureCountryController = TextEditingController();
  final departureCityController = TextEditingController();
  final arrivalCountryController = TextEditingController();
  final arrivalCityController = TextEditingController();
  final pricePerKgController = TextEditingController();
  final availableKgController = TextEditingController();

  // Date times
  final departureDateTime = Rx<DateTime?>(null);
  final arrivalDateTime = Rx<DateTime?>(null);

  // Observable values for revenue calculation
  final pricePerKg = 0.0.obs;
  final availableKg = 0.0.obs;

  // Loading
  final isSubmitting = false.obs;

  // Form keys
  final formKey1 = GlobalKey<FormState>();
  final formKey2 = GlobalKey<FormState>();

  @override
  void onInit() {
    super.onInit();
    _loadOfferData();
  }

  @override
  void onClose() {
    departureCountryController.dispose();
    departureCityController.dispose();
    arrivalCountryController.dispose();
    arrivalCityController.dispose();
    pricePerKgController.dispose();
    availableKgController.dispose();
    super.onClose();
  }

  /// Load offer data from arguments
  void _loadOfferData() {
    final args = Get.arguments;
    if (args == null || args['offer'] == null) {
      Get.back();
      Get.snackbar(
        'Erreur',
        'Offre introuvable',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    offer = args['offer'] as DiaspoOffer;

    // Pre-fill form fields
    departureCountryController.text = offer.departureCountry;
    departureCityController.text = offer.departureCity;
    arrivalCountryController.text = offer.arrivalCountry;
    arrivalCityController.text = offer.arrivalCity;
    pricePerKgController.text = offer.pricePerKg.toString();
    availableKgController.text = offer.availableKg.toString();

    departureDateTime.value = offer.departureDateTime;
    arrivalDateTime.value = offer.arrivalDateTime;

    pricePerKg.value = offer.pricePerKg;
    availableKg.value = offer.availableKg;
  }

  /// Go to next step
  void nextStep() {
    // Validate current step
    if (currentStep.value == 0) {
      if (!formKey1.currentState!.validate()) return;
      if (departureDateTime.value == null || arrivalDateTime.value == null) {
        Get.snackbar(
          'Erreur',
          'Veuillez sélectionner les dates de départ et d\'arrivée',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    } else if (currentStep.value == 1) {
      if (!formKey2.currentState!.validate()) return;
    }

    if (currentStep.value < totalSteps - 1) {
      currentStep.value++;
    }
  }

  /// Go to previous step
  void previousStep() {
    if (currentStep.value > 0) {
      currentStep.value--;
    }
  }

  /// Submit the updated offer
  Future<void> submitOffer() async {
    // Validate dates before submitting
    if (departureDateTime.value == null || arrivalDateTime.value == null) {
      Get.snackbar(
        'Erreur',
        'Veuillez sélectionner les dates de départ et d\'arrivée',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (arrivalDateTime.value!.isBefore(departureDateTime.value!) ||
        arrivalDateTime.value!.isAtSameMomentAs(departureDateTime.value!)) {
      Get.snackbar(
        'Erreur',
        'La date d\'arrivée doit être après la date de départ',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    isSubmitting.value = true;

    try {
      await _diaspoService.updateOffer(
        offer.id,
        {
          'departure_country': departureCountryController.text.trim(),
          'departure_city': departureCityController.text.trim(),
          'departure_datetime': departureDateTime.value!.toIso8601String(),
          'arrival_country': arrivalCountryController.text.trim(),
          'arrival_city': arrivalCityController.text.trim(),
          'arrival_datetime': arrivalDateTime.value!.toIso8601String(),
          'price_per_kg': double.parse(pricePerKgController.text.trim()),
          'available_kg': double.parse(availableKgController.text.trim()),
        },
      );

      Get.back(result: true); // Return true to indicate success
      Get.snackbar(
        'Succès',
        'Votre offre a été mise à jour avec succès',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      // Parse error message from server
      String errorMessage = 'Impossible de mettre à jour l\'offre. Veuillez réessayer.';

      if (e.toString().contains('arrival datetime field must be a date after departure datetime')) {
        errorMessage = 'La date d\'arrivée doit être après la date de départ';
      } else if (e.toString().contains('cannot be modified')) {
        errorMessage = 'Cette offre ne peut plus être modifiée';
      } else if (e.toString().contains('Non autorisé')) {
        errorMessage = 'Vous n\'êtes pas autorisé à modifier cette offre';
      }

      Get.snackbar(
        'Erreur',
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Pick departure date
  Future<void> pickDepartureDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: departureDateTime.value ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(departureDateTime.value ?? DateTime.now()),
      );

      if (time != null) {
        departureDateTime.value = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }
    }
  }

  /// Pick arrival date
  Future<void> pickArrivalDate(BuildContext context) async {
    final minDate = departureDateTime.value ?? DateTime.now().add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: arrivalDateTime.value ?? minDate.add(const Duration(hours: 2)),
      firstDate: minDate,
      lastDate: minDate.add(const Duration(days: 30)),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(arrivalDateTime.value ?? DateTime.now()),
      );

      if (time != null) {
        final selectedArrivalDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );

        // Validate that arrival is after departure
        if (selectedArrivalDateTime.isBefore(minDate) ||
            selectedArrivalDateTime.isAtSameMomentAs(minDate)) {
          Get.snackbar(
            'Erreur',
            'L\'heure d\'arrivée doit être après l\'heure de départ',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return;
        }

        arrivalDateTime.value = selectedArrivalDateTime;
      }
    }
  }

  /// Format date time
  String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Sélectionner';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
