import 'package:get/get.dart';
import '../controllers/shop_statistics_controller.dart';

class ShopStatisticsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShopStatisticsController>(() => ShopStatisticsController());
  }
}
