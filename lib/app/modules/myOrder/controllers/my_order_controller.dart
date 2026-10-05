import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/providers/order_service.dart';
import '../../../data/providers/wallet_service.dart';
import '../../../data/providers/currency_service.dart';
import '../models/customer_order_models.dart';
import '../../payment/deposit_balance_payment.dart';
import '../../../core/utils/app_design.dart';

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
      Get.snackbar('my_order.errors.title'.tr, 'my_order.errors.load_orders'.tr,
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
        Get.snackbar('my_order.success_title'.tr, 'my_order.cancelled_message'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        loadOrders(refresh: true);
      } else {
        Get.snackbar('my_order.errors.title'.tr, response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar('my_order.errors.title'.tr, 'my_order.errors.cancel_order'.tr,
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
        Get.snackbar('my_order.errors.title'.tr, 'my_order.errors.call_number'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar('my_order.errors.title'.tr, 'my_order.errors.contact_deliverer'.tr,
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
        Get.snackbar('my_order.success_title'.tr, 'my_order.delivery_confirmed'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.primary,
          colorText: Get.theme.colorScheme.onPrimary,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        loadOrders(refresh: true);
      } else {
        Get.snackbar('my_order.errors.title'.tr, response.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar('my_order.errors.title'.tr, 'my_order.errors.confirm_delivery'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Commande transporteur : l'acheteur confirme lui-même la réception du colis.
  Future<void> confirmReception(CustomerOrder order) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('my_order.reception_dialog.title'.tr),
        content: Text('my_order.reception_dialog.message'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('my_order.reception_dialog.not_yet'.tr),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text(
              'my_order.reception_dialog.confirm'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final id = int.tryParse(order.id);
    if (id == null) return;
    final response = await OrderService.confirmReception(id);
    if (response.success) {
      Get.snackbar('my_order.thanks_title'.tr, response.message.isNotEmpty && response.message != 'Succès'
              ? response.message
              : 'my_order.reception_confirmed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      await loadOrders(refresh: true);
    } else {
      Get.snackbar('my_order.errors.title'.tr, response.message.isNotEmpty ? response.message : 'my_order.errors.confirm_reception'.tr,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Get.theme.colorScheme.error,
        colorText: Get.theme.colorScheme.onError,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Commande avec acompte en cours de paiement du solde (bouton occupé).
  final RxnString payingBalanceOrderId = RxnString();

  /// Commande avec acompte : le client paie le solde, débloqué après la
  /// livraison et la vérification du produit avec ASSO.
  Future<void> payBalance(CustomerOrder order) async {
    final info = order.deposit;
    final id = int.tryParse(order.id);
    if (info == null || id == null || payingBalanceOrderId.value != null) return;

    payingBalanceOrderId.value = order.id;
    try {
      await DepositBalancePayment.pay(
        orderId: id,
        orderNumber: order.orderNumber ?? order.id,
        info: info,
      );
    } finally {
      payingBalanceOrderId.value = null;
      await loadOrders(refresh: true);
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
        Get.snackbar('my_order.thanks_title'.tr, 'my_order.rating_dialog.sent'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppDesign.success,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        loadOrders(refresh: true);
      } else {
        Get.snackbar('my_order.errors.title'.tr, response.message.isNotEmpty ? response.message : 'my_order.errors.rate'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Get.theme.colorScheme.error,
          colorText: Get.theme.colorScheme.onError,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar('my_order.errors.title'.tr, 'my_order.errors.send_rating'.tr,
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
        // Clavier ouvert sur le commentaire, les étoiles et le champ ne
        // tiennent plus sur un petit écran : le contenu défile au lieu de
        // déborder.
        scrollable: true,
        title: Text('my_order.rating_dialog.title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'my_order.rating_dialog.order'.trParams({
                'number': order.orderNumber ?? order.id,
              }),
            ),
            const SizedBox(height: 16),
            Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => selectedRating.value = i + 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < selectedRating.value ? Icons.star_rounded : Icons.star_border_rounded,
                    color: i < selectedRating.value ? AppDesign.warning : Colors.grey,
                    size: 40,
                  ),
                ),
              )),
            )),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: InputDecoration(
                hintText: 'my_order.rating_dialog.comment_hint'.tr,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('my_order.rating_dialog.later'.tr),
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
            child: Text('my_order.rating_dialog.send'.tr),
          )),
        ],
      ),
    );
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
