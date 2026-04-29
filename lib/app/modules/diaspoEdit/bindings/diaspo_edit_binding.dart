import 'package:get/get.dart';
import '../controllers/diaspo_edit_controller.dart';

class DiaspoEditBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DiaspoEditController>(
      () => DiaspoEditController(),
    );
  }
}
