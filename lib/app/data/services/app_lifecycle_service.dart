import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/widgets/autoplay_video.dart';

/// Garde-fou mémoire de l'application, à l'échelle de toute sa durée de vie.
///
/// Les murs de produits décodent des dizaines de photos et ouvrent des
/// lecteurs vidéo. Sur les téléphones modestes, une longue session finissait
/// par dépasser ce que le système tolère : l'application était tuée (retour
/// brutal à l'écran d'accueil du téléphone) ou revenait sur un écran noir.
///
/// - le cache d'images décodées est plafonné (le défaut de Flutter, 100 Mo et
///   1 000 images, suppose un téléphone haut de gamme) ;
/// - quand le système signale qu'il manque de mémoire, on rend tout ce qui
///   peut l'être : images hors écran et lecteurs vidéo en pause ;
/// - en arrière-plan, on vide aussi le cache d'images, pour que le système ne
///   tue pas l'application la première quand il récupère de la mémoire.
class AppLifecycleService extends GetxService with WidgetsBindingObserver {
  static AppLifecycleService get to => Get.find<AppLifecycleService>();

  /// Plafond du cache d'images décodées.
  static const int imageCacheBytes = 60 << 20;
  static const int imageCacheEntries = 250;

  @override
  void onInit() {
    super.onInit();
    PaintingBinding.instance.imageCache
      ..maximumSizeBytes = imageCacheBytes
      ..maximumSize = imageCacheEntries;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didHaveMemoryPressure() {
    debugPrint('[Lifecycle] mémoire faible : libération des caches');
    releaseMemory();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Les images encore affichées restent en mémoire (« live ») : seules
      // celles hors écran sont rendues. Elles se rechargent depuis le cache
      // disque au retour.
      PaintingBinding.instance.imageCache.clear();
      AutoplayCoordinator.instance.releaseIdle();
    }
  }

  /// Rend la mémoire récupérable sans rien casser à l'écran.
  static void releaseMemory() {
    final cache = PaintingBinding.instance.imageCache;
    cache.clear();
    cache.clearLiveImages();
    AutoplayCoordinator.instance.releaseIdle();
  }
}
