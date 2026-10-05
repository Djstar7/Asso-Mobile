import 'package:get/get.dart';

import '../../../data/providers/currency_service.dart';
import '../../../data/providers/dispute_service.dart';

/// Après un remboursement : produits similaires dont le VENDEUR offre la
/// livraison (gratuité de sa boutique ou du produit, à ses frais).
class SimilarProductsController extends GetxController {
  late final int disputeId;

  final products = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    disputeId = int.tryParse('${(Get.arguments as Map?)?['id']}') ?? 0;
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    final response = await DisputeService.similarProducts(disputeId);
    if (response.success) {
      products.value = ((response.data?['products'] as List?) ?? const [])
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
    }
    isLoading.value = false;
  }

  void openProduct(Map<String, dynamic> product) => Get.toNamed('/product', arguments: product);

  String formatPrice(Map<String, dynamic> product) {
    final value = double.tryParse('${product['price_xaf'] ?? product['price'] ?? 0}') ?? 0;
    return Get.isRegistered<CurrencyService>()
        ? CurrencyService.to.formatPrice(value)
        : '${value.toStringAsFixed(0)} FCFA';
  }
}
