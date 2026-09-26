import 'package:get/get.dart';
import '../../../data/providers/diaspo_service.dart';

class DiaspoDetailBinding extends Bindings {
  @override
  void dependencies() {
    // Le contrôleur est propre à chaque page (voir `DiaspoDetailPage`).
    Get.lazyPut<DiaspoService>(() => DiaspoService());
  }
}
