import 'package:get/get.dart';
import '../controllers/inventory_list_controller.dart';
import '../../storeManagement/controllers/store_management_controller.dart';

class InventoryListBinding extends Bindings {
  @override
  void dependencies() {
    // L'inventaire peut s'ouvrir directement, sans passage par la boutique.
    if (!Get.isRegistered<StoreManagementController>()) {
      Get.lazyPut<StoreManagementController>(() => StoreManagementController());
    }
    Get.lazyPut<InventoryListController>(() => InventoryListController());
  }
}
