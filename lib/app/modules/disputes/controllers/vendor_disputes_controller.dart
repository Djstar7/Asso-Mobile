import 'package:get/get.dart';

import '../../../data/providers/currency_service.dart';
import '../../../data/providers/dispute_service.dart';
import '../../../routes/app_pages.dart';
import '../models/dispute_models.dart';

/// Réclamations reçues par le vendeur : en cours, puis clôturées.
class VendorDisputesController extends GetxController {
  final disputes = <Dispute>[].obs;
  final isLoading = true.obs;
  final filter = 'open'.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = disputes.isEmpty;
    final response = await DisputeService.vendorDisputes(status: filter.value);
    if (response.success) {
      disputes.value = ((response.data?['disputes'] as List?) ?? const [])
          .whereType<Map>()
          .map((d) => Dispute.fromMap(Map<String, dynamic>.from(d)))
          .toList();
    }
    isLoading.value = false;
  }

  void setFilter(String value) {
    if (filter.value == value) return;
    filter.value = value;
    disputes.clear();
    load();
  }

  Future<void> open(Dispute dispute) async {
    await Get.toNamed(Routes.DISPUTE_DETAIL, arguments: {'id': dispute.id, 'role': 'vendor'});
    await load();
  }

  String formatPrice(double amount) => Get.isRegistered<CurrencyService>()
      ? CurrencyService.to.formatPrice(amount)
      : '${amount.toStringAsFixed(0)} FCFA';
}
