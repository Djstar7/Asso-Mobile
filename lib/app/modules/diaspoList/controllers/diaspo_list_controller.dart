import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/models/diaspo_booking.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/media_helper.dart';
import '../../../routes/app_pages.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/widgets/app_sheet.dart';

class DiaspoListController extends GetxController {
  final DiaspoService _diaspoService = Get.find<DiaspoService>();

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
  // Échéance la plus proche avant retrait d'une offre « Profil non vérifié ».
  final Rx<DateTime?> nextVerificationDeadline = Rx<DateTime?>(null);

  // Document upload
  final Rx<String?> selectedDocumentType = Rx<String?>(
    null,
  ); // 'cni' or 'passport'
  final Rx<XFile?> documentFrontImage = Rx<XFile?>(null);
  final Rx<XFile?> documentBackImage = Rx<XFile?>(null);
  final isUploadingDocument = false.obs;

  // Pagination
  int currentPage = 1;
  bool hasMore = true;

  // Selected tab: 0 = Tous, 1 = Mes Offres, 2 = Mes Achats, 3 = Mes Ventes
  final selectedTab = 0.obs;

  // 🔍 Recherche (remplace les filtres)
  final searchQuery = ''.obs;

  /// Liste filtrée selon le texte recherché
  List<DiaspoOffer> get filteredOffers {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return offers;

    return offers.where((offer) {
      return offer.departureCity.toLowerCase().contains(query) ||
          offer.departureCountry.toLowerCase().contains(query) ||
          offer.arrivalCity.toLowerCase().contains(query) ||
          offer.arrivalCountry.toLowerCase().contains(query);
    }).toList();
  }

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
        verificationStatus.value =
            response['data']['verification_status'] ?? 'unverified';
        canCreateOffers.value = response['data']['can_create_offers'] ?? false;
        final deadline = response['data']['next_deadline'];
        nextVerificationDeadline.value = deadline != null
            ? DateTime.tryParse(deadline)?.toLocal()
            : null;
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
    if (!_isInitialLoad &&
        (isLoading.value || (isLoadingMore.value && !refresh)))
      return;

    // Set loading state: use isLoading for initial/refresh, isLoadingMore for pagination
    if (_isInitialLoad || refresh) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    _isInitialLoad = false; // Mark initial load as done

    try {
      final response = await _diaspoService.getOffers(page: currentPage);

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
        'diaspo_list.error'.tr,
        'diaspo_list.load_offers_error'.tr,
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

  // Validation de code (voyageur) / confirmation de réception (acheteur)
  final isValidatingCode = false.obs;

  /// Le voyageur valide le code de livraison remis par l'acheteur.
  Future<void> sellerConfirmCode(int bookingId, String code) async {
    if (isValidatingCode.value) return;
    isValidatingCode.value = true;
    try {
      await _diaspoService.sellerConfirmDelivery(
        bookingId: bookingId,
        confirmationCode: code,
      );
      Get.back(); // fermer le dialogue
      Get.snackbar(
        'diaspo_list.code_validated_title'.tr,
        'diaspo_list.code_validated_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.successColor,
        colorText: Colors.white,
      );
      await loadMyBookingsAsSeller();
    } catch (e) {
      Get.snackbar(
        'diaspo_list.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    } finally {
      isValidatingCode.value = false;
    }
  }

  /// L'acheteur confirme la réception de son colis (libère les fonds au voyageur).
  Future<void> confirmReceipt(int bookingId, String code) async {
    if (isValidatingCode.value) return;
    isValidatingCode.value = true;
    try {
      await _diaspoService.confirmReceipt(
        bookingId: bookingId,
        confirmationCode: code,
      );
      Get.back();
      await loadMyBookingsAsBuyer();
      _showReceiptConfirmedDialog();
    } catch (e) {
      Get.snackbar(
        'diaspo_list.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppThemeSystem.errorColor,
        colorText: Colors.white,
      );
    } finally {
      isValidatingCode.value = false;
    }
  }

  /// Confirmation de réception : on annonce le déblocage des fonds et on
  /// propose d'aller voir le portefeuille, plutôt qu'un simple message fugace.
  void _showReceiptConfirmedDialog() {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppThemeSystem.successColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: AppThemeSystem.successColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('diaspo_list.receipt_confirmed.title'.tr)),
          ],
        ),
        content: Text('diaspo_list.receipt_confirmed.message'.tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('diaspo_list.close'.tr)),
          ElevatedButton.icon(
            onPressed: () {
              Get.back();
              Get.toNamed(Routes.WALLET);
            },
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: Text('diaspo_list.receipt_confirmed.view_wallet'.tr),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeSystem.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
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
    await loadVerificationStatus();
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

  /// Check if an offer belongs to the current user
  bool isMyOffer(DiaspoOffer offer) {
    final currentUser = StorageService.getUser();
    if (currentUser == null) return false;
    return offer.userId == currentUser.id;
  }

  /// Échéance de régularisation formatée (jj/mm/aaaa), ou null.
  String? get formattedNextDeadline {
    final d = nextVerificationDeadline.value;
    if (d == null) return null;
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  /// Handle create offer button
  void handleCreateOffer() {
    // L'identité n'empêche pas la publication : l'offre est en ligne avec la
    // mention « Profil non vérifié » jusqu'à la validation de l'identité.
    Get.toNamed('/diaspo/create');
  }

  /// Ouvre le parcours de vérification sans bloquer la création d'une offre.
  void handleVerification() {
    if (verificationStatus.value == 'verified') {
      Get.snackbar(
        'diaspo_list.identity_verified_title'.tr,
        'diaspo_list.identity_verified_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    _showVerificationDialog();
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
                const Icon(Icons.hourglass_empty, color: AppDesign.accent),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'diaspo_list.verification.pending_title'.tr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Text('diaspo_list.verification.pending_message'.tr),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text('diaspo_list.ok'.tr)),
            ],
          ),
        );
        break;

      case 'rejected':
        Get.dialog(
          AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.error_outline, color: AppDesign.danger),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'diaspo_list.verification.rejected_title'.tr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Text(
              '${'diaspo_list.verification.rejected_intro'.tr}\n\n'
              '${formattedNextDeadline != null ? '${'diaspo_list.verification.rejected_deadline'.trParams({'date': formattedNextDeadline!})}\n\n' : ''}'
              '${'diaspo_list.verification.rejected_question'.tr}',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('diaspo_list.cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  _showUploadVerificationBottomSheet();
                },
                child: Text('diaspo_list.verification.resubmit'.tr),
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
                const Icon(Icons.verified_user, color: AppDesign.info),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'diaspo_list.verification.required_title'.tr,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Text('diaspo_list.verification.required_message'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('diaspo_list.verification.later'.tr),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  _showUploadVerificationBottomSheet();
                },
                child: Text('diaspo_list.verification.verify_now'.tr),
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

    // Feuille haute (deux photos) : sans plafond, elle passait sous la barre
    // d'état. Le bouton d'envoi reste épinglé en bas, toujours visible.
    AppSheet.show(
      AppSheet(
        title: 'diaspo_list.verification.sheet_title'.tr,
        footer: Obx(
          () => SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  (selectedDocumentType.value != null &&
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
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      'diaspo_list.verification.submit'.tr,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'diaspo_list.verification.sheet_intro'.tr,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Document type selection
            Text(
              'diaspo_list.verification.document_type'.tr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Obx(
              () => Row(
                children: [
                  // CNI option
                  Expanded(
                    child: GestureDetector(
                      onTap: () => selectedDocumentType.value = 'cni',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selectedDocumentType.value == 'cni'
                              ? AppThemeSystem.primaryColor.withValues(
                                  alpha: 0.1,
                                )
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
                              'diaspo_list.verification.id_card'.tr,
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
                              'diaspo_list.verification.id_card_subtitle'.tr,
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
                              ? AppThemeSystem.primaryColor.withValues(
                                  alpha: 0.1,
                                )
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
                              'diaspo_list.verification.passport'.tr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color:
                                    selectedDocumentType.value == 'passport'
                                    ? AppThemeSystem.primaryColor
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'diaspo_list.verification.passport_subtitle'.tr,
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
              ),
            ),
            const SizedBox(height: 24),

            // Photos section (only show if document type is selected)
            Obx(
              () => selectedDocumentType.value != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'diaspo_list.verification.document_photos'.tr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Recto
                        _buildDocumentUploadCard(
                          title: 'diaspo_list.verification.front'.tr,
                          icon: Icons.badge,
                          image: documentFrontImage.value,
                          onUpload: () => _pickDocumentImage(isBack: false),
                          onRemove: () => documentFrontImage.value = null,
                        ),
                        const SizedBox(height: 16),

                        // Verso
                        _buildDocumentUploadCard(
                          title: 'diaspo_list.verification.back'.tr,
                          icon: Icons.badge_outlined,
                          image: documentBackImage.value,
                          onUpload: () => _pickDocumentImage(isBack: true),
                          onRemove: () => documentBackImage.value = null,
                        ),
                      ],
                    )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
      enableDrag: false,
    );
  }

  /// Build document upload card
  Widget _buildDocumentUploadCard({
    required String title,
    required IconData icon,
    required XFile? image,
    required VoidCallback onUpload,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: image != null ? AppDesign.success : Colors.grey[300]!,
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
                    'diaspo_list.verification.tap_to_add'.tr,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: MediaHelper.buildImagePreview(
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
                      backgroundColor: AppDesign.danger,
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
                      color: AppDesign.success,
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

  /// Sélectionne l'image d'un document (recto/verso) via le picker de marque
  /// partagé (appareil photo / galerie aux couleurs Asso), compatible web + mobile.
  Future<void> _pickDocumentImage({required bool isBack}) async {
    final XFile? image = await MediaHelper.pickBrandedImage(
      title: isBack
          ? 'diaspo_list.verification.document_back'.tr
          : 'diaspo_list.verification.document_front'.tr,
      subtitle: 'diaspo_list.verification.photo_hint'.tr,
      imageQuality: 85,
    );

    if (image != null) {
      if (isBack) {
        documentBackImage.value = image;
      } else {
        documentFrontImage.value = image;
      }
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

      final docTypeName = selectedDocumentType.value == 'cni'
          ? 'diaspo_list.verification.id_card'.tr
          : 'diaspo_list.verification.passport'.tr;
      Get.snackbar(
        'diaspo_list.success'.tr,
        'diaspo_list.verification.submitted_message'.trParams({
          'document': docTypeName,
        }),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );

      // Reload verification status
      await loadVerificationStatus();
    } catch (e) {
      isUploadingDocument.value = false;
      Get.snackbar(
        'diaspo_list.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    }
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
