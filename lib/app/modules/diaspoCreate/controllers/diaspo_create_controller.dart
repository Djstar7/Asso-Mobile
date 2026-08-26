import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/models/currency_model.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/currency_service.dart';
import '../../../data/providers/diaspo_service.dart';
class DiaspoCreateController extends GetxController {
  final DiaspoService _diaspoService = Get.find<DiaspoService>();

  // Step management
  final currentStep = 0.obs;
  final totalSteps = 3;

  // Liste des pays avec leur devise (source unique : /v1/currencies/all-with-countries),
  // le même composant que la sélection de pays à l'onboarding.
  final RxList<Map<String, dynamic>> countriesWithCurrency = <Map<String, dynamic>>[].obs;
  final isLoadingCountries = false.obs;

  // Devise de l'offre, déduite du PAYS DE DÉPART sélectionné (là où les kg sont tarifés).
  final selectedCurrencyCode = 'XAF'.obs;
  final selectedCurrencySymbol = 'FCFA'.obs;

  /// Symbole de devise à afficher dans l'étape tarification (devise de l'offre).
  String get offerCurrencySymbol => selectedCurrencySymbol.value;

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
    _prefillFromUserCountry();
    loadCountries();
  }

  /// Par défaut, le pays de départ = le pays de l'utilisateur, et la devise de
  /// l'offre = sa devise. L'utilisateur peut ensuite changer via le picker.
  void _prefillFromUserCountry() {
    try {
      final cs = CurrencyService.to;
      if (cs.currencyCode.isNotEmpty) {
        selectedCurrencyCode.value = cs.currencyCode;
        selectedCurrencySymbol.value = cs.currencySymbol;
      }
      if (cs.detectedCountry.isNotEmpty && departureCountryController.text.isEmpty) {
        departureCountryController.text = cs.detectedCountry;
      }
    } catch (_) {
      // CurrencyService non prêt : on garde les défauts (XAF/FCFA).
    }
  }

  /// Charge la liste des pays + devises (source unique partagée avec l'onboarding).
  Future<void> loadCountries() async {
    if (countriesWithCurrency.isNotEmpty) return;
    isLoadingCountries.value = true;
    try {
      final response = await ApiProvider.get('/v1/currencies/all-with-countries');
      if (response.success && response.data != null && response.data!['data'] != null) {
        final List currencies = response.data!['data'];
        final List<Map<String, dynamic>> list = [];
        for (final c in currencies) {
          final currency = CurrencyModel.fromJson(c);
          for (final country in currency.countries) {
            list.add({
              'country': country,
              'code': currency.code,
              'symbol': currency.symbol,
            });
          }
        }
        list.sort((a, b) => (a['country'] as String).compareTo(b['country'] as String));
        countriesWithCurrency.value = list;
      }
    } catch (e) {
      // Silencieux : le formulaire reste utilisable, la devise garde son défaut.
    } finally {
      isLoadingCountries.value = false;
    }
  }

  /// Ouvre le sélecteur de pays (avec recherche). Pour le départ, fixe aussi la
  /// devise de l'offre depuis le pays choisi.
  Future<void> pickCountry({required bool isDeparture}) async {
    if (countriesWithCurrency.isEmpty) await loadCountries();

    final search = ''.obs;

    await Get.bottomSheet(
      Container(
        height: Get.height * 0.75,
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(Get.context!),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppThemeSystem.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              isDeparture ? 'Pays de départ' : 'Pays d\'arrivée',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.getPrimaryTextColor(Get.context!),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: false,
              onChanged: (v) => search.value = v.toLowerCase(),
              decoration: InputDecoration(
                hintText: 'Rechercher un pays ou une devise',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(() {
                final q = search.value;
                final items = q.isEmpty
                    ? countriesWithCurrency
                    : countriesWithCurrency.where((e) =>
                        (e['country'] as String).toLowerCase().contains(q) ||
                        (e['code'] as String).toLowerCase().contains(q)).toList();
                if (isLoadingCountries.value && items.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = items[i];
                    return ListTile(
                      title: Text(e['country'] as String),
                      trailing: Text(
                        '${e['code']} · ${e['symbol']}',
                        style: TextStyle(
                          color: AppThemeSystem.getSecondaryTextColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        if (isDeparture) {
                          departureCountryController.text = e['country'] as String;
                          selectedCurrencyCode.value = e['code'] as String;
                          selectedCurrencySymbol.value = e['symbol'] as String;
                        } else {
                          arrivalCountryController.text = e['country'] as String;
                        }
                        Get.back();
                      },
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
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

  /// Submit the offer
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
      await _diaspoService.createOffer(
        departureCountry: departureCountryController.text.trim(),
        departureCity: departureCityController.text.trim(),
        departureDateTime: departureDateTime.value!,
        arrivalCountry: arrivalCountryController.text.trim(),
        arrivalCity: arrivalCityController.text.trim(),
        arrivalDateTime: arrivalDateTime.value!,
        pricePerKg: double.parse(pricePerKgController.text.trim()),
        availableKg: double.parse(availableKgController.text.trim()),
        // La devise suit le pays de départ sélectionné (composant pays+devise).
        currency: selectedCurrencyCode.value,
      );

      Get.offNamed('/diaspo');
      Get.snackbar(
        'Succès',
        'Votre offre a été créée avec succès. Elle sera vérifiée par notre équipe.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      // Parse error message from server
      String errorMessage = 'Impossible de créer l\'offre. Veuillez réessayer.';

      if (e.toString().contains('arrival datetime field must be a date after departure datetime')) {
        errorMessage = 'La date d\'arrivée doit être après la date de départ';
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
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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
      initialDate: minDate.add(const Duration(hours: 2)),
      firstDate: minDate,
      lastDate: minDate.add(const Duration(days: 30)),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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

  /// Get currency symbol
  String get currencySymbol {
    if (!Get.isRegistered<CurrencyService>()) {
      return 'FCFA';
    }
    return CurrencyService.to.currencySymbol;
  }
}
