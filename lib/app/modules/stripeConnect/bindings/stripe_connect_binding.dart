import 'package:get/get.dart';

import '../controllers/stripe_connect_controller.dart';

class StripeConnectBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<StripeConnectController>(() => StripeConnectController());
  }
}
