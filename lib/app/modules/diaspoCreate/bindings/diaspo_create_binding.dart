import 'package:get/get.dart';
import '../controllers/diaspo_create_controller.dart';
import '../../../data/providers/diaspo_service.dart';

class DiaspoCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DiaspoService>(() => DiaspoService());
    Get.lazyPut<DiaspoCreateController>(() => DiaspoCreateController());
  }
}
