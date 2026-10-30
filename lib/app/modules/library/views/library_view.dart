import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/widgets/product_card.dart';
import '../../../core/widgets/shimmer_widgets.dart';
import '../../../data/models/wholesale_models.dart';
import '../../../data/providers/currency_service.dart';
import '../controllers/library_controller.dart';

/// Rubrique Bibliothèque : recherche, rayons, genres, filtres et grille de livres.
class LibraryView extends GetView<LibraryController> {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppKeyboardDismisser(
      child: Scaffold(
        backgroundColor: AppThemeSystem.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: context.ds.surface,
          elevation: 0,
          centerTitle: false,
          leading: const AppBackButton(),
          title: Text(
            'library.title'.tr,
            style: Theme.of(context).appBarTheme.titleTextStyle,
          ),
          actions: [
            Obx(() {
              final count = controller.activeFilterCount;
              return IconButton(
                tooltip: 'library.filters'.tr,
                onPressed: () => _openFilters(context),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  backgroundColor: AppDesign.accent,
                  child: const Icon(Icons.tune_rounded),
                ),
              );
            }),
          ],
        ),
        body: Column(
          children: [
            _buildSearch(context),
            _buildShelves(context),
            _buildGenres(context),
            Expanded(child: _buildBooks(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.ds.gutter,
        AppDesign.space2,
        context.ds.gutter,
        AppDesign.space2,
      ),
      child: _SearchField(controller: controller),
    );
  }

  Widget _buildShelves(BuildContext context) {
    return Obx(() {
      if (controller.shelves.isEmpty) return const SizedBox.shrink();
      final selected = controller.selectedShelfId.value;
      return _ChipRow(
        children: [
          _LibraryChip(
            label: 'library.all_shelves'.tr,
            icon: Icons.grid_view_rounded,
            selected: selected == null,
            onTap: () => controller.selectShelf(null),
          ),
          for (final shelf in controller.shelves)
            _LibraryChip(
              label: LibraryController.localizedName(shelf),
              selected: selected == shelf['id'],
              onTap: () => controller.selectShelf(shelf['id'] as int?),
            ),
        ],
      );
    });
  }

  Widget _buildGenres(BuildContext context) {
    return Obx(() {
      // Lus ici pour que la rangée suive le rayon et le genre choisis.
      controller.selectedShelfId.value;
      final selected = controller.selectedGenreId.value;
      final genres = controller.genres;
      if (genres.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(top: AppDesign.space2),
        child: _ChipRow(
          compact: true,
          children: [
            _LibraryChip(
              label: 'library.all_genres'.tr,
              compact: true,
              selected: selected == null,
              onTap: () => controller.selectGenre(null),
            ),
            for (final genre in genres)
              _LibraryChip(
                label: LibraryController.localizedName(genre),
                compact: true,
                selected: selected == genre['id'],
                onTap: () => controller.selectGenre(genre['id'] as int?),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildBooks(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.books.isEmpty) {
        return GridView.builder(
          padding: EdgeInsets.all(context.ds.gutter),
          gridDelegate: ProductCard.gridDelegate(context),
          itemCount: 6,
          itemBuilder: (context, _) => ShimmerWidgets.productCardShimmer(context),
        );
      }

      final error = controller.loadError.value;
      if (error != null) {
        return AppEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'library.error_title'.tr,
          message: error,
          actionLabel: 'library.retry'.tr,
          onAction: controller.reload,
        );
      }

      if (controller.books.isEmpty) {
        final filtered = controller.hasAnyFilter;
        return AppEmptyState(
          icon: Icons.menu_book_rounded,
          title: filtered ? 'library.no_result_title'.tr : 'library.empty_title'.tr,
          message: filtered ? 'library.no_result_message'.tr : 'library.empty_message'.tr,
          actionLabel: filtered ? 'library.clear_filters'.tr : null,
          onAction: filtered ? controller.clearAll : null,
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          await Future.wait([controller.loadShelves(), controller.reload()]);
        },
        color: AppThemeSystem.primaryColor,
        child: NotificationListener<ScrollNotification>(
          onNotification: (info) {
            if (info.metrics.pixels >= info.metrics.maxScrollExtent - 300) {
              controller.loadMore();
            }
            return false;
          },
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(context.ds.gutter),
            gridDelegate: ProductCard.gridDelegate(context),
            itemCount:
                controller.books.length + (controller.isLoadingMore.value ? 2 : 0),
            itemBuilder: (context, index) {
              if (index >= controller.books.length) {
                return ShimmerWidgets.productCardShimmer(context);
              }
              return _BookCard(book: controller.books[index]);
            },
          ),
        ),
      );
    });
  }

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.ds.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesign.radiusLg)),
      ),
      builder: (_) => _FiltersSheet(controller: controller),
    );
  }
}

/// Champ de recherche : titre, auteur, éditeur ou ISBN.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller});

  final LibraryController controller;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _text =
      TextEditingController(text: widget.controller.search.value);
  Worker? _sync;

  @override
  void initState() {
    super.initState();
    // « Effacer les filtres » vide aussi le champ.
    _sync = ever<String>(widget.controller.search, (value) {
      if (_text.text != value) _text.text = value;
    });
  }

  @override
  void dispose() {
    _sync?.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: _text,
      hint: 'library.search_hint'.tr,
      prefixIcon: const Icon(Icons.search_rounded),
      textInputAction: TextInputAction.search,
      onChanged: (value) => widget.controller.search.value = value,
      onSubmitted: (_) => widget.controller.reload(),
      suffixIcon: Obx(
        () => widget.controller.search.value.isEmpty
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: 'library.clear_search'.tr,
                icon: const Icon(Icons.close_rounded),
                onPressed: () => widget.controller.search.value = '',
              ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children, this.compact = false});

  final List<Widget> children;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 34 : 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.ds.gutter),
        itemCount: children.length,
        separatorBuilder: (_, _) => SizedBox(width: AppDesign.space2),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

class _LibraryChip extends StatelessWidget {
  const _LibraryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.ds.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppDesign.accent : context.ds.surface,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppDesign.accent : context.ds.border),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: context.textStyle(
                    compact ? FontSizeType.caption : FontSizeType.body2,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final Map<String, dynamic> book;

  @override
  Widget build(BuildContext context) {
    final shop = book['shop'] as Map?;
    final author = (book['book'] as Map?)?['author']?.toString().trim();

    return ProductCard(
      video: WholesaleVideo.fromJson(book['video']),
      name: book['name']?.toString() ?? '',
      price: CurrencyService.formatProductPrice(book),
      location: (author?.isNotEmpty ?? false) ? author : null,
      locationIcon: Icons.person_outline_rounded,
      isCertified: shop?['is_certified'] == true,
      isSponsored: book['is_sponsored'] == true,
      imageBuilder: (context) => _cover(context),
      onTap: () => Get.toNamed('/product', arguments: book),
    );
  }

  Widget _cover(BuildContext context) {
    final primary = book['primary_image']?.toString();
    final images = book['images'] as List?;
    final first = images != null && images.isNotEmpty
        ? (images.first is Map ? images.first['url'] : images.first)?.toString()
        : null;
    final url = (primary?.startsWith('http') ?? false) ? primary : first;

    if (url == null || !url.startsWith('http')) return _placeholder(context);

    final width = ProductCard.widthInGrid(context);
    return AppNetworkImage(
      url: url,
      decodeSize: Size(width, width / ProductCard.imageAspectRatio),
      placeholder: (_) => const SizedBox.expand(),
      showProgress: true,
      errorBuilder: (_) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: context.ds.surfaceMuted,
      child: Center(
        child: Icon(Icons.menu_book_rounded, size: 40, color: context.ds.textTertiary),
      ),
    );
  }
}

/// Filtres langue et format, appliqués d'un coup à la validation.
class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.controller});

  final LibraryController controller;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String? _language = widget.controller.language.value;
  late String? _format = widget.controller.format.value;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.ds.gutter,
          AppDesign.space4,
          context.ds.gutter,
          AppDesign.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'library.filters'.tr,
              style: context.textStyle(
                FontSizeType.h6,
                fontWeight: FontWeight.w700,
                color: context.ds.textPrimary,
              ),
            ),
            SizedBox(height: AppDesign.space4),
            _group(
              context,
              title: 'library.language'.tr,
              values: LibraryController.languages,
              labelPrefix: 'library.languages.',
              selected: _language,
              onSelected: (value) => setState(() => _language = value),
            ),
            SizedBox(height: AppDesign.space4),
            _group(
              context,
              title: 'library.format'.tr,
              values: LibraryController.formats,
              labelPrefix: 'library.formats.',
              selected: _format,
              onSelected: (value) => setState(() => _format = value),
            ),
            SizedBox(height: AppDesign.space5),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'library.reset'.tr,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => setState(() {
                      _language = null;
                      _format = null;
                    }),
                  ),
                ),
                SizedBox(width: AppDesign.space3),
                Expanded(
                  child: AppButton(
                    label: 'library.apply'.tr,
                    onPressed: () {
                      widget.controller.applyFilters(language: _language, format: _format);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(
    BuildContext context, {
    required String title,
    required List<String> values,
    required String labelPrefix,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textStyle(
            FontSizeType.body2,
            fontWeight: FontWeight.w600,
            color: context.ds.textSecondary,
          ),
        ),
        SizedBox(height: AppDesign.space2),
        Wrap(
          spacing: AppDesign.space2,
          runSpacing: AppDesign.space2,
          children: [
            SizedBox(
              height: 36,
              child: _LibraryChip(
                label: 'library.any'.tr,
                compact: true,
                selected: selected == null,
                onTap: () => onSelected(null),
              ),
            ),
            for (final value in values)
              SizedBox(
                height: 36,
                child: _LibraryChip(
                  label: '$labelPrefix$value'.tr,
                  compact: true,
                  selected: selected == value,
                  onTap: () => onSelected(value),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
