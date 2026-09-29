import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/providers/currency_service.dart';
import '../../../core/utils/string_utils.dart';
import '../../diaspoList/controllers/diaspo_list_controller.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';

class DiaspoDetailController extends GetxController {
  final DiaspoService _diaspoService = Get.find<DiaspoService>();

  final offer = Rx<DiaspoOffer?>(null);
  final isLoading = false.obs;
  final isDeleting = false.obs;
  final isMyOffer = false.obs; // État réactif au lieu d'un getter

  @override
  void onInit() {
    super.onInit();
    _loadOffer();
  }

  void _loadOffer() {
    final args = Get.arguments;
    if (args is! Map) return;
    final passed = args['offer'];
    if (passed is DiaspoOffer) {
      offer.value = passed;
      _checkIfMyOffer(); // Vérifier si c'est mon offre
      return;
    }
    // Une notification transporte l'identifiant en texte (les données FCM
    // sont toujours des chaînes) : `as int` levait dans `onInit` et laissait
    // un écran d'erreur à la place de l'offre.
    final id = int.tryParse('${args['offerId'] ?? ''}');
    if (id != null) _fetchOffer(id);
  }

  /// Vérifier si l'offre appartient à l'utilisateur actuel
  void _checkIfMyOffer() {
    if (offer.value == null) {
      isMyOffer.value = false;
      return;
    }
    final currentUser = StorageService.getUser();
    isMyOffer.value = currentUser != null && offer.value!.userId == currentUser.id;
  }

  Future<void> _fetchOffer(int id) async {
    isLoading.value = true;
    try {
      final fetchedOffer = await _diaspoService.getOffer(id);
      offer.value = fetchedOffer;
      _checkIfMyOffer(); // Vérifier si c'est mon offre après le fetch
    } catch (e) {
      Get.snackbar(
        'diaspo_detail.error'.tr,
        'diaspo_detail.load_error'.tr,
      );
      // Pas `Get.back()` : avec le snackbar tout juste ouvert, il se
      // contentait de le refermer et laissait l'utilisateur sur une page vide.
      // Page déjà quittée : rien à fermer.
      if (!isClosed) AppNavigation.pop();
    } finally {
      isLoading.value = false;
    }
  }

  /// Navigate to chat with Diaspo offer tagging
  Future<void> openChat() async {
    if (offer.value == null) return;

    try {
      // Créer ou obtenir une conversation avec l'utilisateur et l'offre Diaspo
      final response = await ConversationService.startConversation(
        userId: offer.value!.userId,
        diaspoOfferId: offer.value!.id,
      );

      if (response.success && response.data != null) {
        final conversationData = response.data!['conversation'];
        final otherUser = conversationData['other_user'];
        final userName = otherUser?['name'] ?? 'diaspo_detail.user_fallback'.tr;

        // Naviguer vers le chat avec les données de la conversation et l'offre Diaspo
        Get.toNamed('/chatdetail', arguments: {
          'id': conversationData['id'].toString(),
          'name': userName,
          'avatar': StringUtils.getInitials(userName),
          'isOnline': false,
          'diaspo_offer': {
            'id': offer.value!.id,
            'departure_city': offer.value!.departureCity,
            'departure_country': offer.value!.departureCountry,
            'arrival_city': offer.value!.arrivalCity,
            'arrival_country': offer.value!.arrivalCountry,
            'price_per_kg': offer.value!.pricePerKg,
            'currency': offer.value!.currency,
            'remaining_kg': offer.value!.remainingKg,
          },
          'default_message': 'diaspo_detail.chat_default_message'.tr,
        });
      } else {
        Get.snackbar(
          'diaspo_detail.error'.tr,
          'diaspo_detail.chat_start_error'.tr,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'diaspo_detail.error'.tr,
        'diaspo_detail.generic_error'.trParams({'error': e.toString()}),
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Navigate to booking
  void openBooking() {
    if (offer.value == null) return;

    Get.toNamed('/diaspo/booking', arguments: {
      'offer': offer.value,
    });
  }

  /// Navigate to edit offer
  void editOffer() {
    if (offer.value == null) return;

    Get.toNamed('/diaspo/edit', arguments: {
      'offer': offer.value,
    })?.then((result) {
      // Refresh offer if edited
      if (result == true && offer.value != null) {
        _fetchOffer(offer.value!.id);

        // Notify DiaspoListController to refresh
        try {
          final diaspoListController = Get.find<DiaspoListController>();
          diaspoListController.refresh();
        } catch (e) {
          // DiaspoListController not found, ignore
        }
      }
    });
  }

  /// Delete offer with confirmation
  void deleteOffer() {
    if (offer.value == null) return;

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppDesign.accent),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                'diaspo_detail.delete_dialog.title'.tr,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text('diaspo_detail.delete_dialog.message'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('diaspo_detail.cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _performDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesign.danger,
            ),
            child: Text('diaspo_detail.delete'.tr),
          ),
        ],
      ),
    );
  }

  /// Perform the actual deletion
  Future<void> _performDelete() async {
    if (offer.value == null) return;

    isDeleting.value = true;
    try {
      await _diaspoService.deleteOffer(offer.value!.id);

      // Notify DiaspoListController to refresh
      try {
        final diaspoListController = Get.find<DiaspoListController>();
        diaspoListController.refresh();
      } catch (e) {
        // DiaspoListController not found, ignore
      }

      Get.back(); // Return to previous screen
      Get.snackbar(
        'diaspo_detail.success'.tr,
        'diaspo_detail.delete_success'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.success,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'diaspo_detail.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
    } finally {
      isDeleting.value = false;
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
