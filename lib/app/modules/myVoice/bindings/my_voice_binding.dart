import 'package:get/get.dart';
import '../controllers/my_voice_controller.dart';

class MyVoiceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MyVoiceController>(() => MyVoiceController());
  }
}
