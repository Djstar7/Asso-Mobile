import 'package:get/get.dart';
import '../../storeManagement/models/store_models.dart';
import '../../storeManagement/controllers/store_management_controller.dart';

class InventoryListController extends GetxController {
  final Rx<InventoryType?> selectedFilter = Rx<InventoryType?>(null);

  // Récupérer le StoreManagementController pour accéder aux données d'inventaire
  StoreManagementController get storeController => Get.find<StoreManagementController>();

  /// Liste filtrée des entrées d'inventaire
  List<InventoryEntry> get filteredInventory {
    final entries = storeController.inventoryEntries;

    if (selectedFilter.value == null) {
      return entries;
    }

    return entries.where((entry) => entry.type == selectedFilter.value).toList();
  }

  /// Changer le filtre
  void changeFilter(InventoryType? type) {
    selectedFilter.value = type;
  }

  /// Voir les détails d'une entrée
  void viewEntryDetails(InventoryEntry entry) {
    storeController.viewInventoryDetails(entry);
  }
}
