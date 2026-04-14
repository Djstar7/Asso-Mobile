import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/wallet_service.dart';
import '../models/customer_order_models.dart';

class MyOrderController extends GetxController {
  final RxList<CustomerOrder> allOrders = <CustomerOrder>[].obs;
  final RxList<CustomerOrder> filteredOrders = <CustomerOrder>[].obs;
  final RxString selectedStatus = 'all'.obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;
  int _currentPage = 1;

  @override
  void onInit() {
    super.onInit();
    loadOrders();
  }

  Future<void> loadOrders({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      hasMore.value = true;
    }

    isLoading.value = true;

    try {
      final response = await OrderService.getOrders(
        page: _currentPage,
        status: selectedStatus.value == 'all' ? null : selectedStatus.value,
      );

      if (response.success && response.data != null) {
        final ordersList = response.data!['orders'] as List? ?? [];
        final pagination = response.data!['pagination'] as Map<String, dynamic>? ?? {};

        final convertedOrders = ordersList
            .map((o) => CustomerOrder.fromMap(Map<String, dynamic>.from(o)))
            .toList();

        if (refresh || _currentPage == 1) {
          allOrders.value = convertedOrders;
        } else {
          allOrders.addAll(convertedOrders);
        }

        filteredOrders.value = List.from(allOrders);
        hasMore.value = pagination['has_more'] ?? false;
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de charger les commandes',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void filterByStatus(String status) {
    selectedStatus.value = status;
    loadOrders(refresh: true);
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    try {
      final response = await OrderService.cancelOrder(int.parse(orderId), reason: reason);
      if (response.success) {
        Get.snackbar('Succès', 'Commande annulée',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        loadOrders(refresh: true);
      } else {
        Get.snackbar('Erreur', response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible d\'annuler la commande',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> contactDelivery(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        Get.snackbar('Erreur', 'Impossible d\'appeler ce numéro',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de contacter le livreur',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  void trackOrder(String orderId) {
    // Navigate to tracking with order ID
    Get.toNamed('/tracking', arguments: {'order_id': orderId});
  }

  /// Client confirms delivery → unlocks money to vendor + delivery person
  Future<void> confirmDelivery(String orderId) async {
    try {
      final response = await WalletService.confirmDelivery(int.parse(orderId));
      if (response.success) {
        Get.snackbar('Succès', 'Livraison confirmée ! Merci.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        loadOrders(refresh: true);
      } else {
        Get.snackbar('Erreur', response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de confirmer la livraison',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Client rate une commande livrée
  Future<void> rateOrder(String orderId, {required int rating, String? comment}) async {
    try {
      final response = await OrderService.rateOrder(
        int.parse(orderId),
        rating: rating,
        comment: comment,
      );

      if (response.success) {
        Get.snackbar('Merci !', 'Votre avis a été envoyé au vendeur.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        loadOrders(refresh: true);
      } else {
        Get.snackbar('Erreur', response.message.isNotEmpty ? response.message : 'Impossible de noter',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible d\'envoyer la note',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Affiche le dialog de notation
  void showRatingDialog(CustomerOrder order) {
    final selectedRating = 0.obs;
    final commentController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Noter votre expérience'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Commande #${order.orderNumber ?? order.id}'),
            const SizedBox(height: 16),
            Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => selectedRating.value = i + 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < selectedRating.value ? Icons.star_rounded : Icons.star_border_rounded,
                    color: i < selectedRating.value ? Colors.amber : Colors.grey,
                    size: 40,
                  ),
                ),
              )),
            )),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: 'Commentaire (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Plus tard'),
          ),
          Obx(() => ElevatedButton(
            onPressed: selectedRating.value > 0
                ? () {
                    Get.back();
                    rateOrder(
                      order.id,
                      rating: selectedRating.value,
                      comment: commentController.text.isNotEmpty ? commentController.text : null,
                    );
                  }
                : null,
            child: const Text('Envoyer'),
          )),
        ],
      ),
    );
  }
}
