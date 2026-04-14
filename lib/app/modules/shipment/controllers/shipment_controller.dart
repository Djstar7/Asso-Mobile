import 'package:get/get.dart';
import '../../myOrder/controllers/my_order_controller.dart';

class ShipmentController extends GetxController {
  late final MyOrderController orderController;

  @override
  void onInit() {
    super.onInit();
    orderController = Get.find<MyOrderController>();
    orderController.loadOrders(refresh: true);
  }
}
