import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:get/get.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/masonry_grid.dart';
import '../../../core/widgets/masonry_product_tile.dart';
import '../../../core/widgets/passcolis_card.dart';
import '../../../core/widgets/product_card.dart';
import '../../../data/providers/currency_service.dart';
import '../../import/views/wholesale_product_view.dart';
import '../controllers/search_controller.dart' as search_ctrl;
import '../../../core/widgets/scoped_controller_page.dart';

/// Vue de recherche, ouverte comme un écran à part entière.
///
/// Elle a son propre contrôleur, distinct de celui de l'onglet : la
/// catégorie passée à la route n'est lue qu'à la création, et les deux
/// recherches ne se mélangent plus (voir [ScopedControllerPage]).
class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return ScopedControllerPage<search_ctrl.SearchController>(
      create: search_ctrl.SearchController.new,
      builder: (controller) => _SearchViewContent(pageController: controller),
    );
  }
}

/// Même recherche, montée dans l'onglet de la navigation basse.
///
/// Elle réutilise le contenu de [SearchView] au lieu d'en maintenir une
/// copie : seule l'enveloppe change — pas de Scaffold ni de flèche de
/// retour, puisqu'on est sur une destination principale et non sur un écran
/// empilé.
class SearchTabView extends StatelessWidget {
  const SearchTabView({super.key});

  @override
  Widget build(BuildContext context) {
    // Permanent, comme les autres contrôleurs d'onglets : lié à la route de
    // l'accueil, il était supprimé par un `offAllNamed(HOME)` alors que le
    // nouvel accueil l'affichait encore — onglet sur fond d'erreur.
    if (!Get.isRegistered<search_ctrl.SearchController>()) {
      Get.put(search_ctrl.SearchController(), permanent: true);
    }

    return const _SearchViewContent(embedded: true);
  }
}

class _SearchViewContent extends GetView<search_ctrl.SearchController> {
  const _SearchViewContent({this.embedded = false, this.pageController});

  /// Contrôleur propre à la page de recherche ; l'onglet utilise celui
  /// enregistré dans GetX.
  final search_ctrl.SearchController? pageController;

  @override
  search_ctrl.SearchController get controller =>
      pageController ?? super.controller;

  /// Monté dans un onglet : l'écran hôte fournit déjà le fond, la zone sûre
  /// et le moyen de naviguer ailleurs.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);

    final body = Column(
      children: [
        // Barre de recherche fixe
        _buildSearchHeader(context, isDark),

        // Contenu scrollable
        Expanded(child: Obx(() => _buildContent(context, isDark))),
      ],
    );

    if (embedded) return body;

    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: SafeArea(child: body),
    );
  }

  /// Header avec barre de recherche
  Widget _buildSearchHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bascule Produits / Passcolis, au-dessus du champ : on choisit
          // d'abord ce que l'on cherche, on le formule ensuite. Repliée
          // quand on descend dans le mur, pour lui laisser l'écran.
          _buildCollapsible(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildScopeTabs(context, isDark),
            ),
          ),

          // Champ de recherche
          Row(
            children: [
              // Bouton retour — inutile sur un onglet, qui n'empile rien.
              if (!embedded) const AppBackButton(),

              // Champ de recherche
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppThemeSystem.grey300, width: 1),
                  ),
                  // Obx : seul le libellé du champ dépend de l'onglet. Le
                  // TextEditingController et le FocusNode appartenant au
                  // controller, la saisie et le focus survivent au rebuild.
                  child: Obx(
                    () => TextField(
                      controller: controller.searchTextController,
                      focusNode: controller.searchFocusNode,
                      textInputAction: TextInputAction.search,
                      onChanged: (value) {
                        controller.searchQuery.value = value;
                      },
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          controller.performSearch(value);
                        }
                      },
                      style: TextStyle(
                        color: AppThemeSystem.blackColor,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        // Le libellé suit l'onglet : on ne cherche pas une ville
                        // de la même façon qu'un article.
                        hintText:
                            controller.scope.value ==
                                search_ctrl.SearchScope.passcolis
                            ? 'Rechercher une ville, un pays...'
                            : 'Rechercher des produits...',
                        hintStyle: TextStyle(
                          color: AppThemeSystem.grey500,
                          fontSize: 15,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppThemeSystem.primaryColor,
                        ),
                        suffixIcon: Obx(
                          () => controller.searchQuery.value.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: AppThemeSystem.grey500,
                                  ),
                                  onPressed: controller.clearSearch,
                                )
                              : const SizedBox.shrink(),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Filtres rapides (catégories) — propres aux produits : un trajet
          // n'appartient à aucune catégorie du catalogue.
          Obx(() {
            if (controller.scope.value != search_ctrl.SearchScope.products) {
              return const SizedBox.shrink();
            }
            return _buildCollapsible(
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _buildQuickFilters(context, isDark),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Partie de l'en-tête repliée quand on descend dans les résultats.
  Widget _buildCollapsible(Widget child) {
    return Obx(
      () => AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: controller.chromeVisible.value
            ? child
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  /// Replie l'en-tête quand le doigt descend dans la liste, le rappelle dès
  /// qu'il remonte ou qu'on revient en haut.
  bool _onUserScroll(UserScrollNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;

    if (notification.direction == ScrollDirection.forward ||
        metrics.pixels <= metrics.minScrollExtent + 8) {
      controller.chromeVisible.value = true;
    } else if (notification.direction == ScrollDirection.reverse &&
        metrics.pixels > metrics.minScrollExtent + 24) {
      controller.chromeVisible.value = false;
    }
    return false;
  }

  /// Bascule entre les deux familles de résultats.
  ///
  /// Un segmenté plutôt qu'un `TabBar` : les deux listes ne se font pas
  /// défiler horizontalement l'une vers l'autre, et l'état sélectionné reste
  /// lisible sans dépendre d'un indicateur fin.
  Widget _buildScopeTabs(BuildContext context, bool isDark) {
    return Obx(() {
      final current = controller.scope.value;

      Widget tab(String label, IconData icon, search_ctrl.SearchScope value) {
        final isSelected = current == value;

        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.changeScope(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppThemeSystem.primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: isSelected
                        ? Colors.white
                        : AppThemeSystem.getSecondaryTextColor(context),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(
                        FontSizeType.body2,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : AppThemeSystem.getSecondaryTextColor(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppThemeSystem.grey800 : AppThemeSystem.grey100,
          borderRadius: BorderRadius.circular(AppDesign.radiusMd),
        ),
        child: Row(
          children: [
            tab(
              'Produits',
              Icons.grid_view_rounded,
              search_ctrl.SearchScope.products,
            ),
            tab(
              'Passcolis',
              Icons.flight_takeoff_rounded,
              search_ctrl.SearchScope.passcolis,
            ),
          ],
        ),
      );
    });
  }

  /// Filtres rapides (catégories)
  Widget _buildQuickFilters(BuildContext context, bool isDark) {
    return SizedBox(
      height: 40,
      child: Obx(() {
        if (controller.categories.isEmpty) return const SizedBox.shrink();

        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: controller.categories.length,
          itemBuilder: (context, index) {
            final category = controller.categories[index];

            // Chaque chip doit observer selectedCategory individuellement
            return Obx(() {
              final isSelected = index == 0
                  ? controller.selectedCategory.value.isEmpty ||
                        controller.selectedCategory.value == 'Tous'
                  : controller.selectedCategory.value == category;

              return _buildFilterChip(
                context,
                isDark,
                label: category,
                icon: index == 0 ? Icons.grid_view_rounded : null,
                isSelected: isSelected,
                onTap: () {
                  controller.selectCategory(category);
                },
              );
            });
          },
        );
      }),
    );
  }

  /// Chip de filtre
  Widget _buildFilterChip(
    BuildContext context,
    bool isDark, {
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppThemeSystem.primaryColor,
                      AppThemeSystem.tertiaryColor,
                    ],
                  )
                : null,
            color: isSelected
                ? null
                : isDark
                ? AppThemeSystem.grey800
                : AppThemeSystem.grey200,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? null
                : Border.all(
                    color: isDark
                        ? AppThemeSystem.grey700
                        : AppThemeSystem.grey300,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : AppThemeSystem.getPrimaryTextColor(context),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.body2,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : AppThemeSystem.getPrimaryTextColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Contenu principal : la famille de résultats correspondant à l'onglet.
  ///
  /// Le fondu croisé évite que la liste change brutalement sous le doigt
  /// quand on bascule d'un onglet à l'autre.
  Widget _buildContent(BuildContext context, bool isDark) {
    final isPasscolis =
        controller.scope.value == search_ctrl.SearchScope.passcolis;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey(controller.scope.value),
        child: isPasscolis
            ? _buildPasscolisContent(context, isDark)
            : _buildProductsContent(context, isDark),
      ),
    );
  }

  /// Onglet « Produits » : un mur mêlant catalogue local et articles de gros.
  Widget _buildProductsContent(BuildContext context, bool isDark) {
    final feed = controller.feed;
    final isSearching = controller.searchQuery.value.trim().isNotEmpty;

    if (feed.isNotEmpty) return _buildResults(context, isDark, feed);

    // Premier chargement, ou texte saisi dont les résultats arrivent : un
    // mur vide n'est pas encore un « aucun résultat ».
    if (controller.isLoading.value || controller.isSearchPending) {
      return _buildLoadingState(context);
    }

    if (controller.wall.loadFailed.value) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Produits indisponibles',
        message:
            "Les produits n'ont pas pu être chargés. Vérifiez votre connexion puis réessayez.",
        actionLabel: 'Réessayer',
        onAction: controller.retry,
      );
    }

    return isSearching
        ? _buildEmptyState(context, isDark)
        : _buildSearchHistory(context, isDark);
  }

  /// Onglet « Passcolis » : les trajets proposés par la diaspora.
  Widget _buildPasscolisContent(BuildContext context, bool isDark) {
    if (controller.isLoadingPasscolis.value &&
        controller.passcolisOffers.isEmpty) {
      return ListView.separated(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        itemCount: 4,
        separatorBuilder: (_, _) => SizedBox(height: AppDesign.space3),
        itemBuilder: (context, index) => const PasscolisCardShimmer(),
      );
    }

    if (controller.passcolisLoadFailed.value &&
        controller.passcolisOffers.isEmpty) {
      return AppEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Trajets indisponibles',
        message:
            "Les trajets n'ont pas pu être chargés. Vérifiez votre connexion puis réessayez.",
        actionLabel: 'Réessayer',
        onAction: () => controller.loadPasscolisOffers(isRefresh: true),
      );
    }

    final offers = controller.filteredPasscolis;

    if (offers.isEmpty) {
      final hasQuery = controller.searchQuery.value.isNotEmpty;
      return AppEmptyState(
        icon: Icons.flight_takeoff_rounded,
        title: hasQuery ? 'Aucun trajet trouvé' : 'Aucun trajet disponible',
        message: hasQuery
            ? 'Aucun voyageur ne dessert « ${controller.searchQuery.value} » pour le moment. Essayez une autre ville ou un pays.'
            : 'Aucun voyageur ne propose de kilos pour le moment. Revenez bientôt.',
        actionLabel: hasQuery ? 'Effacer la recherche' : 'Actualiser',
        onAction: hasQuery
            ? controller.clearSearch
            : () => controller.loadPasscolisOffers(isRefresh: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => controller.loadPasscolisOffers(isRefresh: true),
      color: AppThemeSystem.primaryColor,
      child: NotificationListener<UserScrollNotification>(
        onNotification: _onUserScroll,
        child: ListView.separated(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
          // +1 : l'en-tête reprend le décompte affiché côté produits.
          itemCount: offers.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: AppDesign.space3),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: AppDesign.space1),
                child: Text(
                  '${offers.length} trajet${offers.length > 1 ? 's' : ''}',
                  style: context.textStyle(
                    FontSizeType.body1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }

            return PasscolisCard(offer: offers[index - 1]);
          },
        ),
      ),
    );
  }

  /// État de chargement : le squelette annonce le décalage du mur qui va le
  /// remplacer, sinon la page « saute » à l'arrivée des résultats.
  Widget _buildLoadingState(BuildContext context) {
    final ratios = [for (var i = 0; i < 8; i++) masonryAspectRatioFor(i)];

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: _wallPadding(context),
          sliver: SliverMasonryGrid(
            itemCount: ratios.length,
            crossAxisCount: AppDesign.productColumns(context),
            crossAxisSpacing: AppDesign.space2,
            mainAxisSpacing: AppDesign.space2,
            itemBuilder: (_, i) => MasonryTileSkeleton(aspectRatio: ratios[i]),
          ),
        ),
      ],
    );
  }

  EdgeInsets _wallPadding(BuildContext context) => EdgeInsets.fromLTRB(
    AppDesign.gutter(context),
    AppDesign.space3,
    AppDesign.gutter(context),
    AppDesign.space6,
  );

  /// Historique de recherche
  Widget _buildSearchHistory(BuildContext context, bool isDark) {
    return Obx(() {
      if (controller.searchHistory.isEmpty) {
        return _buildInitialState(context, isDark);
      }

      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recherches récentes',
                  style: context.textStyle(
                    FontSizeType.h5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: controller.clearHistory,
                  child: Text(
                    'Effacer tout',
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: AppThemeSystem.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...controller.searchHistory.map(
              (query) => InkWell(
                onTap: () => controller.performSearch(query),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? AppThemeSystem.grey800
                          : AppThemeSystem.grey200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: AppThemeSystem.grey500,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          query,
                          style: context.textStyle(FontSizeType.body1),
                        ),
                      ),
                      Icon(
                        Icons.north_west_rounded,
                        color: AppThemeSystem.grey400,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// État initial (suggestions)
  Widget _buildInitialState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppThemeSystem.primaryColor.withValues(alpha: 0.1),
                    AppThemeSystem.tertiaryColor.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_rounded,
                size: 64,
                color: AppThemeSystem.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recherchez des produits',
              style: context.textStyle(
                FontSizeType.h4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trouvez ce que vous cherchez parmi\ndes milliers de produits',
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.body2,
                color: AppThemeSystem.grey600,
              ),
            ),
            const SizedBox(height: 32),
            // Suggestions de recherche
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children:
                  [
                    'Vêtements',
                    'Électronique',
                    'Chaussures',
                    'Accessoires',
                  ].map((tag) {
                    return InkWell(
                      onTap: () {
                        controller.searchTextController.text = tag;
                        controller.searchQuery.value = tag;
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppThemeSystem.grey800
                              : AppThemeSystem.grey100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppThemeSystem.grey700
                                : AppThemeSystem.grey300,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: context.textStyle(FontSizeType.body2),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// État vide (aucun résultat)
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? AppThemeSystem.grey800 : AppThemeSystem.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64,
                color: AppThemeSystem.grey500,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun résultat trouvé',
              style: context.textStyle(
                FontSizeType.h4,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec des mots-clés différents\nou parcourez les catégories',
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.body2,
                color: AppThemeSystem.grey600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: controller.clearSearch,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Nouvelle recherche'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mur de résultats, en colonnes libres.
  ///
  /// Les articles de gros s'y intercalent entre les produits locaux ; ceux
  /// qui ont une vidéo la lisent en boucle, muette, tant qu'ils sont à
  /// l'écran.
  Widget _buildResults(
    BuildContext context,
    bool isDark,
    List<search_ctrl.SearchFeedItem> feed,
  ) {
    final wall = controller.wall;
    final gutter = AppDesign.gutter(context);
    final columns = AppDesign.productColumns(context);

    // Les photos sont décodées à la largeur d'une colonne, en pixels
    // physiques, plutôt qu'en pleine résolution.
    final tileWidth =
        (MediaQuery.sizeOf(context).width -
            gutter * 2 -
            AppDesign.space2 * (columns - 1)) /
        columns;
    final cacheWidth = (tileWidth * MediaQuery.devicePixelRatioOf(context))
        .ceil();

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: controller.refreshWall,
          color: AppThemeSystem.primaryColor,
          // Contenu plus court que l'écran : aucun défilement ne réclamerait
          // la page suivante, la mise à jour des dimensions s'en charge.
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              _maybeLoadMore(notification.depth, notification.metrics);
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  _onUserScroll(notification);
                }
                _maybeLoadMore(notification.depth, notification.metrics);
                // Laisser remonter : le RefreshIndicator écoute les mêmes
                // notifications.
                return false;
              },
              child: CustomScrollView(
                // Une position par mur : effacer la recherche retrouve le
                // catalogue là où on l'avait laissé, une nouvelle recherche
                // repart du haut.
                key: PageStorageKey<String>('search-wall-${wall.query.value}'),
                physics: const AlwaysScrollableScrollPhysics(),
                // Faire défiler les résultats referme le clavier, qui en
                // masquait la moitié ; le champ reste en haut pour reprendre
                // la saisie.
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildResultsHeader(context, isDark),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      0,
                      gutter,
                      AppDesign.space6,
                    ),
                    sliver: SliverMasonryGrid(
                      itemCount: feed.length,
                      crossAxisCount: columns,
                      crossAxisSpacing: AppDesign.space2,
                      mainAxisSpacing: AppDesign.space2,
                      itemBuilder: (context, index) =>
                          _buildTile(context, feed[index], cacheWidth),
                    ),
                  ),
                  if (wall.isLoadingMore.value)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: AppDesign.space6),
                        child: Center(
                          child: SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppThemeSystem.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Rafraîchissement ou nouvelle saisie : les résultats affichés restent
        // lisibles, une barre fine signale que les suivants arrivent.
        if (wall.isLoading.value || controller.isSearchPending)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppThemeSystem.primaryColor,
              backgroundColor: Colors.transparent,
            ),
          ),
      ],
    );
  }

  /// Demande la page suivante un écran à l'avance, pour qu'elle arrive
  /// avant que le doigt n'atteigne le bas du mur.
  void _maybeLoadMore(int depth, ScrollMetrics metrics) {
    if (depth != 0) return;
    if (metrics.extentAfter < metrics.viewportDimension) {
      controller.loadMore();
    }
  }

  /// Décompte et accès aux filtres, au-dessus du mur.
  Widget _buildResultsHeader(BuildContext context, bool isDark) {
    final count = controller.resultCount;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDesign.gutter(context),
        AppDesign.space2,
        AppDesign.gutter(context) - AppDesign.space2,
        AppDesign.space1,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count produit${count > 1 ? 's' : ''}',
            style: context.textStyle(
              FontSizeType.body1,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Bouton filtres avec badge
          Obx(() {
            final filterCount = controller.activeFiltersCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: AppThemeSystem.primaryColor,
                  ),
                  onPressed: () => _showFiltersBottomSheet(context, isDark),
                ),
                if (filterCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppThemeSystem.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$filterCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    search_ctrl.SearchFeedItem item,
    int cacheWidth,
  ) {
    return switch (item) {
      search_ctrl.LocalFeedItem(:final product) => _buildLocalTile(
        product,
        cacheWidth,
      ),
      search_ctrl.WholesaleFeedItem(:final entry) => _buildWholesaleTile(
        entry,
        cacheWidth,
      ),
    };
  }

  /// Tuile d'un produit du catalogue local.
  Widget _buildLocalTile(Map<String, dynamic> product, int cacheWidth) {
    final id = (product['id'] as num?)?.toInt() ?? 0;
    final price =
        double.tryParse(
          (product['price_xaf'] ?? product['price'])?.toString() ?? '0',
        ) ??
        0.0;
    final location = product['location']?.toString() ?? '';

    // Asso Ads : emplacement acheté par le vendeur, signalé comme tel — sur
    // le visuel et sous le prix, où une photo sombre ne peut pas le masquer.
    final isSponsored = product['is_sponsored'] == true;

    return MasonryProductTile(
      key: ValueKey('${isSponsored ? 'ad' : 'p'}$id'),
      // Format stable dérivé de l'identifiant : les photos du catalogue
      // sont presque toutes carrées, leurs vraies proportions aligneraient
      // le mur.
      aspectRatio: masonryAspectRatioFor(id),
      image: MasonryTileImage(
        url: product['primary_image']?.toString(),
        cacheWidth: cacheWidth,
      ),
      badge: isSponsored
          ? const AssoAdsChip()
          : ProductCard.isShopCertified(product)
          ? const CertifiedMark()
          : null,
      name: product['name']?.toString() ?? 'Produit',
      price: controller.formatPrice(price),
      meta: isSponsored
          ? (location.isEmpty ? 'Sponsorisé' : 'Sponsorisé · $location')
          : location,
      metaIcon: isSponsored
          ? Icons.campaign_outlined
          : Icons.location_on_outlined,
      metaColor: isSponsored ? AppDesign.info : null,
      onTap: () => controller.onProductTap(product),
    );
  }

  /// Tuile d'un article de gros : sa vidéo quand il en a une, sinon sa photo.
  Widget _buildWholesaleTile(
    search_ctrl.SearchWholesaleEntry entry,
    int cacheWidth,
  ) {
    final product = entry.product;
    final video = product.video;
    final tier = product.entryTier;

    return MasonryProductTile(
      key: ValueKey('w${product.id}'),
      // Une vidéo garde son format réel (le plus souvent vertical, filmé au
      // téléphone) : la recadrer couperait le sujet.
      aspectRatio: video == null
          ? masonryAspectRatioFor(product.id)
          : masonryVideoAspectRatio(video.aspectRatio),
      image: MasonryTileImage(
        url: video?.posterUrl ?? product.image,
        cacheWidth: cacheWidth,
      ),
      videoUrl: video == null ? null : resolveMediaUrl(video.previewUrl),
      videoDurationLabel: video?.durationLabel,
      badge: _WholesaleBadge(flag: entry.countryFlag),
      name: product.name,
      price: tier == null
          ? '—'
          : CurrencyService.formatAmountInCurrency(
              tier.unitPrice,
              tier.currency,
            ),
      // Le prix affiché est celui du palier le plus avantageux : il ne
      // s'entend qu'à partir de sa quantité.
      meta: tier == null
          ? 'Vente en gros'
          : 'Dès ${tier.minQuantity} pièce${tier.minQuantity > 1 ? 's' : ''}',
      metaIcon: Icons.inventory_2_outlined,
      onTap: () => WholesaleProductView.open(
        product: product,
        shippingOptions: entry.shippingOptions,
        countryFlag: entry.countryFlag,
      ),
    );
  }

  /// Affiche la modal de filtres
  void _showFiltersBottomSheet(BuildContext context, bool isDark) {
    // Reset temporary values to current applied filters
    controller.minPrice.value = controller.currentMinPrice.value;
    controller.maxPrice.value = controller.currentMaxPrice.value;

    // Feuille standard : titre et croix, hauteur arrêtée sous la barre
    // d'état, boutons toujours visibles au-dessus du clavier.
    AppSheet.show(
      AppSheet(
        title: 'Filtres et tri',
        color: isDark ? AppThemeSystem.darkCardColor : Colors.white,
        // Boutons d'action, épinglés : au bout du contenu ils passaient
        // sous le clavier dès qu'on saisissait un prix.
        footer: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  controller.resetFilters();
                  Get.back();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppThemeSystem.primaryColor,
                  side: BorderSide(color: AppThemeSystem.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Réinitialiser'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  controller.applyPriceFilters();
                  Get.back();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Appliquer les filtres'),
              ),
            ),
          ],
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtre de prix
            Text(
              'Fourchette de prix',
              style: context.textStyle(
                FontSizeType.body1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Prix minimum et maximum
            Row(
              children: [
                Expanded(
                  child: Obx(
                    () => _buildPriceInputField(
                      context,
                      isDark,
                      label: 'Min',
                      textController: controller.minPriceController,
                      onChanged: (value) {
                        controller.minPrice.value = value;
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '-',
                    style: context.textStyle(
                      FontSizeType.h5,
                      color: AppThemeSystem.grey500,
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(
                    () => _buildPriceInputField(
                      context,
                      isDark,
                      label: 'Max',
                      textController: controller.maxPriceController,
                      onChanged: (value) {
                        controller.maxPrice.value = value;
                      },
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Prix suggérés
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPriceChip(context, isDark, 'Moins de 5.000', 0, 5000),
                  _buildPriceChip(
                    context,
                    isDark,
                    '5.000 - 20.000',
                    5000,
                    20000,
                  ),
                  _buildPriceChip(
                    context,
                    isDark,
                    '20.000 - 50.000',
                    20000,
                    50000,
                  ),
                  _buildPriceChip(
                    context,
                    isDark,
                    '50.000 - 100.000',
                    50000,
                    100000,
                  ),
                  _buildPriceChip(
                    context,
                    isDark,
                    'Plus de 100.000',
                    100000,
                    1000000,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Options de tri
            Text(
              'Trier par',
              style: context.textStyle(
                FontSizeType.body1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: search_ctrl.SortOption.values.map((option) {
                  final isSelected =
                      controller.selectedSortOption.value == option;
                  return InkWell(
                    onTap: () {
                      controller.selectSortOption(option);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  AppThemeSystem.primaryColor,
                                  AppThemeSystem.tertiaryColor,
                                ],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : isDark
                            ? AppThemeSystem.grey800
                            : AppThemeSystem.grey200,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected
                            ? null
                            : Border.all(
                                color: isDark
                                    ? AppThemeSystem.grey700
                                    : AppThemeSystem.grey300,
                              ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            option.icon,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : AppThemeSystem.getPrimaryTextColor(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            option.label,
                            style: context.textStyle(
                              FontSizeType.body2,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppThemeSystem.getPrimaryTextColor(
                                      context,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Champ d'entrée de prix
  Widget _buildPriceInputField(
    BuildContext context,
    bool isDark, {
    required String label,
    required TextEditingController textController,
    required Function(double) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppThemeSystem.grey800 : AppThemeSystem.grey100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppThemeSystem.grey700 : AppThemeSystem.grey300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.textStyle(
              FontSizeType.caption,
              color: AppThemeSystem.grey600,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: textController,
            keyboardType: TextInputType.number,
            style: context.textStyle(
              FontSizeType.body1,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: AppThemeSystem.grey500),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              suffixText: controller.currencySymbol,
              suffixStyle: context.textStyle(
                FontSizeType.caption,
                color: AppThemeSystem.grey500,
              ),
            ),
            onChanged: (text) {
              final parsed = double.tryParse(text) ?? 0;
              onChanged(parsed);
            },
          ),
        ],
      ),
    );
  }

  /// Chip de prix suggéré
  Widget _buildPriceChip(
    BuildContext context,
    bool isDark,
    String label,
    double min,
    double max,
  ) {
    final isSelected =
        controller.minPrice.value == min && controller.maxPrice.value == max;

    return InkWell(
      onTap: () {
        controller.minPrice.value = min;
        controller.maxPrice.value = max;
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
              : isDark
              ? AppThemeSystem.grey800
              : AppThemeSystem.grey100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppThemeSystem.primaryColor
                : isDark
                ? AppThemeSystem.grey700
                : AppThemeSystem.grey300,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: context.textStyle(
            FontSizeType.body2,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppThemeSystem.primaryColor
                : AppThemeSystem.getPrimaryTextColor(context),
          ),
        ),
      ),
    );
  }
}

/// Marque d'un article de gros : son pays d'origine et la mention « Gros ».
///
/// Mêlé aux produits locaux, un article vendu par lots doit se distinguer
/// d'un coup d'œil : son prix ne s'entend qu'à partir d'une quantité.
class _WholesaleBadge extends StatelessWidget {
  const _WholesaleBadge({required this.flag});

  final String flag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppDesign.neutral900.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flag.isNotEmpty) ...[
            Text(flag, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
          ],
          Text(
            'Gros',
            style: context.textStyle(
              FontSizeType.overline,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
