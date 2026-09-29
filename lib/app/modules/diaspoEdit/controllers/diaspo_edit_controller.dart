import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_design.dart';

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
        'diaspo_edit.error'.tr,
        'diaspo_edit.offer_not_found'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
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
          'diaspo_edit.error'.tr,
          'diaspo_edit.select_dates'.tr,
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
        'diaspo_edit.error'.tr,
        'diaspo_edit.select_dates'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return;
    }

    if (arrivalDateTime.value!.isBefore(departureDateTime.value!) ||
        arrivalDateTime.value!.isAtSameMomentAs(departureDateTime.value!)) {
      Get.snackbar(
        'diaspo_edit.error'.tr,
        'diaspo_edit.arrival_after_departure'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
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
        'diaspo_edit.success'.tr,
        'diaspo_edit.updated_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
      );
    } catch (e) {
      // Parse error message from server
      String errorMessage = 'diaspo_edit.update_failed'.tr;

      if (e.toString().contains('arrival datetime field must be a date after departure datetime')) {
        errorMessage = 'diaspo_edit.arrival_after_departure'.tr;
      } else if (e.toString().contains('cannot be modified')) {
        errorMessage = 'diaspo_edit.cannot_be_modified'.tr;
      } else if (e.toString().contains('Non autorisé') ||
          e.toString().contains('Unauthorized')) {
        errorMessage = 'diaspo_edit.not_authorized'.tr;
      } else if (e is DioException && e.response?.data is Map) {
        // Le serveur répond dans la langue de l'application : son message
        // (offre terminée, réservations actives…) s'affiche tel quel.
        final serverMessage = (e.response!.data as Map)['message'];
        if (serverMessage is String && serverMessage.isNotEmpty) {
          errorMessage = serverMessage;
        }
      }

      Get.snackbar(
        'diaspo_edit.error'.tr,
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
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
            'diaspo_edit.error'.tr,
            'diaspo_edit.arrival_time_after_departure'.tr,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppDesign.danger,
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
    if (dateTime == null) return 'diaspo_edit.select'.tr;
    return 'diaspo_edit.date_time'.trParams({
      'date': '${dateTime.day}/${dateTime.month}/${dateTime.year}',
      'time': '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}',
    });
  }

  // ================================
  // CURRENCY FORMATTING
  // ================================

  /// Format price with user's currency
  String formatPrice(double priceInXOF, {bool showSymbol = true}) {
    if (!Get.isRegistered<CurrencyService>()) {
      return '${priceInXOF.toStringAsFixed(0)} FCFA';
    }
    return CurrencyService.to.formatPrice(priceInXOF, showSymbol: showSymbol);
  }

  /// Symbole de la devise RÉELLE de l'offre (et non la devise de l'utilisateur).
  /// Dérivé du code `offer.currency` via la table de correspondance.
  String get currencySymbol {
    return CurrencyService.getSymbolForCode(offer.currency);
  }
}
