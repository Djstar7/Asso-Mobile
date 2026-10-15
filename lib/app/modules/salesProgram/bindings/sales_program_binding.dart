import 'package:get/get.dart';
import '../controllers/sales_program_controller.dart';

class SalesProgramBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SalesProgramController>(() => SalesProgramController());
  }
}
