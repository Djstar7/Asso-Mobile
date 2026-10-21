import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/providers/diaspo_service.dart';
import '../../../data/providers/maritime_service.dart';
import '../../maritime/controllers/maritime_controller.dart';
import '../controllers/diaspo_list_controller.dart';
import 'diaspo_list_view.dart';

/// Le même parcours que Diaspo Exchange, dans l'onglet Recherche.
class PasscolisSection extends StatefulWidget {
  const PasscolisSection({super.key});

  @override
  State<PasscolisSection> createState() => _PasscolisSectionState();
}

class _PasscolisSectionState extends State<PasscolisSection> {
  DiaspoListController? _ownedDiaspo;
  MaritimeController? _ownedMaritime;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<DiaspoService>()) Get.put(DiaspoService());
    if (!Get.isRegistered<MaritimeService>()) Get.put(MaritimeService());

    // Les fiches ouvertes au-dessus de la recherche retrouvent ces mêmes
    // contrôleurs pour actualiser les offres et les réservations au retour.
    // Seule cette section libère les contrôleurs qu'elle a créés.
    if (!Get.isRegistered<DiaspoListController>()) {
      _ownedDiaspo = Get.put(DiaspoListController(), permanent: true);
    }
    if (!Get.isRegistered<MaritimeController>()) {
      _ownedMaritime = Get.put(MaritimeController(), permanent: true);
    }
  }

  @override
  void dispose() {
    if (_ownedDiaspo != null &&
        Get.isRegistered<DiaspoListController>() &&
        identical(Get.find<DiaspoListController>(), _ownedDiaspo)) {
      Get.delete<DiaspoListController>(force: true);
    }
    if (_ownedMaritime != null &&
        Get.isRegistered<MaritimeController>() &&
        identical(Get.find<MaritimeController>(), _ownedMaritime)) {
      Get.delete<MaritimeController>(force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const DiaspoListView(embedded: true);
}
