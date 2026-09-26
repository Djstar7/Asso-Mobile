import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/vendor_details_controller.dart';
import '../../../core/widgets/scoped_controller_page.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/app_network_image.dart';

/// Page ouverte par la route : chaque boutique empilée a son propre
/// [VendorDetailsController] (voir [ScopedControllerPage]).
class VendorDetailsPage extends StatelessWidget {
  const VendorDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScopedControllerPage<VendorDetailsController>(
      create: VendorDetailsController.new,
      builder: (controller) => VendorDetailsView(pageController: controller),
    );
  }
}

class VendorDetailsView extends GetView<VendorDetailsController> {
  const VendorDetailsView({super.key, this.pageController});

  /// Contrôleur propre à la page ; sans lui, celui enregistré dans GetX.
  final VendorDetailsController? pageController;

  @override
  VendorDetailsController get controller => pageController ?? super.controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeSystem.getBackgroundColor(context),
      body: Obx(() {
        if (controller.isLoading.value) {
          return _withBackButton(_buildLoadingState(context));
        }

        if (controller.hasError.value) {
          return _withBackButton(_buildErrorState(context));
        }

        return _buildContent(context);
      }),
    );
  }

  /// Pas de bandeau tant que la boutique n'est pas chargée : sans cette
  /// flèche, un chargement lent ou une erreur ne laissait que le bouton
  /// système pour repartir.
  Widget _withBackButton(Widget child) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(child: child),
          const Positioned(
            top: AppDesign.space1,
            left: AppDesign.space1,
            child: AppBackButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              AppThemeSystem.primaryColor,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement de la boutique...',
            style: context.textStyle(
              FontSizeType.body1,
              color: AppThemeSystem.grey600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppThemeSystem.getHorizontalPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: AppThemeSystem.errorColor,
            ),
            SizedBox(height: 16),
            Text(
              'Erreur',
              style: context.textStyle(
                FontSizeType.h5,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              controller.errorMessage.value,
              style: context.textStyle(
                FontSizeType.body1,
                color: AppThemeSystem.grey600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => AppNavigation.back(context),
              icon: Icon(Icons.arrow_back_ios_new_rounded),
              label: Text('Retour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final shop = controller.shopData.value;
    if (shop == null) return SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: controller.refreshShopDetails,
      color: AppDesign.accent,
      child: CustomScrollView(
        // Parcourir la grille referme le clavier de la recherche épinglée.
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        // Sans cela, une boutique au catalogue court ne se laisse pas tirer
        // pour se rafraîchir : la liste ne déborde pas, donc ne défile pas.
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildAppBar(context, shop),
          SliverToBoxAdapter(child: _buildIdentity(context, shop)),
          // La recherche reste sous la main pendant qu'on parcourt la grille :
          // dans une boutique fournie, la faire défiler hors de l'écran
          // obligeait à remonter tout le catalogue pour affiner.
          _buildSearchHeader(context),
          Obx(() {
            final visible = controller.visibleProducts;

            if (visible.isEmpty) {
              return SliverToBoxAdapter(
                child: _buildEmptyProducts(context),
              );
            }

            return SliverPadding(
              padding: EdgeInsets.fromLTRB(
                context.ds.gutter,
                AppDesign.space4,
                context.ds.gutter,
                AppDesign.space6,
              ),
              sliver: SliverGrid(
                gridDelegate: ProductCard.gridDelegate(context),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildProductCard(context, visible[index]),
                  childCount: visible.length,
                ),
              ),
            );
          }),
          SliverToBoxAdapter(
            child: SizedBox(height: context.ds.gutter),
          ),
        ],
      ),
    );
  }

  /// Bandeau de la boutique : image de couverture, logo et nom.
  ///
  /// Le nom ne figure plus qu'ici : répété juste en dessous dans la fiche, il
  /// occupait deux fois la même place sans rien apprendre de plus.
  Widget _buildAppBar(BuildContext context, Map<String, dynamic> shop) {
    final shopName = shop['name']?.toString() ?? 'Boutique';
    final shopLogo = shop['logo']?.toString();
    final cover = shop['cover']?.toString() ?? shop['banner']?.toString();

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      stretch: true,
      backgroundColor: AppDesign.accent,
      foregroundColor: Colors.white,
      leading: Padding(
        padding: EdgeInsets.only(left: AppDesign.space2),
        // Même retour que [AppBackButton] (accueil si la boutique a été
        // ouverte depuis un lien), sur une pastille lisible sur la photo.
        child: _GlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Retour',
          onPressed: () => AppNavigation.back(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsetsDirectional.only(
          start: 56,
          end: 56,
          bottom: AppDesign.space4,
        ),
        centerTitle: true,
        title: Text(
          shopName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyle(
            FontSizeType.subtitle1,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        background: _ShopCover(cover: cover, logo: shopLogo),
      ),
    );
  }

  /// Carte d'identité : description, tenue de boutique, adresse et chiffres.
  Widget _buildIdentity(BuildContext context, Map<String, dynamic> shop) {
    final description = shop['description']?.toString() ?? '';
    final address = shop['address']?.toString() ?? '';
    final isCertified =
        shop['is_certified'] == true || shop['is_certified'] == 1;
    final ownerName = shop['owner']?['name']?.toString();
    final ownerAvatar = shop['owner']?['profile_picture']?.toString();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space4,
        context.ds.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCertified) ...[
            const AppBadge(
              label: 'Boutique certifiée',
              tone: AppBadgeTone.info,
              icon: Icons.verified_rounded,
            ),
            SizedBox(height: AppDesign.space3),
          ],

          if (description.isNotEmpty) ...[
            Text(
              description,
              style: context.textStyle(
                FontSizeType.body2,
                color: context.ds.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: AppDesign.space4),
          ],

          // Les chiffres d'abord : c'est ce qui décide d'entrer ou non dans
          // le catalogue, et ils tiennent sur une seule ligne lisible.
          _buildShopStats(context),

          SizedBox(height: AppDesign.space4),

          // Tenue et adresse réunies dans une même ligne discrète : ce sont
          // des renseignements de confiance, pas le sujet de l'écran.
          if (ownerName != null && ownerName.isNotEmpty)
            _MetaRow(
              leading: _OwnerAvatar(url: ownerAvatar),
              label: 'Tenue par',
              value: ownerName,
            ),
          if (address.isNotEmpty) ...[
            SizedBox(height: AppDesign.space3),
            _MetaRow(
              leading: Icon(
                Icons.location_on_rounded,
                color: AppDesign.accent,
                size: 20,
              ),
              label: 'Adresse',
              value: address,
            ),
          ],
        ],
      ),
    );
  }

  /// Les trois chiffres de la boutique, sur une ligne.
  ///
  /// Trois cartes encadrées pour trois nombres faisaient beaucoup de
  /// contours : une seule surface, séparée de traits fins, pèse moins.
  Widget _buildShopStats(BuildContext context) {
    final stats = controller.shopStats.value;
    if (stats == null) return SizedBox.shrink();

    final rating = stats['average_rating'];
    final ratingLabel = rating is num
        ? rating.toStringAsFixed(1)
        : (rating?.toString() ?? '—');

    return Container(
      padding: EdgeInsets.symmetric(vertical: AppDesign.space4),
      decoration: BoxDecoration(
        color: context.ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
        border: Border.all(color: context.ds.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                value: '${stats['products_count'] ?? 0}',
                label: 'Produits',
              ),
            ),
            _StatSeparator(),
            Expanded(
              child: _StatTile(
                value: ratingLabel,
                label: 'Note',
                icon: Icons.star_rounded,
                iconColor: AppDesign.warning,
              ),
            ),
            _StatSeparator(),
            Expanded(
              child: _StatTile(
                value: '${stats['reviews_count'] ?? 0}',
                label: 'Avis',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Message affiché quand la grille ne montre rien.
  ///
  /// Deux situations à ne pas confondre : une boutique vide, sur laquelle on
  /// ne peut rien, et une recherche trop étroite, dont on peut revenir.
  Widget _buildEmptyProducts(BuildContext context) {
    final filtered = controller.hasActiveFilters;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.ds.gutter,
        vertical: AppDesign.space10,
      ),
      child: AppEmptyState(
        icon: filtered
            ? Icons.search_off_rounded
            : Icons.shopping_bag_outlined,
        title: filtered
            ? 'Aucun produit ne correspond'
            : 'Boutique encore vide',
        message: filtered
            ? 'Essayez un autre mot, ou revenez au catalogue complet.'
            : 'Cette boutique n\'a pas encore mis d\'article en vente.',
        actionLabel: filtered ? 'Tout afficher' : null,
        onAction: filtered ? controller.resetFilters : null,
      ),
    );
  }

  /// Barre de recherche et filtres, épinglée en tête du catalogue.
  ///
  /// Portée par un [SliverAppBar] plutôt qu'un [SliverPersistentHeader] : ce
  /// dernier réclame une hauteur annoncée d'avance, que le champ de saisie
  /// dépassait de quelques pixels dès que la police rendue s'écartait de
  /// l'estimation. Ici la barre se mesure sur son propre contenu.
  Widget _buildSearchHeader(BuildContext context) {
    final bar = _SearchBar(controller: controller, context: context);

    return SliverAppBar(
      pinned: true,
      primary: false,
      automaticallyImplyLeading: false,
      backgroundColor: context.ds.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // Toute la hauteur passe dans `bottom` : le corps de la barre reste vide.
      toolbarHeight: 0,
      bottom: bar,
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final price = product['price_xaf'] ?? product['price'] ?? 0;
    final stock = product['stock'] ?? 0;
    final isOutOfStock = stock is num && stock <= 0;

    String? image;
    final primary = product['primary_image']?.toString();
    if (primary != null && primary.isNotEmpty) {
      image = primary;
    } else if (product['images'] is List &&
        (product['images'] as List).isNotEmpty) {
      image = (product['images'] as List).first.toString();
    }

    return ProductCard(
      name: product['name']?.toString() ?? 'Produit',
      price: controller.formatPrice(
        price is num ? price.toDouble() : double.tryParse('$price') ?? 0,
      ),
      badgeLabel: isOutOfStock ? 'Épuisé' : null,
      badgeTone: AppBadgeTone.neutral,
      imageBuilder: image == null || image.isEmpty
          ? null
          : (context) {
              // Décodée à la taille de la carte, pas en pleine résolution.
              final cardWidth = ProductCard.widthInGrid(context);
              return AppNetworkImage(
                url: image!,
                decodeSize: Size(
                  cardWidth,
                  cardWidth / ProductCard.imageAspectRatio,
                ),
                placeholder: (_) => const SizedBox.expand(),
                errorBuilder: (_) => _buildImagePlaceholder(),
              );
            },
      onTap: () => controller.onProductTap(product),
    );
  }

  Widget _buildImagePlaceholder() {
    return Builder(
      builder: (context) => ColoredBox(
        color: context.ds.surfaceMuted,
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 26,
            color: context.ds.textTertiary,
          ),
        ),
      ),
    );
  }
}


/// Couverture du bandeau : image de la boutique, ou aplat de marque.
///
/// Un dégradé sombre couvre le bas quelle que soit la source : posé sur la
/// seule image, le titre blanc disparaissait sur les couvertures claires.
class _ShopCover extends StatelessWidget {
  const _ShopCover({required this.cover, required this.logo});

  final String? cover;
  final String? logo;

  @override
  Widget build(BuildContext context) {
    final hasCover = cover != null && cover!.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasCover)
          Image.network(
            cover!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _CoverFallback(),
          )
        else
          const _CoverFallback(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.65),
              ],
              stops: const [0, 0.45, 1],
            ),
          ),
        ),
        if (logo != null && logo!.isNotEmpty)
          Align(
            alignment: const Alignment(0, -0.15),
            child: _ShopLogo(url: logo!),
          ),
      ],
    );
  }
}

/// Aplat de marque, quand la boutique n'a pas de couverture.
class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppDesign.accent,
            Color.lerp(AppDesign.accent, Colors.black, 0.25)!,
          ],
        ),
      ),
    );
  }
}

/// Logo de la boutique, posé en médaillon sur la couverture.
class _ShopLogo extends StatelessWidget {
  const _ShopLogo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.ds.surface,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.storefront_rounded,
            color: AppDesign.accent,
            size: 32,
          ),
        ),
      ),
    );
  }
}

/// Bouton rond translucide, lisible sur n'importe quelle couverture.
class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.black.withValues(alpha: 0.32),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 20),
          tooltip: tooltip,
          // Le bouton reste sous la taille tactile réglementaire sans cela :
          // la surface colorée ne fait que 40 px.
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Un chiffre de la boutique et son libellé.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: iconColor ?? AppDesign.accent),
              const SizedBox(width: 4),
            ],
            Text(
              value,
              style: context.textStyle(
                FontSizeType.h5,
                fontWeight: FontWeight.w700,
                color: context.ds.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: AppDesign.space1),
        Text(
          label,
          style: context.textStyle(
            FontSizeType.caption,
            color: context.ds.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Trait fin entre deux chiffres.
class _StatSeparator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      indent: AppDesign.space1,
      endIndent: AppDesign.space1,
      color: context.ds.border,
    );
  }
}

/// Ligne de renseignement : une icône, un libellé, une valeur.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.leading,
    required this.label,
    required this.value,
  });

  final Widget leading;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 32, child: Center(child: leading)),
        SizedBox(width: AppDesign.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.overline,
                  color: context.ds.textTertiary,
                ),
              ),
              Text(
                value,
                style: context.textStyle(
                  FontSizeType.body2,
                  fontWeight: FontWeight.w600,
                  color: context.ds.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Portrait du tenancier, initiale à défaut de photo.
class _OwnerAvatar extends StatelessWidget {
  const _OwnerAvatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(color: AppDesign.accent),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
    );

    return SizedBox(
      width: 32,
      height: 32,
      child: ClipOval(
        child: url != null && url!.isNotEmpty
            ? Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => placeholder,
              )
            : placeholder,
      ),
    );
  }
}

/// Barre de recherche et pastilles de filtre, posée sous l'en-tête.
///
/// Sa hauteur préférée est mesurée sur le texte réellement rendu — police et
/// réglage d'accessibilité compris — au lieu d'être devinée : un écart de
/// quelques pixels suffisait à faire déborder la colonne.
class _SearchBar extends StatelessWidget implements PreferredSizeWidget {
  _SearchBar({required this.controller, required BuildContext context})
      : preferredSize = Size.fromHeight(_measure(context));

  final VendorDetailsController controller;

  /// Hauteur mesurée à la construction, sur le contexte de la vue.
  @override
  final Size preferredSize;

  /// Hauteur réellement occupée par les deux rangées et leurs marges.
  static double _measure(BuildContext context) {
    // Une ligne de saisie : le texte tel qu'il sera rendu, le rembourrage
    // vertical du champ, puis sa bordure.
    final field =
        _lineHeight(context, FontSizeType.body2) + AppDesign.space3 * 2 + 2;
    // Une pastille : le texte et son rembourrage.
    final chips =
        _lineHeight(context, FontSizeType.caption) + AppDesign.space2 * 2;
    // Marges de la barre : au-dessus du champ, entre les rangées, en dessous.
    final chrome = AppDesign.space4 + AppDesign.space3 + AppDesign.space2;
    return field + chips + chrome;
  }

  /// Hauteur d'une ligne pour un style donné, réglage d'accessibilité inclus.
  ///
  /// Mesurer plutôt qu'estimer : la valeur devinée tombait quelques pixels
  /// sous la réalité et la colonne débordait de son en-tête.
  static double _lineHeight(BuildContext context, FontSizeType type) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Ag',
        style: TextStyle(fontSize: AppThemeSystem.getFontSize(context, type)),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.height;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Opaque : la grille défile dessous, et une barre translucide la
      // laissait transparaître derrière le champ de saisie.
      color: context.ds.canvas,
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space4,
        context.ds.gutter,
        AppDesign.space2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SearchField(controller: controller),
          SizedBox(height: AppDesign.space3),
          _FilterRow(controller: controller),
        ],
      ),
    );
  }
}

/// Rangée horizontale des filtres et du tri.
class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.controller});

  final VendorDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final sort = controller.sort.value;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'En stock',
              icon: Icons.check_circle_outline_rounded,
              selected: controller.inStockOnly.value,
              onTap: controller.toggleInStockOnly,
            ),
            SizedBox(width: AppDesign.space2),
            for (final option in ShopProductSort.values) ...[
              _FilterChip(
                label: option.label,
                selected: sort == option,
                onTap: () => controller.setSort(option),
              ),
              SizedBox(width: AppDesign.space2),
            ],
          ],
        ),
      );
    });
  }
}

/// Champ de recherche du catalogue.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final VendorDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final hasQuery = controller.query.value.isNotEmpty;

      return TextField(
        controller: controller.searchController,
        onChanged: controller.onSearchChanged,
        textInputAction: TextInputAction.search,
        style: context.textStyle(
          FontSizeType.body2,
          color: context.ds.textPrimary,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Rechercher dans la boutique',
          hintStyle: context.textStyle(
            FontSizeType.body2,
            color: context.ds.textTertiary,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: context.ds.textTertiary,
          ),
          suffixIcon: hasQuery
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: context.ds.textSecondary,
                  ),
                  tooltip: 'Effacer',
                  onPressed: controller.clearSearch,
                )
              : null,
          filled: true,
          fillColor: context.ds.surfaceMuted,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppDesign.space3,
            vertical: AppDesign.space3,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusPill),
            borderSide: BorderSide(color: AppDesign.accent, width: 1.5),
          ),
        ),
      );
    });
  }
}

/// Pastille de filtre ou de tri.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.ds.textSecondary;

    return Material(
      color: selected ? AppDesign.accent : context.ds.surfaceMuted,
      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppDesign.space3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.caption,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
