import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../tracking/controllers/tracking_controller.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../wallet/controllers/wallet_controller.dart';
import '../../myVoice/controllers/my_voice_controller.dart';
import '../../../data/services/wallet_service.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    print('');
    print('========================================');
    print('🔧 HOME BINDING: dependencies() CALLED');
    print('========================================');

    // Initialiser les services nécessaires d'abord
    Get.lazyPut<WalletService>(() => WalletService());

    // Créer les controllers des onglets AVANT HomeController
    // Utiliser put() au lieu de lazyPut() pour créer immédiatement
    // car TabBarView a besoin d'eux dès le premier build
    // permanent: true pour éviter la dispose pendant la navigation
    Get.put<ChatController>(
      ChatController(),
      permanent: true,
    );
    print('  └─ ✅ ChatController created (permanent)');

    Get.put<WalletController>(
      WalletController(),
      permanent: true,
    );
    print('  └─ ✅ WalletController created (permanent)');

    Get.put<TrackingController>(
      TrackingController(),
      permanent: true,
    );
    print('  └─ ✅ TrackingController created (permanent)');

    Get.put<MyVoiceController>(
      MyVoiceController(),
      permanent: true,
    );
    print('  └─ ✅ MyVoiceController created (permanent)');

    Get.put<ProfileController>(
      ProfileController(),
      permanent: true,
    );
    print('  └─ ✅ ProfileController created (permanent)');

    // Créer HomeController en dernier
    // permanent: true pour éviter que le TabController soit disposé pendant la navigation
    Get.put<HomeController>(
      HomeController(),
      permanent: true,
    );
    print('  └─ ✅ HomeController created (permanent)');

    print('✅ HOME BINDING: All dependencies registered');
    print('========================================');
    print('');
  }
}
