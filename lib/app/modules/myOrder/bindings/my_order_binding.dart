import 'package:get/get.dart';

import '../../tracking/controllers/tracking_controller.dart';
import '../controllers/my_order_controller.dart';

/// « Mes commandes » s'ouvre sur la page Suivi (onglets Commandes / Suivi) :
/// les deux contrôleurs sont nécessaires.
class MyOrderBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MyOrderController>(
      () => MyOrderController(),
    );
    if (!Get.isRegistered<TrackingController>()) {
      Get.lazyPut<TrackingController>(() => TrackingController());
    }
  }
}
