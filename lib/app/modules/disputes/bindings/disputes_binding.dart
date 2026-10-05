import 'package:get/get.dart';

import '../controllers/dispute_detail_controller.dart';
import '../controllers/similar_products_controller.dart';
import '../controllers/vendor_disputes_controller.dart';

class DisputeDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DisputeDetailController>(() => DisputeDetailController());
  }
}

class VendorDisputesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VendorDisputesController>(() => VendorDisputesController());
  }
}

class SimilarProductsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SimilarProductsController>(() => SimilarProductsController());
  }
}
