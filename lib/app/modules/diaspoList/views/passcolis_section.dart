import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/maritime_service.dart';
import '../../maritime/controllers/maritime_controller.dart';
import '../controllers/diaspo_list_controller.dart';
import 'diaspo_list_view.dart';

/// Le même parcours que Diaspo Exchange, dans l'onglet Recherche.
class PasscolisSection extends StatefulWidget {
  const PasscolisSection({super.key, this.embedded = true});

  final bool embedded;

  @override
  State<PasscolisSection> createState() => _PasscolisSectionState();
}

class _PasscolisSectionState extends State<PasscolisSection> {
  static int _hosts = 0;
  static DiaspoListController? _ownedDiaspo;
  static MaritimeController? _ownedMaritime;
  late final DiaspoListController _diaspo;
  late final MaritimeController _maritime;

  @override
  void initState() {
    super.initState();
    _hosts++;
    if (!Get.isRegistered<DiaspoService>()) Get.put(DiaspoService());
    if (!Get.isRegistered<MaritimeService>()) Get.put(MaritimeService());

    // Les fiches ouvertes au-dessus de la recherche retrouvent ces mêmes
    // contrôleurs pour actualiser les offres et les réservations au retour.
    // Le dernier hôte libère les contrôleurs créés par ce groupe de vues.
    if (!Get.isRegistered<DiaspoListController>()) {
      _ownedDiaspo = Get.put<DiaspoListController>(
        DiaspoListController(),
        permanent: true,
      );
    }
    if (!Get.isRegistered<MaritimeController>()) {
      _ownedMaritime = Get.put<MaritimeController>(
        MaritimeController(),
        permanent: true,
      );
    }
    _diaspo = Get.find<DiaspoListController>();
    _maritime = Get.find<MaritimeController>();
  }

  @override
  void dispose() {
    // AnimatedSwitcher conserve l'ancienne section pendant la transition.
    // Une section qui sort ne doit pas détruire les contrôleurs d'une autre
    // section déjà montée (onglet rouvert rapidement ou recherche empilée).
    _hosts--;
    if (_hosts == 0 &&
        _ownedDiaspo != null &&
        Get.isRegistered<DiaspoListController>() &&
        identical(Get.find<DiaspoListController>(), _ownedDiaspo)) {
      Get.delete<DiaspoListController>(force: true);
    }
    if (_hosts == 0 &&
        _ownedMaritime != null &&
        Get.isRegistered<MaritimeController>() &&
        identical(Get.find<MaritimeController>(), _ownedMaritime)) {
      Get.delete<MaritimeController>(force: true);
    }
    if (_hosts == 0) {
      _ownedDiaspo = null;
      _ownedMaritime = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DiaspoListView(
    embedded: widget.embedded,
    pageController: _diaspo,
    freightController: _maritime,
  );
}
