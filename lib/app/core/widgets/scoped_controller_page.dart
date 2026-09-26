import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// Page qui possède son propre contrôleur GetX, créé à son ouverture et
/// libéré à sa fermeture.
///
/// Fiche produit, boutique, conversation, offre Diaspo : ces pages s'empilent
/// sous le même nom de route (produit → boutique → produit…). Avec le
/// contrôleur unique d'un `Bindings`, la seconde page reprenait l'état de la
/// première — une seconde conversation envoyait ses messages dans la
/// première —, et fermer ou remplacer l'une libérait le contrôleur que
/// l'autre affichait encore : champs et carrousels sur des contrôleurs
/// détruits, écran d'erreur à la reconstruction suivante.
///
/// Le contrôleur est enregistré sous une étiquette unique, `permanent` pour
/// que GetX ne le supprime pas à la fermeture d'une route voisine : seul
/// [State.dispose] le libère. Il est créé pendant la première construction
/// de la route, quand `Get.arguments` désigne bien ses arguments.
class ScopedControllerPage<T extends GetxController> extends StatefulWidget {
  const ScopedControllerPage({
    super.key,
    required this.create,
    required this.builder,
  });

  final T Function() create;
  final Widget Function(T controller) builder;

  @override
  State<ScopedControllerPage<T>> createState() =>
      _ScopedControllerPageState<T>();
}

class _ScopedControllerPageState<T extends GetxController>
    extends State<ScopedControllerPage<T>> {
  static int _nextId = 0;

  late final String _tag = '$T-page-${_nextId++}';
  late final T _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put<T>(widget.create(), tag: _tag, permanent: true);
  }

  @override
  void dispose() {
    if (Get.isRegistered<T>(tag: _tag)) {
      Get.delete<T>(tag: _tag, force: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}
