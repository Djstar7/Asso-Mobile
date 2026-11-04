import 'package:get/get.dart';

import '../controllers/web_login_controller.dart';

class WebLoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(WebLoginController.new);
  }
}
