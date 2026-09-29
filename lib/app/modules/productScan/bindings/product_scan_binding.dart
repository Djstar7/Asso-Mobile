import 'package:get/get.dart';
import '../controllers/product_scan_controller.dart';

class ProductScanBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ProductScanController>(() => ProductScanController());
  }
}
