import 'package:get/get.dart';

import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/maritime_service.dart';
import '../controllers/maritime_booking_controller.dart';

class MaritimeBookingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DiaspoService>(() => DiaspoService());
    Get.lazyPut<MaritimeService>(() => MaritimeService());
    Get.lazyPut<MaritimeBookingController>(() => MaritimeBookingController());
  }
}
