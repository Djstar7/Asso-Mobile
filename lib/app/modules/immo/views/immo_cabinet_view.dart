import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';
import '../immo_actions.dart';
import '../immo_nav.dart';
import '../widgets/immo_widgets.dart';

/// Fiche d'un cabinet partenaire, sur le modèle de son affiche : bandeau,
/// spécialités, « Pourquoi nous choisir », puis ses terrains par localité.
class ImmoCabinetView extends StatefulWidget {
  const ImmoCabinetView({super.key, required this.cabinetId});

  final int cabinetId;

  @override
  State<ImmoCabinetView> createState() => _ImmoCabinetViewState();
}

class _ImmoCabinetViewState extends State<ImmoCabinetView> {
  RealEstateCabinet? _cabinet;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cabinet = await RealEstateService.cabinet(widget.cabinetId);
    if (!mounted) return;
    setState(() {
      _cabinet = cabinet;
      _loading = false;
    });
  }

  void _contact() {
    final cabinet = _cabinet;
    if (cabinet == null || cabinet.listings.isEmpty) return;
    ImmoActions.contactAsso(context, cabinet.listings.first);
  }

  @override
  Widget build(BuildContext context) {
    final cabinet = _cabinet;
    if (_loading) {
      return Scaffold(backgroundColor: context.ds.canvas, body: const Center(child: CircularProgressIndicator()));
    }
    if (cabinet == null) {
      return Scaffold(
        backgroundColor: context.ds.canvas,
        body: AppEmptyState(icon: Icons.account_balance_outlined, title: 'immo.cabinet.not_found'.tr, actionLabel: 'immo.home.retry'.tr, onAction: _load),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.ds.canvas,
        bottomNavigationBar: cabinet.listings.isEmpty
            ? null
            : Container(
                padding: EdgeInsets.fromLTRB(context.ds.gutter, AppDesign.space3, context.ds.gutter, AppDesign.space3),
                decoration: BoxDecoration(color: context.ds.surface, border: Border(top: BorderSide(color: context.ds.border))),
                child: AppButton(label: 'immo.cabinet.contact_us'.tr, icon: Icons.chat_bubble_outline_rounded, onPressed: _contact),
              ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _Banner(cabinet: cabinet)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsHeader(
                TabBar(
                  labelColor: AppDesign.accent,
                  indicatorColor: AppDesign.accent,
                  unselectedLabelColor: context.ds.textSecondary,
                  tabs: [
                    Tab(text: 'immo.cabinet.tab_about'.tr),
                    Tab(text: 'immo.cabinet.tab_lands'.trParams({'count': '${cabinet.listings.length}'})),
                  ],
                ),
                context.ds.surface,
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _About(cabinet: cabinet),
              _Lands(cabinet: cabinet),
            ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.cabinet});

  final RealEstateCabinet cabinet;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Stack(
      children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: cabinet.bannerUrl == null
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppDesign.accentPressed, AppDesign.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                )
              : AppNetworkImage(url: cabinet.bannerUrl!, decodeSize: Size(width, 220)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.65)],
              ),
            ),
          ),
        ),
        Positioned(
          left: context.ds.gutter,
          right: context.ds.gutter,
          bottom: AppDesign.space4,
          child: Row(
            children: [
              ImmoCabinetLogo(url: cabinet.logoUrl, size: 64),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(cabinet.name, maxLines: 2,
                            style: context.textStyle(FontSizeType.h6, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                      if (cabinet.isVerified) ...[
                        const SizedBox(width: AppDesign.space1),
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                      ],
                    ]),
                    if (cabinet.specialties != null)
                      Text(cabinet.specialties!, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: context.textStyle(FontSizeType.body2, color: Colors.white)),
                    if (cabinet.headquartersCity != null)
                      Text('immo.cabinet.headquarters'.trParams({'city': cabinet.headquartersCity!}),
                          style: context.textStyle(FontSizeType.caption, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader(this.tabBar, this.color);

  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(color: color, child: tabBar);

  @override
  bool shouldRebuild(covariant _TabsHeader oldDelegate) => oldDelegate.tabBar != tabBar || oldDelegate.color != color;
}

class _About extends StatelessWidget {
  const _About({required this.cabinet});

  final RealEstateCabinet cabinet;

  @override
  Widget build(BuildContext context) {
    final contact = cabinet.contact;

    return ListView(
      padding: EdgeInsets.fromLTRB(context.ds.gutter, AppDesign.space4, context.ds.gutter, AppDesign.space8),
      children: [
        if (cabinet.tagline != null) ...[
          Text(cabinet.tagline!, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: AppDesign.accent)),
          const SizedBox(height: AppDesign.space3),
        ],
        if (cabinet.description != null) ...[
          Text(cabinet.description!, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary, height: 1.5)),
          const SizedBox(height: AppDesign.space4),
        ],
        if (cabinet.whyChooseUs.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppDesign.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('immo.cabinet.why_us'.tr, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
                const SizedBox(height: AppDesign.space3),
                for (final item in cabinet.whyChooseUs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDesign.space2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppDesign.accent, size: 20),
                        const SizedBox(width: AppDesign.space2),
                        Expanded(child: Text(item, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (cabinet.ownersMessage != null) ...[
          const SizedBox(height: AppDesign.space4),
          AppCard(
            color: AppDesign.accentSubtle,
            showBorder: false,
            padding: const EdgeInsets.all(AppDesign.space4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.groups_rounded, color: AppDesign.accentText),
                const SizedBox(width: AppDesign.space3),
                Expanded(child: Text(cabinet.ownersMessage!, style: context.textStyle(FontSizeType.body2, color: AppDesign.accentText))),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppDesign.space4),
        AppCard(
          padding: const EdgeInsets.all(AppDesign.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('immo.cabinet.contact_title'.tr, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: context.ds.textPrimary)),
              const SizedBox(height: AppDesign.space2),
              if (cabinet.contactUnlocked && contact != null)
                for (final entry in {
                  Icons.phone_outlined: contact['phone'],
                  Icons.chat_outlined: contact['whatsapp'],
                  Icons.mail_outline_rounded: contact['email'],
                  Icons.location_on_outlined: contact['address'],
                }.entries.where((e) => e.value != null))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDesign.space2),
                    child: Row(children: [
                      Icon(entry.key, size: 18, color: AppDesign.success),
                      const SizedBox(width: AppDesign.space2),
                      Expanded(child: Text('${entry.value}', style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600, color: context.ds.textPrimary))),
                    ]),
                  )
              else
                Text('immo.cabinet.contact_hidden'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Lands extends StatefulWidget {
  const _Lands({required this.cabinet});

  final RealEstateCabinet cabinet;

  @override
  State<_Lands> createState() => _LandsState();
}

class _LandsState extends State<_Lands> {
  @override
  Widget build(BuildContext context) {
    final listings = widget.cabinet.listings;
    if (listings.isEmpty) {
      return AppEmptyState(icon: Icons.landscape_outlined, title: 'immo.cabinet.no_lands'.tr);
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(context.ds.gutter, AppDesign.space4, context.ds.gutter, AppDesign.space8),
      itemCount: listings.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDesign.space4),
      itemBuilder: (context, i) {
        final listing = listings[i];

        return ImmoLandCard(
          listing: listing,
          onTap: () => ImmoNav.push(ImmoNav.listing, arguments: listing.id),
          onFavorite: () => AuthGuard.requireAuth(
            context,
            featureName: 'immo.feature.favorites'.tr,
            onAuthenticated: () async {
              await ImmoActions.toggleFavorite(context, listing);
              if (mounted) setState(() {});
            },
          ),
        );
      },
    );
  }
}
