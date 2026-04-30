import 'package:get/get.dart';
import '../controllers/country_selection_controller.dart';

class CountrySelectionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CountrySelectionController>(
      () => CountrySelectionController(),
    );
  }
}
