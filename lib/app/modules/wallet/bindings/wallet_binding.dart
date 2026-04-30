import 'package:get/get.dart';

import '../controllers/wallet_controller.dart';
import '../../../data/services/wallet_service.dart';
import '../../../data/providers/diaspo_service.dart';

class WalletBinding extends Bindings {
  @override
  void dependencies() {
    // Initialiser le service diaspo
    Get.lazyPut<DiaspoService>(() => DiaspoService());

    // Initialiser le service wallet
    Get.lazyPut<WalletService>(() => WalletService());

    // Initialiser le controller
    Get.lazyPut<WalletController>(() => WalletController());
  }
}
