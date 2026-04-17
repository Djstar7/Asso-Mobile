import 'package:get/get.dart';

import '../controllers/product_controller.dart';

class ProductBinding extends Bindings {
  @override
  void dependencies() {
    // Use lazyPut with fenix: true to auto-recreate controller on navigation
    Get.lazyPut<ProductController>(
      () => ProductController(),
      fenix: true,
    );
  }
}
