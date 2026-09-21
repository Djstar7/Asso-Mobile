import 'package:get/get.dart';
import '../controllers/boost_controller.dart';

class BoostBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<BoostController>(() => BoostController());
  }
}
