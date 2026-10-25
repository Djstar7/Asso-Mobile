import 'package:get/get.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/maritime_service.dart';

class DiaspoListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DiaspoService>(() => DiaspoService());
    Get.lazyPut<MaritimeService>(() => MaritimeService());
  }
}
