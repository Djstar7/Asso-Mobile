import 'package:get/get.dart';
import '../controllers/diaspo_list_controller.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/maritime_service.dart';
import '../../maritime/controllers/maritime_controller.dart';

class DiaspoListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DiaspoService>(() => DiaspoService());
    Get.lazyPut<DiaspoListController>(() => DiaspoListController());
    Get.lazyPut<MaritimeService>(() => MaritimeService());
    Get.lazyPut<MaritimeController>(() => MaritimeController());
  }
}
