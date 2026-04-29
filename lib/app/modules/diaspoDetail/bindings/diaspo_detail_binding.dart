import 'package:get/get.dart';
import '../controllers/diaspo_detail_controller.dart';
import '../../../data/providers/diaspo_service.dart';

class DiaspoDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DiaspoService>(() => DiaspoService());
    Get.lazyPut<DiaspoDetailController>(() => DiaspoDetailController());
  }
}
