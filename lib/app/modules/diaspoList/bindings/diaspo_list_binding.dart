import 'package:get/get.dart';
import '../controllers/diaspo_list_controller.dart';
import '../../../data/providers/diaspo_service.dart';

class DiaspoListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DiaspoService>(() => DiaspoService());
    Get.lazyPut<DiaspoListController>(() => DiaspoListController());
  }
}
