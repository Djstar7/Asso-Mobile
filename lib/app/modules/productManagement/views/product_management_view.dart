import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_ui.dart';
import '../controllers/product_management_controller.dart';
import '../../../routes/app_pages.dart';

class ProductManagementView extends GetView<ProductManagementController> {
  const ProductManagementView({super.key});

  /// Statuts proposés en filtre rapide, dans l'ordre d'affichage.
  static const _statusFilters = <({String? value, String label})>[
    (value: null, label: 'Tous'),
    (value: 'active', label: 'Actifs'),
    (value: 'inactive', label: 'Inactifs'),
    (value: 'pending', label: 'En attente'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Sans écran derrière (ouverture après un `offAllNamed`), on revient
        // au tableau de bord vendeur plutôt qu'à l'accueil.
        leading: AppBackButton(
          onPressed: () {
            if (Get.isOverlaysOpen) {
              Get.back();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Get.offAllNamed(Routes.VENDOR_DASHBOARD);
            }
          },
        ),
        title: Text(
          'Mes Produits',
          style: context.h5.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          _buildSearchHeader(context),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.products.isEmpty) {
                return _buildSkeletonList(context);
              }

              if (controller.errorMessage.value != null &&
                  controller.products.isEmpty) {
                return _buildErrorState(context);
              }

              if (controller.products.isEmpty) {
                // Une liste vide sous un filtre n'est pas un catalogue vide :
                // proposer « Ajouter un produit » ici serait trompeur.
                return controller.hasActiveFilters
                    ? _buildNoResultsState(context)
                    : _buildEmptyState(context);
              }

              return _buildProductsList(context);
            }),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.navigateToAddProduct,
        backgroundColor: AppThemeSystem.primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Ajouter',
          style: context.button.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // Recherche & filtres
  // ==========================================================================

  Widget _buildSearchHeader(BuildContext context) {
    final gutter = context.ds.gutter;

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, AppDesign.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.ds.surfaceMuted,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.ds.border),
            ),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.onSearchChanged,
              textInputAction: TextInputAction.search,
              style: context.textStyle(FontSizeType.body1),
              decoration: InputDecoration(
                hintText: 'Rechercher dans mes produits…',
                hintStyle: context.body2.copyWith(
                  color: context.ds.textTertiary,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.ds.textSecondary,
                ),
                // Le bouton d'effacement n'apparaît qu'une fois la recherche
                // appliquée, pour ne pas sautiller à la première frappe.
                suffixIcon: Obx(
                  () => controller.searchQuery.value.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: 'Effacer la recherche',
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.ds.textSecondary,
                          ),
                          onPressed: controller.clearSearch,
                        ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          SizedBox(height: AppDesign.space3),
          _buildStatusFilters(context),
          _buildResultCount(context),
        ],
      ),
    );
  }

  Widget _buildStatusFilters(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Obx(() {
        final active = controller.statusFilter.value;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _statusFilters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = _statusFilters[index];
            final selected = filter.value == active;
            return _FilterChip(
              label: filter.label,
              selected: selected,
              onTap: () => controller.setStatusFilter(filter.value),
            );
          },
        );
      }),
    );
  }

  /// Compteur de résultats : il confirme que le filtre a bien été pris en
  /// compte et rappelle la taille réelle du catalogue.
  Widget _buildResultCount(BuildContext context) {
    return Obx(() {
      if (controller.products.isEmpty) return const SizedBox.shrink();

      final total = controller.totalProducts.value;
      final loaded = controller.products.length;
      final label = total == 1 ? 'produit' : 'produits';
      final text = loaded < total
          ? '$loaded sur $total $label'
          : '$total $label';

      return Padding(
        padding: EdgeInsets.only(top: AppDesign.space3),
        child: Row(
          children: [
            Text(
              text,
              style: context.caption.copyWith(color: context.ds.textSecondary),
            ),
            if (controller.hasActiveFilters) ...[
              const Spacer(),
              InkWell(
                onTap: controller.clearFilters,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    'Réinitialiser',
                    style: context.caption.copyWith(
                      color: AppThemeSystem.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // ==========================================================================
  // Liste
  // ==========================================================================

  Widget _buildProductsList(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refreshProducts,
      color: AppThemeSystem.primaryColor,
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 300) {
            controller.loadMoreProducts();
          }
          return false;
        },
        child: ListView.separated(
          // La recherche est au-dessus de la liste : parcourir les résultats
          // referme le clavier qui en cachait la moitié.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          // Marge basse élargie : sans elle, le bouton flottant « Ajouter »
          // recouvrait les actions de la dernière fiche produit.
          padding: EdgeInsets.fromLTRB(
            context.ds.gutter,
            0,
            context.ds.gutter,
            context.ds.gutter + AppDesign.space12 + AppDesign.space4,
          ),
          itemCount: controller.products.length + 1,
          separatorBuilder: (_, _) => SizedBox(height: AppDesign.space3),
          itemBuilder: (context, index) {
            if (index == controller.products.length) {
              return _buildListFooter(context);
            }
            return _buildProductCard(context, controller.products[index]);
          },
        ),
      ),
    );
  }

  /// Pied de liste : chargement de la page suivante, ou fin de liste atteinte.
  Widget _buildListFooter(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingMore.value) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: AppDesign.space4),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppThemeSystem.primaryColor,
                ),
              ),
            ),
          ),
        );
      }

      // Le repère de fin n'a de sens qu'une fois plusieurs pages parcourues.
      if (!controller.hasMore.value && controller.products.length > 8) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: AppDesign.space4),
          child: Center(
            child: Text(
              'Fin de la liste',
              style: context.caption.copyWith(color: context.ds.textTertiary),
            ),
          ),
        );
      }

      return const SizedBox.shrink();
    });
  }

  // ==========================================================================
  // Fiche produit
  // ==========================================================================

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final status = product['status'] as String? ?? 'inactive';
    final imageUrl = _primaryImageUrl(product);
    final radius = context.deviceType == DeviceType.mobile ? 12.0 : 16.0;

    return Container(
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: context.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 110,
                  child: _buildProductImage(context, imageUrl),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(AppDesign.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product['name']?.toString() ?? '',
                          style: context.subtitle1.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          controller.formatPrice(_priceOf(product)),
                          style: context.h6.copyWith(
                            color: AppThemeSystem.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _StatusBadge(status: status),
                            const SizedBox(width: 8),
                            Flexible(child: _buildStockLabel(context, product)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: context.borderColor),
          _buildCardActions(context, product, status),
        ],
      ),
    );
  }

  Widget _buildProductImage(BuildContext context, String? imageUrl) {
    if (imageUrl == null) {
      return Container(
        color: context.ds.surfaceMuted,
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: context.ds.textTertiary,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      // Colonne de 110 px : décodée à sa largeur, pas en pleine résolution.
      memCacheWidth: (110 * MediaQuery.devicePixelRatioOf(context)).ceil(),
      placeholder: (context, url) =>
          Container(color: context.ds.surfaceMuted),
      errorWidget: (context, url, error) => Container(
        color: context.ds.surfaceMuted,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 28,
          color: context.ds.textTertiary,
        ),
      ),
    );
  }

  /// Le stock est l'information que le vendeur surveille le plus : une rupture
  /// doit se repérer sans ouvrir la fiche.
  Widget _buildStockLabel(BuildContext context, Map<String, dynamic> product) {
    final stock = int.tryParse(product['stock']?.toString() ?? '');
    if (stock == null) return const SizedBox.shrink();

    final outOfStock = stock <= 0;
    return Text(
      outOfStock ? 'Rupture de stock' : 'Stock : $stock',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.caption.copyWith(
        color: outOfStock
            ? AppThemeSystem.errorColor
            : context.ds.textSecondary,
        fontWeight: outOfStock ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildCardActions(
    BuildContext context,
    Map<String, dynamic> product,
    String status,
  ) {
    final isActive = status == 'active';

    return Column(
      children: [
        // Asso Ads : mise en avant payante, réservée aux articles en ligne —
        // sponsoriser un produit désactivé n'aurait rien à montrer.
        if (isActive) ...[
          _CardAction(
            icon: Icons.campaign_outlined,
            label: 'Booster cet article',
            color: AppDesign.accent,
            onTap: () => Get.toNamed(
              Routes.BOOST,
              arguments: {'product': product},
            ),
          ),
          Container(height: 1, color: context.borderColor),
        ],
        Row(
          children: [
            Expanded(
              child: _CardAction(
                icon: Icons.edit_outlined,
                label: 'Modifier',
                onTap: () => controller.editProduct(product),
              ),
            ),
            _actionDivider(context),
            Expanded(
              child: _CardAction(
                icon: isActive
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                label: isActive ? 'Désactiver' : 'Réactiver',
                onTap: () => controller.toggleProductStatus(product),
              ),
            ),
            _actionDivider(context),
            Expanded(
              child: _CardAction(
                icon: Icons.delete_outline,
                label: 'Supprimer',
                // Seule action irréversible : elle garde une couleur d'alerte.
                color: AppThemeSystem.errorColor,
                onTap: () => controller.deleteProduct(
                  product['id'] as int,
                  product['name']?.toString() ?? 'ce produit',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionDivider(BuildContext context) =>
      Container(width: 1, height: 28, color: context.borderColor);

  // ==========================================================================
  // États : squelette, vide, sans résultat, erreur
  // ==========================================================================

  /// Squelette plutôt qu'un spinner centré : la page garde sa forme pendant
  /// le chargement, ce qui la fait paraître plus rapide.
  Widget _buildSkeletonList(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        0,
        context.ds.gutter,
        context.ds.gutter,
      ),
      itemCount: 5,
      separatorBuilder: (_, _) => SizedBox(height: AppDesign.space3),
      itemBuilder: (context, _) => Container(
        height: 132,
        decoration: BoxDecoration(
          color: context.ds.surfaceMuted,
          borderRadius: BorderRadius.circular(
            context.deviceType == DeviceType.mobile ? 12 : 16,
          ),
          border: Border.all(color: context.borderColor),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return _CenteredState(
      icon: Icons.shopping_basket_outlined,
      title: 'Aucun produit publié',
      message: 'Commencez à vendre en ajoutant votre premier produit.',
      actionLabel: 'Ajouter mon premier produit',
      actionIcon: Icons.add,
      onAction: controller.navigateToAddProduct,
    );
  }

  Widget _buildNoResultsState(BuildContext context) {
    final query = controller.searchQuery.value;
    return _CenteredState(
      icon: Icons.search_off_rounded,
      title: 'Aucun résultat',
      message: query.isEmpty
          ? 'Aucun produit ne correspond à ce filtre.'
          : 'Aucun produit ne correspond à « $query ».',
      actionLabel: 'Réinitialiser les filtres',
      actionIcon: Icons.refresh_rounded,
      onAction: controller.clearFilters,
      outlined: true,
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return _CenteredState(
      icon: Icons.cloud_off_rounded,
      title: 'Chargement impossible',
      message: controller.errorMessage.value ?? 'Une erreur est survenue.',
      actionLabel: 'Réessayer',
      actionIcon: Icons.refresh_rounded,
      onAction: controller.refreshProducts,
    );
  }

  // ==========================================================================
  // Lecture de la réponse API
  // ==========================================================================

  /// L'API expose l'image principale sous deux formes selon l'endpoint.
  String? _primaryImageUrl(Map<String, dynamic> product) {
    final primary = product['primary_image']?.toString();
    if (primary != null && primary.isNotEmpty) return primary;

    final images = product['images'] as List?;
    if (images == null || images.isEmpty) return null;

    final first = images.first;
    final url = first is Map ? first['url']?.toString() : first?.toString();
    return (url == null || url.isEmpty) ? null : url;
  }

  double _priceOf(Map<String, dynamic> product) {
    final raw = (product['price_xaf'] ?? product['price'])?.toString();
    return double.tryParse(raw ?? '') ?? 0;
  }
}

// ============================================================================
// Widgets internes
// ============================================================================

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppThemeSystem.primaryColor : context.ds.surfaceMuted,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? AppThemeSystem.primaryColor
                  : context.ds.border,
            ),
          ),
          child: Text(
            label,
            style: context.caption.copyWith(
              color: selected ? Colors.white : context.ds.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'active' => AppThemeSystem.successColor,
      'pending' => AppThemeSystem.warningColor,
      _ => AppThemeSystem.grey500,
    };
    final label = switch (status.toLowerCase()) {
      'active' => 'Actif',
      'pending' => 'En attente',
      _ => 'Inactif',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: context.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Les actions courantes restent neutres ; seule la suppression est colorée.
    final tint = color ?? context.ds.textSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: tint),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.button.copyWith(
                  color: tint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// État plein écran (liste vide, sans résultat, erreur) : même mise en page
/// pour les trois, seul le propos change.
class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.outlined = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      actionLabel,
      style: context.button.copyWith(
        color: outlined ? AppThemeSystem.primaryColor : Colors.white,
        fontWeight: FontWeight.w600,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Défilable : sans cela, « tirer pour rafraîchir » et le clavier
        // ouvert feraient déborder la colonne sur les petits écrans.
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(context.ds.gutter * 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 72, color: context.ds.textTertiary),
                    SizedBox(height: AppDesign.space4),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: context.h6.copyWith(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: AppDesign.space2),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: context.body2.copyWith(
                        color: context.ds.textSecondary,
                      ),
                    ),
                    SizedBox(height: AppDesign.space5),
                    if (outlined)
                      OutlinedButton.icon(
                        onPressed: onAction,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppThemeSystem.primaryColor,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(
                          actionIcon,
                          color: AppThemeSystem.primaryColor,
                        ),
                        label: label,
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: onAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeSystem.primaryColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(actionIcon, color: Colors.white),
                        label: label,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
