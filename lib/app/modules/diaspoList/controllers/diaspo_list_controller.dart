import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/models/diaspo_booking.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../core/utils/app_theme_system.dart';

class DiaspoListController extends GetxController {
  final DiaspoService _diaspoService = Get.find<DiaspoService>();
  final ImagePicker _picker = ImagePicker();

  // Data
  final offers = <DiaspoOffer>[].obs;
  final myOffers = <DiaspoOffer>[].obs;
  final myBookingsAsBuyer = <DiaspoBooking>[].obs;
  final myBookingsAsSeller = <DiaspoBooking>[].obs;

  // Loading states
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  bool _isInitialLoad = true; // Track if this is the first load

  // Verification status
  final verificationStatus = 'unverified'.obs;
  final canCreateOffers = false.obs;

  // Document upload
  final Rx<String?> selectedDocumentType = Rx<String?>(null); // 'cni' or 'passport'
  final Rx<File?> documentFrontImage = Rx<File?>(null);
  final Rx<File?> documentBackImage = Rx<File?>(null);
  final isUploadingDocument = false.obs;

  // Pagination
  int currentPage = 1;
  bool hasMore = true;

  // Selected tab: 0 = Tous, 1 = Mes Offres, 2 = Mes Achats, 3 = Mes Ventes
  final selectedTab = 0.obs;

  // Filters
  final Rx<String?> filterDepartureCountry = Rx<String?>(null);
  final Rx<String?> filterArrivalCountry = Rx<String?>(null);
  final Rx<String?> filterDepartureCity = Rx<String?>(null);
  final Rx<String?> filterArrivalCity = Rx<String?>(null);
  final Rx<DateTime?> filterMinDate = Rx<DateTime?>(null);
  final Rx<DateTime?> filterMaxDate = Rx<DateTime?>(null);
  final Rx<double?> filterMaxPrice = Rx<double?>(null);
  final hasActiveFilters = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadVerificationStatus();
    loadOffers();
  }

  @override
  void onClose() {
    super.onClose();
  }

  /// Load verification status
  Future<void> loadVerificationStatus() async {
    try {
      final response = await _diaspoService.getVerificationStatus();
      if (response['success']) {
        verificationStatus.value = response['data']['verification_status'] ?? 'unverified';
        canCreateOffers.value = response['data']['can_create_offers'] ?? false;
      }
    } catch (e) {
      print('Error loading verification status: $e');
    }
  }

  /// Load all offers with filters
  Future<void> loadOffers({bool refresh = false}) async {
    if (refresh) {
      currentPage = 1;
      hasMore = true;
      offers.clear();
    }

    // Allow first load, but prevent duplicate requests after that
    if (!_isInitialLoad && (isLoading.value || (isLoadingMore.value && !refresh))) return;

    // Set loading state: use isLoading for initial/refresh, isLoadingMore for pagination
    if (_isInitialLoad || refresh) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    _isInitialLoad = false; // Mark initial load as done

    try {
      final response = await _diaspoService.getOffers(
        page: currentPage,
        departureCountry: filterDepartureCountry.value,
        arrivalCountry: filterArrivalCountry.value,
        departureCity: filterDepartureCity.value,
        arrivalCity: filterArrivalCity.value,
        minDate: filterMinDate.value?.toIso8601String(),
        maxDate: filterMaxDate.value?.toIso8601String(),
        maxPrice: filterMaxPrice.value,
      );

      if (response['success']) {
        final data = response['data'];
        final List<DiaspoOffer> newOffers = (data['data'] as List)
            .map((json) => DiaspoOffer.fromJson(json))
            .toList();

        if (refresh) {
          offers.value = newOffers;
        } else {
          offers.addAll(newOffers);
        }

        currentPage = data['current_page'] + 1;
        hasMore = data['current_page'] < data['last_page'];
      }
    } catch (e) {
      print('Error loading offers: $e');
      Get.snackbar(
        'Erreur',
        'Impossible de charger les offres',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  /// Load my offers
  Future<void> loadMyOffers() async {
    isLoading.value = true;
    try {
      final response = await _diaspoService.getMyOffers();
      if (response['success']) {
        final data = response['data'];
        final List<DiaspoOffer> newOffers = (data['data'] as List)
            .map((json) => DiaspoOffer.fromJson(json))
            .toList();
        myOffers.value = newOffers;
      }
    } catch (e) {
      print('Error loading my offers: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load my bookings as buyer
  Future<void> loadMyBookingsAsBuyer() async {
    isLoading.value = true;
    try {
      final response = await _diaspoService.getBookings(role: 'buyer');
      if (response['success']) {
        final data = response['data'];
        final List<DiaspoBooking> bookings = (data['data'] as List)
            .map((json) => DiaspoBooking.fromJson(json))
            .toList();
        myBookingsAsBuyer.value = bookings;
      }
    } catch (e) {
      print('Error loading my bookings as buyer: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load my bookings as seller
  Future<void> loadMyBookingsAsSeller() async {
    isLoading.value = true;
    try {
      final response = await _diaspoService.getBookings(role: 'seller');
      if (response['success']) {
        final data = response['data'];
        final List<DiaspoBooking> bookings = (data['data'] as List)
            .map((json) => DiaspoBooking.fromJson(json))
            .toList();
        myBookingsAsSeller.value = bookings;
      }
    } catch (e) {
      print('Error loading my bookings as seller: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Change tab and load data
  void changeTab(int index) {
    selectedTab.value = index;
    switch (index) {
      case 0:
        if (offers.isEmpty) loadOffers();
        break;
      case 1:
        if (myOffers.isEmpty) loadMyOffers();
        break;
      case 2:
        if (myBookingsAsBuyer.isEmpty) loadMyBookingsAsBuyer();
        break;
      case 3:
        if (myBookingsAsSeller.isEmpty) loadMyBookingsAsSeller();
        break;
    }
  }

  /// Refresh current tab data
  @override
  Future<void> refresh() async {
    switch (selectedTab.value) {
      case 0:
        await loadOffers(refresh: true);
        break;
      case 1:
        await loadMyOffers();
        break;
      case 2:
        await loadMyBookingsAsBuyer();
        break;
      case 3:
        await loadMyBookingsAsSeller();
        break;
    }
  }

  /// Load more offers
  void loadMore() {
    if (!hasMore || isLoadingMore.value) return;
    loadOffers();
  }

  /// Apply filters
  void applyFilters({
    String? departureCountry,
    String? arrivalCountry,
    String? departureCity,
    String? arrivalCity,
    DateTime? minDate,
    DateTime? maxDate,
    double? maxPrice,
  }) {
    filterDepartureCountry.value = departureCountry;
    filterArrivalCountry.value = arrivalCountry;
    filterDepartureCity.value = departureCity;
    filterArrivalCity.value = arrivalCity;
    filterMinDate.value = minDate;
    filterMaxDate.value = maxDate;
    filterMaxPrice.value = maxPrice;

    // Update active filters flag
    hasActiveFilters.value = departureCountry != null ||
        arrivalCountry != null ||
        departureCity != null ||
        arrivalCity != null ||
        minDate != null ||
        maxDate != null ||
        maxPrice != null;

    // Reload offers with filters
    loadOffers(refresh: true);
  }

  /// Clear all filters
  void clearFilters() {
    filterDepartureCountry.value = null;
    filterArrivalCountry.value = null;
    filterDepartureCity.value = null;
    filterArrivalCity.value = null;
    filterMinDate.value = null;
    filterMaxDate.value = null;
    filterMaxPrice.value = null;
    hasActiveFilters.value = false;

    // Reload offers without filters
    loadOffers(refresh: true);
  }

  /// Show filters bottom sheet
  void showFiltersBottomSheet() {
    Get.bottomSheet(
      _buildFiltersBottomSheet(),
      isScrollControlled: true,
      enableDrag: true,
    );
  }

  /// Build filters bottom sheet
  Widget _buildFiltersBottomSheet() {
    final isDark = AppThemeSystem.isDarkMode(Get.context!);

    // Local controllers for filter inputs
    final departureCountryController = TextEditingController(text: filterDepartureCountry.value);
    final arrivalCountryController = TextEditingController(text: filterArrivalCountry.value);
    final departureCityController = TextEditingController(text: filterDepartureCity.value);
    final arrivalCityController = TextEditingController(text: filterArrivalCity.value);
    final maxPriceController = TextEditingController(
      text: filterMaxPrice.value?.toString() ?? '',
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.filter_list, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Filtrer les offres',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    departureCountryController.clear();
                    arrivalCountryController.clear();
                    departureCityController.clear();
                    arrivalCityController.clear();
                    maxPriceController.clear();
                    filterMinDate.value = null;
                    filterMaxDate.value = null;
                  },
                  child: const Text('Réinitialiser'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Departure section
            Text(
              'Départ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: departureCountryController,
              decoration: InputDecoration(
                labelText: 'Pays de départ',
                prefixIcon: const Icon(Icons.public),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: departureCityController,
              decoration: InputDecoration(
                labelText: 'Ville de départ',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Arrival section
            Text(
              'Arrivée',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: arrivalCountryController,
              decoration: InputDecoration(
                labelText: 'Pays d\'arrivée',
                prefixIcon: const Icon(Icons.public),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: arrivalCityController,
              decoration: InputDecoration(
                labelText: 'Ville d\'arrivée',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Price filter
            Text(
              'Prix maximum (par kg)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Prix max',
                prefixIcon: const Icon(Icons.euro),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Date range
            Text(
              'Période de départ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppThemeSystem.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Obx(() => OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: Get.context!,
                            initialDate: filterMinDate.value ?? DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            filterMinDate.value = date;
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 20),
                        label: Text(
                          filterMinDate.value != null
                              ? '${filterMinDate.value!.day}/${filterMinDate.value!.month}/${filterMinDate.value!.year}'
                              : 'Du',
                          style: const TextStyle(fontSize: 14),
                        ),
                      )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Obx(() => OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: Get.context!,
                            initialDate: filterMaxDate.value ?? DateTime.now().add(const Duration(days: 7)),
                            firstDate: filterMinDate.value ?? DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            filterMaxDate.value = date;
                          }
                        },
                        icon: const Icon(Icons.calendar_today, size: 20),
                        label: Text(
                          filterMaxDate.value != null
                              ? '${filterMaxDate.value!.day}/${filterMaxDate.value!.month}/${filterMaxDate.value!.year}'
                              : 'Au',
                          style: const TextStyle(fontSize: 14),
                        ),
                      )),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  applyFilters(
                    departureCountry: departureCountryController.text.isEmpty
                        ? null
                        : departureCountryController.text,
                    arrivalCountry: arrivalCountryController.text.isEmpty
                        ? null
                        : arrivalCountryController.text,
                    departureCity: departureCityController.text.isEmpty
                        ? null
                        : departureCityController.text,
                    arrivalCity: arrivalCityController.text.isEmpty
                        ? null
                        : arrivalCityController.text,
                    maxPrice: maxPriceController.text.isEmpty
                        ? null
                        : double.tryParse(maxPriceController.text),
                    minDate: filterMinDate.value,
                    maxDate: filterMaxDate.value,
                  );
                  Get.back();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Appliquer les filtres',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Check if an offer belongs to the current user
  bool isMyOffer(DiaspoOffer offer) {
    final currentUser = StorageService.getUser();
    if (currentUser == null) return false;
    return offer.userId == currentUser.id;
  }

  /// Handle create offer button
  void handleCreateOffer() {
    if (canCreateOffers.value) {
      Get.toNamed('/diaspo/create');
    } else {
      _showVerificationDialog();
    }
  }

  /// Show verification dialog
  void _showVerificationDialog() {
    final status = verificationStatus.value;

    switch (status) {
      case 'pending':
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.hourglass_empty, color: Colors.orange),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Vérification en cours',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Votre pièce d\'identité est en cours de vérification par notre équipe.\n\n'
              'Vous recevrez une notification dès que votre profil sera validé (généralement sous 24-48h).',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        break;

      case 'rejected':
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Vérification refusée',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Votre vérification a été refusée.\n\n'
              'Voulez-vous soumettre à nouveau votre pièce d\'identité ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  _showUploadVerificationBottomSheet();
                },
                child: const Text('Soumettre à nouveau'),
              ),
            ],
          ),
        );
        break;

      default: // unverified
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.blue),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Vérification requise',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Pour créer une offre, vous devez d\'abord vérifier votre identité.\n\n'
              'Document requis (au choix):\n'
              '• Carte Nationale d\'Identité (CNI)\n'
              '• Passeport',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('Plus tard'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  _showUploadVerificationBottomSheet();
                },
                child: const Text('Vérifier maintenant'),
              ),
            ],
          ),
        );
        break;
    }
  }

  /// Show upload verification bottom sheet
  void _showUploadVerificationBottomSheet() {
    // Reset images and document type
    selectedDocumentType.value = null;
    documentFrontImage.value = null;
    documentBackImage.value = null;

    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.isDarkMode(Get.context!)
              ? AppThemeSystem.darkCardColor
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.verified_user, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Vérification d\'identité',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sélectionnez votre type de document et téléchargez les photos recto/verso',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Document type selection
              const Text(
                'Type de document',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Obx(() => Row(
                    children: [
                      // CNI option
                      Expanded(
                        child: GestureDetector(
                          onTap: () => selectedDocumentType.value = 'cni',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedDocumentType.value == 'cni'
                                  ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                                  : Colors.grey[100],
                              border: Border.all(
                                color: selectedDocumentType.value == 'cni'
                                    ? AppThemeSystem.primaryColor
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.credit_card,
                                  size: 36,
                                  color: selectedDocumentType.value == 'cni'
                                      ? AppThemeSystem.primaryColor
                                      : Colors.grey[600],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'CNI',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: selectedDocumentType.value == 'cni'
                                        ? AppThemeSystem.primaryColor
                                        : Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Carte Nationale',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Passport option
                      Expanded(
                        child: GestureDetector(
                          onTap: () => selectedDocumentType.value = 'passport',
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selectedDocumentType.value == 'passport'
                                  ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                                  : Colors.grey[100],
                              border: Border.all(
                                color: selectedDocumentType.value == 'passport'
                                    ? AppThemeSystem.primaryColor
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.card_travel,
                                  size: 36,
                                  color: selectedDocumentType.value == 'passport'
                                      ? AppThemeSystem.primaryColor
                                      : Colors.grey[600],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Passeport',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: selectedDocumentType.value == 'passport'
                                        ? AppThemeSystem.primaryColor
                                        : Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Passport',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )),
              const SizedBox(height: 24),

              // Photos section (only show if document type is selected)
              Obx(() => selectedDocumentType.value != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Photos du document',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Recto
                        _buildDocumentUploadCard(
                          title: 'Recto',
                          icon: Icons.badge,
                          image: documentFrontImage.value,
                          onUpload: () => _showImageSourceDialog(isBack: false),
                          onRemove: () => documentFrontImage.value = null,
                        ),
                        const SizedBox(height: 16),

                        // Verso
                        _buildDocumentUploadCard(
                          title: 'Verso',
                          icon: Icons.badge_outlined,
                          image: documentBackImage.value,
                          onUpload: () => _showImageSourceDialog(isBack: true),
                          onRemove: () => documentBackImage.value = null,
                        ),
                      ],
                    )
                  : const SizedBox()),
              const SizedBox(height: 24),

              // Submit button
              Obx(() => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (selectedDocumentType.value != null &&
                              documentFrontImage.value != null &&
                              documentBackImage.value != null &&
                              !isUploadingDocument.value)
                          ? _submitVerification
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeSystem.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isUploadingDocument.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Soumettre pour vérification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      enableDrag: false,
    );
  }

  /// Build document upload card
  Widget _buildDocumentUploadCard({
    required String title,
    required IconData icon,
    required File? image,
    required VoidCallback onUpload,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: image != null ? Colors.green : Colors.grey[300]!,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: image == null
          ? InkWell(
              onTap: onUpload,
              child: Column(
                children: [
                  Icon(icon, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Appuyez pour ajouter',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    image,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Show image source dialog (Camera or Gallery)
  void _showImageSourceDialog({required bool isBack}) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.isDarkMode(Get.context!)
              ? AppThemeSystem.darkCardColor
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choisir la source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Camera
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Appareil photo'),
              subtitle: const Text('Prendre une photo'),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.camera, isBack: isBack);
              },
            ),
            const SizedBox(height: 8),

            // Gallery
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Galerie'),
              subtitle: const Text('Sélectionner depuis la galerie'),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.gallery, isBack: isBack);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source, {required bool isBack}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        if (isBack) {
          documentBackImage.value = file;
        } else {
          documentFrontImage.value = file;
        }
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Impossible de sélectionner l\'image',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Submit verification documents
  Future<void> _submitVerification() async {
    if (selectedDocumentType.value == null ||
        documentFrontImage.value == null ||
        documentBackImage.value == null) {
      return;
    }

    isUploadingDocument.value = true;

    try {
      await _diaspoService.uploadVerificationDocument(
        frontImage: documentFrontImage.value!,
        backImage: documentBackImage.value!,
        documentType: selectedDocumentType.value!,
      );

      isUploadingDocument.value = false;
      Get.back(); // Close bottom sheet

      final docTypeName = selectedDocumentType.value == 'cni' ? 'CNI' : 'Passeport';
      Get.snackbar(
        'Succès',
        'Votre $docTypeName a été soumis pour vérification. Vous recevrez une notification dans 24-48h.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      // Reload verification status
      await loadVerificationStatus();
    } catch (e) {
      isUploadingDocument.value = false;
      Get.snackbar(
        'Erreur',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
