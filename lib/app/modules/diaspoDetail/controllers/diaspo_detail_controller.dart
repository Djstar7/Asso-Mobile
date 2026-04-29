import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/models/diaspo_offer.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../diaspoList/controllers/diaspo_list_controller.dart';

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
    if (args != null && args['offer'] != null) {
      offer.value = args['offer'] as DiaspoOffer;
      _checkIfMyOffer(); // Vérifier si c'est mon offre
    } else if (args != null && args['offerId'] != null) {
      _fetchOffer(args['offerId'] as int);
    }
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
      Get.snackbar('Erreur', 'Impossible de charger l\'offre');
      Get.back();
    } finally {
      isLoading.value = false;
    }
  }

  /// Navigate to chat
  void openChat() {
    if (offer.value == null) return;

    Get.toNamed('/chatdetail', arguments: {
      'userId': offer.value!.userId,
      'userName': offer.value!.user?.fullName ?? 'Utilisateur',
    });
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
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Confirmer la suppression',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Voulez-vous vraiment supprimer cette offre ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _performDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
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
        'Succès',
        'Offre supprimée avec succès',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Erreur',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isDeleting.value = false;
    }
  }
}
