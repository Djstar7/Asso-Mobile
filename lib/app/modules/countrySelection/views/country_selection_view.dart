import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/country_selection_controller.dart';

/// Choix du pays, et donc de la devise d'affichage des prix.
///
/// C'est le tout premier écran après l'installation : il doit être lisible
/// et neutre. Les pastilles bleues d'origine et le bouton de confirmation
/// bleu ont été remplacés — ils contredisaient l'identité orange de la
/// marque et inversaient la hiérarchie des actions.
///
/// La liste couvre près de deux cents pays. Trois repères la rendent
/// parcourable : des pays suggérés en tête, des sections par initiale, et
/// un index alphabétique sur le bord droit.
class CountrySelectionView extends GetView<CountrySelectionController> {
  const CountrySelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.ds.canvas,
      appBar: AppBar(
        // Premier écran après l'installation, il n'a rien derrière lui : pas
        // de retour. Ouvert par-dessus un autre écran, il en propose un.
        leading: Navigator.canPop(context) ? const AppBackButton() : null,
        title: const Text('Choisissez votre pays'),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: AppContentWidth(
          child: Column(
            children: [
              _SearchHeader(),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value &&
                      controller.allCountries.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (controller.hasError.value &&
                      controller.allCountries.isEmpty) {
                    return _LoadFailure(
                      onRetry: controller.fetchAllCountriesWithCurrencies,
                    );
                  }

                  if (controller.filteredCountries.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Aucun pays trouvé',
                      message:
                          'Essayez avec un autre nom de pays ou un code de devise.',
                    );
                  }

                  return const _CountryList();
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau fixe : explication de l'effet du choix, puis champ de recherche.
class _SearchHeader extends GetView<CountrySelectionController> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space3,
        context.ds.gutter,
        AppDesign.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Les prix et les frais de livraison seront affichés dans la devise du pays choisi.',
            style: context.textStyle(
              FontSizeType.caption,
              color: context.ds.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: AppDesign.space3),
          AppTextField(
            hint: 'Rechercher un pays ou une devise',
            onChanged: controller.filterCountries,
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 20,
              color: context.ds.textTertiary,
            ),
          ),
          // Le nombre de résultats n'apparaît qu'en recherche : au repos il
          // ferait du bruit sans rien apprendre.
          Obx(() {
            if (controller.isBrowsing) return const SizedBox.shrink();
            final count = controller.filteredCountries.length;
            return Padding(
              padding: EdgeInsets.only(top: AppDesign.space2),
              child: Text(
                count > 1 ? '$count pays trouvés' : '$count pays trouvé',
                style: context.textStyle(
                  FontSizeType.overline,
                  color: context.ds.textTertiary,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// La liste elle-même, avec son index alphabétique.
class _CountryList extends StatefulWidget {
  const _CountryList();

  @override
  State<_CountryList> createState() => _CountryListState();
}

class _CountryListState extends State<_CountryList> {
  // Créé une fois pour toutes : instancié dans build(), le défilement
  // repartirait de zéro à chaque changement de filtre.
  final ScrollController scrollController = ScrollController();

  /// Posée sur le bloc de suggestions pour en mesurer la hauteur réelle.
  final GlobalKey _suggestionsKey = GlobalKey();

  CountrySelectionController get controller => Get.find();

  /// Hauteur du bloc de suggestions (en-tête compris), ou 0 s'il est absent.
  double get _suggestionsExtent {
    if (controller.suggestions.isEmpty) return 0;
    final box = _suggestionsKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;
    return _SectionHeaderDelegate._height + box.size.height;
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Obx(() {
          final sections = controller.sections;
          final suggestions = controller.suggestions;
          final browsing = controller.isBrowsing;

          return CustomScrollView(
            controller: scrollController,
            // Parcourir la liste referme le clavier de la recherche, qui
            // en masquait la moitié.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (browsing && suggestions.isNotEmpty) ...[
                _SectionHeaderSliver(
                  label: 'Suggestions',
                  icon: Icons.star_rounded,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    key: _suggestionsKey,
                    padding: EdgeInsets.fromLTRB(
                      context.ds.gutter,
                      AppDesign.space2,
                      context.ds.gutter,
                      AppDesign.space4,
                    ),
                    child: Wrap(
                      spacing: AppDesign.space2,
                      runSpacing: AppDesign.space2,
                      children: [
                        for (final option in suggestions)
                          _SuggestionChip(option: option),
                      ],
                    ),
                  ),
                ),
              ],
              for (final section in sections) ...[
                if (browsing) _SectionHeaderSliver(label: section.letter),
                SliverList.separated(
                  itemCount: section.countries.length,
                  separatorBuilder: (_, _) => Padding(
                    padding: EdgeInsets.only(left: context.ds.gutter + 46),
                    child: const AppDivider(),
                  ),
                  itemBuilder: (context, index) => _CountryTile(
                    option: section.countries[index],
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SizedBox(height: AppDesign.space8),
              ),
            ],
          );
        }),
        // Index alphabétique : seulement quand la liste est complète, car
        // sur un résultat de recherche il pointerait dans le vide.
        Obx(() {
          if (!controller.isBrowsing || controller.sections.length < 5) {
            return const SizedBox.shrink();
          }
          return Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: _AlphabetIndex(
              scrollController: scrollController,
              suggestionsExtent: () => _suggestionsExtent,
            ),
          );
        }),
      ],
    );
  }
}

/// En-tête de section qui reste accroché en haut pendant le défilement.
class _SectionHeaderSliver extends StatelessWidget {
  const _SectionHeaderSliver({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SectionHeaderDelegate(
        label: label,
        icon: icon,
        background: context.ds.canvas,
        foreground: context.ds.textSecondary,
        gutter: context.ds.gutter,
        textStyle: context.textStyle(
          FontSizeType.overline,
          fontWeight: FontWeight.w700,
          color: context.ds.textSecondary,
        ),
      ),
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.gutter,
    required this.textStyle,
  });

  final String label;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final double gutter;
  final TextStyle textStyle;

  static const double _height = 32;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      height: _height,
      // Opaque : l'en-tête épinglé passe par-dessus les lignes qui défilent.
      color: background,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(label, style: textStyle),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionHeaderDelegate old) =>
      old.label != label ||
      old.icon != icon ||
      old.background != background ||
      old.foreground != foreground;
}

/// Raccourci vers un pays courant, présenté en pastille.
class _SuggestionChip extends GetView<CountrySelectionController> {
  const _SuggestionChip({required this.option});

  final CountryOption option;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showConfirmationSheet(context, option),
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesign.space3,
            vertical: AppDesign.space2,
          ),
          decoration: BoxDecoration(
            color: context.ds.surface,
            border: Border.all(color: context.ds.border),
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (option.flag.isNotEmpty) ...[
                Text(option.flag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ],
              Text(
                option.country,
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: FontWeight.w600,
                  color: context.ds.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Index A–Z : une frappe amène directement à la bonne section.
class _AlphabetIndex extends GetView<CountrySelectionController> {
  const _AlphabetIndex({
    required this.scrollController,
    required this.suggestionsExtent,
  });

  final ScrollController scrollController;

  /// Hauteur réellement occupée par le bloc de suggestions. Évaluée au
  /// moment de l'appui, et non à la construction : le nombre de rangées de
  /// pastilles dépend de la largeur de l'écran, et la mesure n'est
  /// disponible qu'une fois la mise en page faite.
  final double Function() suggestionsExtent;

  /// Hauteur d'un séparateur entre deux lignes (AppDivider).
  static const double _separatorHeight = 1;

  /// Fait défiler jusqu'à la section [letter].
  ///
  /// Les lignes ont une hauteur constante, donc la position se calcule au
  /// lieu de dépendre d'une clé par section.
  void _jumpTo(String letter) {
    var offset = suggestionsExtent();

    for (final section in controller.sections) {
      if (section.letter == letter) break;
      final tiles = section.countries.length;
      // n lignes, et n-1 séparateurs entre elles.
      offset += _SectionHeaderDelegate._height +
          tiles * _CountryTile.height +
          (tiles - 1) * _separatorHeight;
    }

    if (!scrollController.hasClients) return;
    final max = scrollController.position.maxScrollExtent;
    scrollController.animateTo(
      offset.clamp(0.0, max),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final letters = controller.sections.map((s) => s.letter).toList();

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: AppDesign.space2, horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          // Fond discret : sans lui les lettres se superposent aux noms de
          // pays et deviennent illisibles pendant le défilement.
          color: context.ds.canvas.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        ),
        // Le clavier ouvert réduit la hauteur disponible : l'index se met à
        // l'échelle au lieu de déborder.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
          for (final letter in letters)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _jumpTo(letter),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  child: Text(
                    letter,
                    style: context.textStyle(
                      FontSizeType.overline,
                      fontWeight: FontWeight.w700,
                      color: context.ds.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ligne de la liste des pays.
class _CountryTile extends StatelessWidget {
  const _CountryTile({required this.option});

  /// Hauteur d'une ligne à réglage de police normal, partagée avec
  /// [_AlphabetIndex]. Une police agrandie peut la dépasser : le saut de
  /// l'index vise alors un peu court, ce qui reste préférable à une ligne
  /// tronquée.
  static const double height = 60;

  final CountryOption option;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showConfirmationSheet(context, option),
        child: Container(
          // Hauteur minimale, et non fixe : l'index alphabétique s'appuie
          // sur cette constante pour calculer sa position de défilement,
          // mais un grand réglage de police système doit pouvoir la
          // dépasser plutôt que de déborder.
          constraints: const BoxConstraints(minHeight: height),
          padding: EdgeInsets.symmetric(
            horizontal: context.ds.gutter,
            vertical: AppDesign.space2,
          ),
          child: Row(
            children: [
              _CountryAvatar(option: option),
              SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.country,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: FontWeight.w600,
                        color: context.ds.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${option.currency.code} — ${option.currency.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.caption,
                        color: context.ds.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppDesign.space2),
              // Le symbole reste visible à droite : c'est ce que
              // l'utilisateur verra ensuite sur chaque prix.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 56),
                child: Text(
                  option.currency.symbol,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: context.textStyle(
                    FontSizeType.caption,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Drapeau du pays, ou son initiale si le pays n'est pas au catalogue.
class _CountryAvatar extends StatelessWidget {
  const _CountryAvatar({required this.option});

  final CountryOption option;

  @override
  Widget build(BuildContext context) {
    if (option.flag.isEmpty) {
      return Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.ds.surfaceMuted,
          borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        ),
        child: Text(
          option.initial,
          style: context.textStyle(
            FontSizeType.caption,
            fontWeight: FontWeight.w700,
            color: context.ds.textSecondary,
          ),
        ),
      );
    }

    // Le drapeau emoji est simplement posé : l'encadrer le ferait paraître
    // désaligné, les emojis n'ayant pas tous la même chasse.
    return SizedBox(
      width: 34,
      height: 34,
      child: Center(
        child: Text(option.flag, style: const TextStyle(fontSize: 26)),
      ),
    );
  }
}

/// Confirmation présentée en feuille plutôt qu'en boîte de dialogue :
/// elle reste dans le pouce et laisse la liste visible derrière.
void _showConfirmationSheet(BuildContext context, CountryOption option) {
  final controller = Get.find<CountrySelectionController>();
  final currency = option.currency;

  Get.bottomSheet(
    SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.ds.gutter,
          AppDesign.space5,
          context.ds.gutter,
          AppDesign.space5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.ds.borderStrong,
                  borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                ),
              ),
            ),
            SizedBox(height: AppDesign.space5),
            Row(
              children: [
                if (option.flag.isNotEmpty) ...[
                  Text(option.flag, style: const TextStyle(fontSize: 34)),
                  SizedBox(width: AppDesign.space3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.country,
                        style: context.textStyle(
                          FontSizeType.h5,
                          fontWeight: FontWeight.w700,
                          color: context.ds.textPrimary,
                        ),
                      ),
                      SizedBox(height: AppDesign.space1),
                      Text(
                        '${currency.code} — ${currency.name}',
                        style: context.textStyle(
                          FontSizeType.body2,
                          color: context.ds.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDesign.space4),
            Container(
              padding: EdgeInsets.all(AppDesign.space3),
              decoration: BoxDecoration(
                color: context.ds.surfaceMuted,
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: context.ds.textSecondary,
                  ),
                  SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Text(
                      'Les prix seront affichés en ${currency.code}. Vous pourrez changer de pays plus tard dans les réglages.',
                      style: context.textStyle(
                        FontSizeType.overline,
                        color: context.ds.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppDesign.space5),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Annuler',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Get.back<void>(),
                  ),
                ),
                SizedBox(width: AppDesign.space3),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Confirmer',
                    onPressed: () {
                      Get.back<void>();
                      controller.selectCountry(option);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    backgroundColor: context.ds.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppDesign.radiusXl),
      ),
    ),
    isScrollControlled: true,
  );
}

/// Chargement impossible : on propose de réessayer plutôt que de laisser
/// un écran vide, le pays étant obligatoire pour continuer.
class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(context.ds.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: context.ds.textTertiary,
            ),
            SizedBox(height: AppDesign.space3),
            Text(
              'Liste des pays indisponible',
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.body1,
                fontWeight: FontWeight.w700,
                color: context.ds.textPrimary,
              ),
            ),
            SizedBox(height: AppDesign.space2),
            Text(
              'Vérifiez votre connexion, puis réessayez.',
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.caption,
                color: context.ds.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: AppDesign.space4),
            AppButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
