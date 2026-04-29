import 'package:get/get.dart';
import '../controllers/diaspo_booking_controller.dart';
import '../../../data/providers/diaspo_service.dart';
import '../../../data/services/wallet_service.dart';

class DiaspoBookingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DiaspoService>(() => DiaspoService());
    Get.lazyPut<WalletService>(() => WalletService());
    Get.lazyPut<DiaspoBookingController>(() => DiaspoBookingController());
  }
}
