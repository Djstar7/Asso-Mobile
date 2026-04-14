import 'package:get/get.dart';
import '../../myOrder/controllers/my_order_controller.dart';

class ShipmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(MyOrderController());
  }
}
