import 'package:get/get.dart';
import '../controllers/inventory_list_controller.dart';

class InventoryListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<InventoryListController>(() => InventoryListController());
  }
}
