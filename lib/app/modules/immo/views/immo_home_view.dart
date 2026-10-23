import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../landlord/views/landlord_dashboard_view.dart';
import '../controllers/immo_home_controller.dart';
import '../immo_nav.dart';
import '../widgets/immo_sheets.dart';
import '../widgets/immo_widgets.dart';

/// Entrée de la rubrique (maquette « Immobilier / Trouvez votre prochain
/// bien ») : onglets Maisons à louer / Terrains à vendre, recherche,
/// filtres, tri, critères enregistrés et liste.
class ImmoHomeView extends StatefulWidget {
  const ImmoHomeView({super.key, this.initialType = RealEstateType.rent});

  final RealEstateType initialType;

  @override
  State<ImmoHomeView> createState() => _ImmoHomeViewState();
}

class _ImmoHomeViewState extends State<ImmoHomeView> {
  late final ImmoHomeController c;

  @override
  void initState() {
    super.initState();
    c = Get.put(ImmoHomeController(initialType: widget.initialType));
  }

  @override
  void dispose() {
    Get.delete<ImmoHomeController>();
    super.dispose();
  }

  // Le favori posé sur la fiche revient à la carte par ImmoActions.
  void _openListing(RealEstateListing listing) => ImmoNav.push(ImmoNav.listing, arguments: listing.id);

  void _toggleFavorite(RealEstateListing listing) {
    AuthGuard.requireAuth(
      context,
      featureName: 'immo.feature.favorites'.tr,
      onAuthenticated: () => c.toggleFavorite(listing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gutter = context.ds.gutter;

    return Scaffold(
      backgroundColor: context.ds.canvas,
      floatingActionButton: Obx(() => c.type.value == RealEstateType.land
          ? FloatingActionButton.extended(
              heroTag: 'immo-project',
              backgroundColor: AppDesign.neutral900,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.architecture_rounded),
              label: Text('immo.project.cta'.tr),
              onPressed: () => AuthGuard.requireAuth(
                context,
                featureName: 'immo.feature.project'.tr,
                onAuthenticated: () => ImmoNav.push(ImmoNav.project),
              ),
            )
          : const SizedBox.shrink()),
      body: RefreshIndicator(
        color: AppDesign.accent,
        onRefresh: c.load,
        child: CustomScrollView(
          controller: c.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, AppDesign.space3, gutter, 0),
              sliver: SliverList.list(children: [
                Text(
                  'immo.home.subtitle'.tr,
                  style: context.textStyle(FontSizeType.body1, color: context.ds.textSecondary),
                ),
                const SizedBox(height: AppDesign.space3),
                _TypeSwitch(c: c),
                const SizedBox(height: AppDesign.space3),
                _SearchRow(c: c),
                const SizedBox(height: AppDesign.space3),
                _FilterChips(c: c),
                const SizedBox(height: AppDesign.space3),
                _CriteriaBanner(c: c),
                _PublishBanner(c: c),
                _CountRow(c: c),
                const SizedBox(height: AppDesign.space2),
              ]),
            ),
            Obx(() {
              if (c.isLoading.value) {
                return SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  sliver: SliverList.separated(
                    itemCount: 3,
                    separatorBuilder: (_, _) => const SizedBox(height: AppDesign.space4),
                    itemBuilder: (_, _) => const ImmoCardSkeleton(),
                  ),
                );
              }
              if (c.items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: gutter),
                    child: AppEmptyState(
                      icon: c.hasError.value ? Icons.wifi_off_rounded : Icons.home_work_outlined,
                      title: c.hasError.value ? 'immo.home.error'.tr : 'immo.home.empty_title'.tr,
                      message: c.hasError.value ? null : 'immo.home.empty_message'.tr,
                      actionLabel: c.hasError.value
                          ? 'immo.home.retry'.tr
                          : (c.filters.isNotEmpty ? 'immo.filters.clear'.tr : null),
                      onAction: c.hasError.value ? c.load : (c.filters.isNotEmpty ? c.clearFilters : null),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 96),
                sliver: SliverList.separated(
                  itemCount: c.items.length + (c.isLoadingMore.value ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: AppDesign.space4),
                  itemBuilder: (context, i) {
                    if (i >= c.items.length) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(AppDesign.space4),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    final listing = c.items[i];

                    return listing.isLand
                        ? ImmoLandCard(
                            listing: listing,
                            onTap: () => _openListing(listing),
                            onFavorite: () => _toggleFavorite(listing),
                            onCabinet: listing.cabinet == null
                                ? null
                                : () => ImmoNav.push(ImmoNav.cabinet, arguments: listing.cabinet!.id),
                          )
                        : ImmoHouseCard(
                            listing: listing,
                            onTap: () => _openListing(listing),
                            onFavorite: () => _toggleFavorite(listing),
                          );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Deux grands boutons : Maisons à louer / Terrains à vendre.
class _TypeSwitch extends StatelessWidget {
  const _TypeSwitch({required this.c});

  final ImmoHomeController c;

  @override
  Widget build(BuildContext context) {
    Widget item(RealEstateType type, IconData icon, String label) {
      return Expanded(
        child: Obx(() {
          final selected = c.type.value == type;
          final fg = selected ? Colors.white : context.ds.textPrimary;

          return Material(
            color: selected ? AppDesign.accent : context.ds.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDesign.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDesign.radiusMd),
              onTap: () => c.switchType(type),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDesign.space3 + 2, horizontal: AppDesign.space1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: fg, size: 20),
                    const SizedBox(width: AppDesign.space1 + 2),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w700, color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      );
    }

    return Row(
      children: [
        item(RealEstateType.rent, Icons.home_rounded, 'immo.home.tab_rent'.tr),
        const SizedBox(width: AppDesign.space2),
        item(RealEstateType.land, Icons.landscape_outlined, 'immo.home.tab_land'.tr),
      ],
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.c});

  final ImmoHomeController c;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppTextField(
            hint: 'immo.home.search_hint'.tr,
            controller: c.searchController,
            prefixIcon: const Icon(Icons.search_rounded),
            textInputAction: TextInputAction.search,
            onChanged: c.onSearchChanged,
            onSubmitted: (_) => c.load(),
          ),
        ),
        const SizedBox(width: AppDesign.space2),
        Obx(() => Material(
              color: c.filters.isEmpty ? context.ds.surface : AppDesign.accentSubtle,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                side: BorderSide(color: c.filters.isEmpty ? context.ds.border : AppDesign.accentBorder),
              ),
              child: IconButton(
                tooltip: 'immo.filters.more'.tr,
                icon: Icon(Icons.tune_rounded, color: c.filters.isEmpty ? context.ds.textPrimary : AppDesign.accent),
                onPressed: () => c.type.value == RealEstateType.land
                    ? showImmoLandFiltersSheet(c)
                    : showImmoMoreFiltersSheet(c),
              ),
            )),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.c});

  final ImmoHomeController c;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Obx(() {
        final isLand = c.type.value == RealEstateType.land;
        final chips = <Widget>[
          ImmoFilterChip(label: 'immo.filters.all'.tr, selected: c.filters.isEmpty, trailing: null, onTap: c.clearFilters),
          ImmoFilterChip(
            label: isLand ? 'immo.filters.budget'.tr : 'immo.filters.price'.tr,
            selected: c.hasAny(['price_min', 'price_max']),
            onTap: () => showImmoPriceSheet(c),
          ),
          ImmoFilterChip(
            label: 'immo.filters.location'.tr,
            selected: c.hasAny(['city', 'district']),
            onTap: () => showImmoLocationSheet(c),
          ),
          if (isLand)
            ImmoFilterChip(
              label: 'immo.filters.land'.tr,
              selected: c.hasAny(['surface_min', 'surface_max', 'serviced', 'titled']),
              onTap: () => showImmoLandFiltersSheet(c),
            )
          else
            ImmoFilterChip(
              label: 'immo.filters.more'.tr,
              icon: Icons.tune_rounded,
              selected: c.hasAny(['rooms_min', 'bedrooms_min', 'furnished', 'not_landlocked', 'roadside']),
              onTap: () => showImmoMoreFiltersSheet(c),
            ),
        ];

        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppDesign.space2),
          itemBuilder: (_, i) => chips[i],
        );
      }),
    );
  }
}

/// Bandeau Studapart : « Vos critères, nos meilleurs logements », puis
/// « N logements correspondent » une fois les critères enregistrés.
class _CriteriaBanner extends StatelessWidget {
  const _CriteriaBanner({required this.c});

  final ImmoHomeController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.type.value != RealEstateType.rent) return const SizedBox.shrink();
      final saved = c.criteria.value;

      return Padding(
        padding: const EdgeInsets.only(bottom: AppDesign.space3),
        child: AppCard(
          color: AppDesign.accentSubtle,
          showBorder: false,
          elevated: false,
          onTap: () => showImmoCriteriaSheet(c),
          padding: const EdgeInsets.all(AppDesign.space3),
          child: Row(
            children: [
              const Icon(Icons.manage_search_rounded, color: AppDesign.accent, size: 28),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saved == null
                          ? 'immo.criteria.banner_title'.tr
                          : 'immo.criteria.banner_matches'.trParams({'count': '${c.total.value}'}),
                      style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: AppDesign.accentText),
                    ),
                    Text(
                      saved == null ? 'immo.criteria.banner_message'.tr : 'immo.criteria.banner_update'.tr,
                      style: context.textStyle(FontSizeType.body2, color: AppDesign.accentText),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppDesign.accentText),
            ],
          ),
        ),
      );
    });
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.c});

  final ImmoHomeController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final key = c.type.value == RealEstateType.land ? 'immo.home.count_land' : 'immo.home.count_rent';

      return Row(
        children: [
          Expanded(
            child: Text(
              c.isLoading.value ? '' : key.trParams({'count': '${c.total.value}'}),
              style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => showImmoSortSheet(c),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${'immo.sort.label'.tr} ', style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
                Text(
                  'immo.sort.${c.sort.value}'.tr,
                  style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600, color: context.ds.textPrimary),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: context.ds.textPrimary),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// « Vous louez un bien ? » : entrée de l'espace bailleur depuis la rubrique.
class _PublishBanner extends StatelessWidget {
  const _PublishBanner({required this.c});

  final ImmoHomeController c;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (c.type.value != RealEstateType.rent) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: AppDesign.space3),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppDesign.space3, vertical: AppDesign.space2),
          onTap: () => AuthGuard.requireAuth(
            context,
            featureName: 'home.feature.landlord_mode'.tr,
            onAuthenticated: () => Get.to(() => const LandlordDashboardView()),
          ),
          child: Row(
            children: [
              const Icon(Icons.real_estate_agent_outlined, color: AppDesign.accent),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                child: Text('immo.home.publish'.tr,
                    style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w600, color: context.ds.textPrimary)),
              ),
              Text('immo.home.publish_cta'.tr,
                  style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w700, color: AppDesign.accent)),
            ],
          ),
        ),
      );
    });
  }
}
