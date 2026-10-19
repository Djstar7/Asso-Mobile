import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/real_estate_service.dart';
import '../immo_actions.dart';
import '../immo_nav.dart';
import '../widgets/immo_quote_sheet.dart';
import '../widgets/immo_widgets.dart';
import 'immo_reserve_view.dart';
import 'immo_room_tour_view.dart';

/// Fiche d'une maison ou d'un terrain (captures Studapart 10 à 21).
///
/// Avant paiement, le bailleur, l'adresse exacte et le point GPS restent
/// masqués : la fiche le dit, et propose de parler à ASSO.
class ImmoListingView extends StatefulWidget {
  const ImmoListingView({super.key, required this.listingId});

  final int listingId;

  @override
  State<ImmoListingView> createState() => _ImmoListingViewState();
}

class _ImmoListingViewState extends State<ImmoListingView> {
  RealEstateListing? _listing;
  bool _loading = true;
  int? _unitId;
  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final listing = await RealEstateService.listing(widget.listingId);
    if (!mounted) return;
    setState(() {
      _listing = listing;
      _loading = false;
      final units = listing?.units ?? const [];
      final available = units.where((u) => u.isAvailable).toList()..sort((a, b) => a.price.compareTo(b.price));
      _unitId = available.isNotEmpty ? available.first.id : (units.isNotEmpty ? units.first.id : null);
    });
  }

  RealEstateUnit? get _unit => _listing?.units.firstWhereOrNull((u) => u.id == _unitId);

  void _openTour({int roomIndex = 0}) {
    final listing = _listing!;
    final rooms = listing.roomsTour.where((r) => r.media.isNotEmpty).toList();
    if (rooms.isEmpty) return;
    ImmoNav.push(ImmoNav.tour, arguments: ImmoRoomTourArgs(title: listing.title, rooms: rooms, initialIndex: roomIndex));
  }

  void _openGallery(int index) {
    final listing = _listing!;
    final rooms = listing.roomsTour.where((r) => r.media.isNotEmpty).toList();
    if (rooms.isNotEmpty) {
      _openTour();
      return;
    }
    final media = listing.media.where((m) => !m.isVideo).toList();
    if (media.isEmpty) return;
    ImmoNav.push(ImmoNav.tour, arguments: ImmoRoomTourArgs(
      title: listing.title,
      rooms: [RealEstateTourRoom(id: 0, kind: 'other', label: 'immo.detail.photos'.tr, media: listing.media)],
      initialIndex: 0,
      initialMedia: index,
    ));
  }

  /// Récapitulatif des montants, puis parcours de réservation (compte requis).
  void _reserve(RealEstateListing listing, RealEstateUnit? unit) {
    AuthGuard.requireAuth(
      context,
      featureName: 'immo.feature.reserve'.tr,
      onAuthenticated: () => showImmoQuoteSheet(
        context,
        listing: listing,
        unit: unit,
        onContinue: () => ImmoNav.push(ImmoNav.reserve, arguments: ImmoReserveArgs(listing: listing, unit: unit)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = _listing;

    if (_loading) {
      return Scaffold(backgroundColor: context.ds.canvas, body: const Center(child: CircularProgressIndicator()));
    }
    if (listing == null) {
      return Scaffold(
        backgroundColor: context.ds.canvas,
        body: AppEmptyState(
          icon: Icons.home_work_outlined,
          title: 'immo.detail.not_found'.tr,
          actionLabel: 'immo.home.retry'.tr,
          onAction: _load,
        ),
      );
    }

    final gutter = context.ds.gutter;

    return Scaffold(
      backgroundColor: context.ds.canvas,
      bottomNavigationBar: _BottomBar(
        listing: listing,
        unit: _unit,
        onContact: () => ImmoActions.contactAsso(context, listing),
        onReserve: () => _reserve(listing, _unit),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppDesign.accent,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(
              listing: listing,
              onTour: _openTour,
              onPhoto: _openGallery,
              onFavorite: () async {
                await ImmoActions.toggleFavorite(context, listing);
                if (mounted) setState(() {});
              },
            )),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, AppDesign.space4, gutter, AppDesign.space8),
              sliver: SliverList.list(children: [
                _Intro(listing: listing),
                if (listing.promoText?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppDesign.space4),
                  _PromoCard(text: listing.promoText!),
                ],
                const SizedBox(height: AppDesign.space4),
                AppCard(
                  padding: const EdgeInsets.all(AppDesign.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (listing.highlights.isNotEmpty) ...[
                        _SectionTitle('immo.detail.highlights'.tr),
                        for (final a in listing.highlights) _HighlightTile(amenity: a),
                        const Divider(height: AppDesign.space8),
                      ],
                      _SectionTitle('immo.detail.description'.tr),
                      _Description(
                        text: listing.description ?? '',
                        expanded: _descriptionExpanded,
                        onToggle: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                      ),
                      const Divider(height: AppDesign.space8),
                      _SectionTitle(listing.isLand ? 'immo.detail.access_land'.tr : 'immo.detail.access'.tr),
                      _AccessList(listing: listing),
                      if (listing.equipments.isNotEmpty) ...[
                        const Divider(height: AppDesign.space8),
                        _AmenityGroup(title: 'immo.detail.equipments'.tr, items: listing.equipments),
                      ],
                      if (listing.services.isNotEmpty) ...[
                        const Divider(height: AppDesign.space8),
                        _AmenityGroup(title: 'immo.detail.services'.tr, items: listing.services),
                      ],
                      const Divider(height: AppDesign.space8),
                      _SectionTitle('immo.detail.location'.tr),
                      _Location(listing: listing),
                    ],
                  ),
                ),
                if (listing.units.length > 1 || listing.isLand && listing.units.isNotEmpty) ...[
                  const SizedBox(height: AppDesign.space6),
                  Text(
                    listing.isLand ? 'immo.detail.lots'.tr : 'immo.detail.units'.tr,
                    style: context.textStyle(FontSizeType.h6, fontWeight: FontWeight.w800, color: context.ds.textPrimary),
                  ),
                  const SizedBox(height: AppDesign.space3),
                  for (final unit in listing.units) ...[
                    _UnitCard(
                      listing: listing,
                      unit: unit,
                      selected: unit.id == _unitId,
                      onSelect: unit.isAvailable ? () => setState(() => _unitId = unit.id) : null,
                      onReserve: unit.isAvailable
                          ? () {
                              setState(() => _unitId = unit.id);
                              _reserve(listing, unit);
                            }
                          : null,
                      onContact: () => ImmoActions.contactAsso(context, listing),
                    ),
                    const SizedBox(height: AppDesign.space3),
                  ],
                ],
                const SizedBox(height: AppDesign.space4),
                _Protection(listing: listing),
                const SizedBox(height: AppDesign.space4),
                if (listing.isLand && listing.cabinet != null)
                  _CabinetCard(listing: listing)
                else if (!listing.isLand)
                  _OwnerCard(listing: listing, onContact: () => ImmoActions.contactAsso(context, listing)),
                const SizedBox(height: AppDesign.space4),
                Text(
                  'immo.detail.reference'.trParams({'reference': listing.reference}),
                  style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space3),
      child: Text(text, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.listing, required this.onTour, required this.onPhoto, required this.onFavorite});

  final RealEstateListing listing;
  final VoidCallback onTour;
  final ValueChanged<int> onPhoto;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final images = listing.media.where((m) => !m.isVideo).map((m) => m.url).toList();
    final hasTour = listing.roomsTour.any((r) => r.media.isNotEmpty);

    return ImmoPhotoCarousel(
      images: images.isEmpty ? listing.images : images,
      height: 300,
      onTap: onPhoto,
      overlay: [
        Positioned(
          top: AppDesign.space3,
          right: AppDesign.space3,
          child: ImmoFavoriteButton(isFavorite: listing.isFavorite, onPressed: onFavorite),
        ),
        if (hasTour)
          Positioned(
            left: 0,
            right: 0,
            bottom: AppDesign.space6,
            child: Center(
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                  onTap: onTour,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDesign.space4, vertical: AppDesign.space2 + 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.view_carousel_rounded, color: AppDesign.accent),
                        const SizedBox(width: AppDesign.space2),
                        Text(
                          'immo.detail.room_tour_cta'.tr,
                          style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: AppDesign.neutral900),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (listing.video != null)
          Positioned(
            bottom: AppDesign.space2,
            right: AppDesign.space3,
            child: ImmoPhotoTag(label: 'immo.card.video'.tr, icon: Icons.play_circle_outline_rounded),
          ),
      ],
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.listing});

  final RealEstateListing listing;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (!listing.isLand) listing.furnished ? 'immo.card.furnished'.tr : 'immo.card.unfurnished'.tr,
      if (immoRoomsLabel(listing).isNotEmpty && !listing.isLand) immoRoomsLabel(listing),
      if (listing.surfaceLabel != null) listing.surfaceLabel!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          listing.isLand ? immoKindLabel(listing) : 'immo.detail.for_rent'.trParams({'kind': immoKindLabel(listing)}),
          style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary),
        ),
        const SizedBox(height: AppDesign.space1),
        Text(
          listing.title,
          style: context.textStyle(FontSizeType.h5, fontWeight: FontWeight.w800, color: context.ds.textPrimary),
        ),
        const SizedBox(height: AppDesign.space1),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 18, color: context.ds.textSecondary),
            const SizedBox(width: AppDesign.space1),
            Expanded(
              child: Text(listing.place, style: context.textStyle(FontSizeType.body1, color: context.ds.textSecondary)),
            ),
          ],
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: AppDesign.space1),
          Text(meta.join('  •  '), style: context.textStyle(FontSizeType.body2, color: context.ds.textPrimary)),
        ],
        const SizedBox(height: AppDesign.space3),
        Wrap(
          spacing: AppDesign.space2,
          runSpacing: AppDesign.space2,
          children: [
            if (listing.isPopular) AppBadge(label: 'immo.detail.popular'.tr, tone: AppBadgeTone.accent, icon: Icons.favorite_border_rounded),
            if (listing.isFeatured) AppBadge(label: 'immo.card.featured'.tr, tone: AppBadgeTone.accent, icon: Icons.star_rounded),
            if (listing.owner?.isVerified ?? false)
              AppBadge(label: 'immo.detail.verified_owner'.tr, tone: AppBadgeTone.success, icon: Icons.verified_rounded),
            if (listing.isLand)
              AppBadge(
                label: listing.landTitled ? 'immo.land.titled'.tr : 'immo.land.not_titled'.tr,
                tone: listing.landTitled ? AppBadgeTone.success : AppBadgeTone.warning,
                icon: Icons.description_outlined,
              ),
            if (listing.isLand && listing.serviced)
              AppBadge(label: 'immo.land.serviced'.tr, tone: AppBadgeTone.success, icon: Icons.bolt_rounded),
            if (listing.lowStock)
              AppBadge(
                label: 'immo.card.places_left'.trParams({'count': '${listing.unitsAvailable}'}),
                tone: AppBadgeTone.danger,
                icon: Icons.error_outline_rounded,
              ),
          ],
        ),
      ],
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppDesign.info),
              const SizedBox(width: AppDesign.space1),
              Text('immo.detail.offer'.tr, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: AppDesign.info)),
            ],
          ),
          const SizedBox(height: AppDesign.space2),
          Text(text, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary)),
        ],
      ),
    );
  }
}

class _HighlightTile extends StatelessWidget {
  const _HighlightTile({required this.amenity});

  final RealEstateAmenity amenity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space3),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppDesign.accent, borderRadius: BorderRadius.circular(AppDesign.radiusSm)),
            child: Icon(immoAmenityIcon(amenity.icon), color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppDesign.space3),
          Expanded(child: Text(amenity.name, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary))),
        ],
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.text, required this.expanded, required this.onToggle});

  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final long = text.length > 220;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expanded || !long ? null : 4,
          overflow: expanded || !long ? null : TextOverflow.ellipsis,
          style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary, height: 1.5),
        ),
        if (long)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppDesign.accent),
            onPressed: onToggle,
            child: Text(expanded ? 'immo.detail.see_less'.tr : 'immo.detail.see_more'.tr),
          ),
      ],
    );
  }
}

/// Accès et quartier : le questionnaire du bailleur, en clair.
class _AccessList extends StatelessWidget {
  const _AccessList({required this.listing});

  final RealEstateListing listing;

  @override
  Widget build(BuildContext context) {
    final a = listing.access;
    final rows = <(IconData, String)>[
      if (a.roadAccess == 'roadside')
        (Icons.add_road_rounded, 'immo.access.roadside'.tr)
      else if (a.distanceToRoadM != null)
        (Icons.add_road_rounded, 'immo.access.distance'.trParams({'meters': '${a.distanceToRoadM}'})),
      if (a.roadCondition != null) (Icons.route_outlined, 'immo.access.road_${a.roadCondition}'.tr),
      (Icons.terrain_outlined, a.isLandlocked ? 'immo.access.landlocked'.tr : 'immo.access.not_landlocked'.tr),
      if (a.waterSource != null) (Icons.water_drop_outlined, 'immo.access.water_${a.waterSource}'.tr),
      if (a.electricity != null) (Icons.bolt_rounded, 'immo.access.electricity_${a.electricity}'.tr),
      if (a.securityLevel != null) (Icons.shield_outlined, 'immo.access.security_${a.securityLevel}'.tr),
      if (a.hasParking) (Icons.local_parking_rounded, 'immo.access.parking'.tr),
      if (a.hasFence) (Icons.fence_rounded, 'immo.access.fence'.tr),
      if (a.hasGuard) (Icons.security_rounded, 'immo.access.guard'.tr),
      if (!listing.isLand && listing.minLeaseMonths != null)
        (Icons.event_repeat_rounded, 'immo.access.min_lease'.trParams({'months': '${listing.minLeaseMonths}'})),
      if (!listing.isLand && listing.advanceMonths != null)
        (Icons.payments_outlined, 'immo.access.advance'.trParams({'months': '${listing.advanceMonths}'})),
      if (listing.isLand && listing.landTitleStatus != null)
        (Icons.description_outlined, listing.landTitleStatus!),
    ];

    return Column(
      children: [
        for (final (icon, text) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDesign.space3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: context.ds.surfaceMuted, borderRadius: BorderRadius.circular(AppDesign.radiusSm)),
                  child: Icon(icon, size: 20, color: context.ds.textPrimary),
                ),
                const SizedBox(width: AppDesign.space3),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppDesign.space2),
                    child: Text(text, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AmenityGroup extends StatelessWidget {
  const _AmenityGroup({required this.title, required this.items});

  final String title;
  final List<RealEstateAmenity> items;

  Widget _tile(BuildContext context, RealEstateAmenity a) => Padding(
        padding: const EdgeInsets.only(bottom: AppDesign.space3),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: context.ds.surfaceMuted, borderRadius: BorderRadius.circular(AppDesign.radiusSm)),
              child: Icon(immoAmenityIcon(a.icon), color: context.ds.textPrimary, size: 22),
            ),
            const SizedBox(width: AppDesign.space3),
            Expanded(child: Text(a.name, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('$title (${items.length})'),
        for (final a in items.take(4)) _tile(context, a),
        if (items.length > 4)
          AppButton(
            label: 'immo.detail.see_all'.trParams({'count': '${items.length}', 'what': title.toLowerCase()}),
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            expand: false,
            onPressed: () => AppSheet.show(AppSheet(
              title: '$title (${items.length})',
              child: Column(children: [for (final a in items) _tile(context, a)]),
            )),
          ),
      ],
    );
  }
}

class _Location extends StatelessWidget {
  const _Location({required this.listing});

  final RealEstateListing listing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: context.ds.surfaceMuted, borderRadius: BorderRadius.circular(AppDesign.radiusSm)),
          child: Icon(Icons.location_on_outlined, color: context.ds.textPrimary),
        ),
        const SizedBox(width: AppDesign.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(listing.place, style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600, color: context.ds.textPrimary)),
              const SizedBox(height: AppDesign.space1),
              Text(
                listing.unlocked && listing.address != null
                    ? listing.address!
                    : 'immo.detail.address_hidden'.tr,
                style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.listing,
    required this.unit,
    required this.selected,
    required this.onSelect,
    required this.onReserve,
    required this.onContact,
  });

  final RealEstateListing listing;
  final RealEstateUnit unit;
  final bool selected;
  final VoidCallback? onSelect;
  final VoidCallback? onReserve;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final surface = unit.surfaceMin == null
        ? null
        : (unit.surfaceMax == null || unit.surfaceMax == unit.surfaceMin
            ? '${unit.surfaceMin} m²'
            : '${unit.surfaceMin} - ${unit.surfaceMax} m²');
    final features = <(IconData, String)>[
      if (!listing.isLand) (Icons.weekend_outlined, unit.furnished ? 'immo.card.furnished'.tr : 'immo.card.unfurnished'.tr),
      if (unit.capacity != null) (Icons.person_outline_rounded, 'immo.detail.capacity'.trParams({'count': '${unit.capacity}'})),
      if (unit.kitchen != null) (Icons.kitchen_outlined, 'immo.detail.kitchen_${unit.kitchen}'.tr),
      if (listing.isLand && unit.serviced) (Icons.bolt_rounded, 'immo.land.serviced'.tr),
    ];
    final threshold = unit.unitsTotal > 1 && unit.unitsAvailable > 0 && unit.unitsAvailable <= 4;

    return AppCard(
      onTap: onSelect,
      color: selected ? AppDesign.accentSubtle : null,
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSelectionDot(isSelected: selected),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.label, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
                    if (surface != null && surface != unit.label)
                      Text(surface, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
                  ],
                ),
              ),
              Obx(() => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        immoPrice(unit.price),
                        style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: AppDesign.accent),
                      ),
                      if (unit.oldPrice != null && unit.oldPrice! > unit.price)
                        Text(
                          immoPrice(unit.oldPrice!),
                          style: context.textStyle(FontSizeType.caption, color: context.ds.textTertiary)
                              .copyWith(decoration: TextDecoration.lineThrough),
                        ),
                      if (!listing.isLand)
                        Text('immo.card.per_month'.tr, style: context.textStyle(FontSizeType.caption, color: context.ds.textSecondary)),
                    ],
                  )),
            ],
          ),
          if (features.isNotEmpty) ...[
            const SizedBox(height: AppDesign.space3),
            Wrap(
              spacing: AppDesign.space4,
              runSpacing: AppDesign.space2,
              children: [
                for (final (icon, text) in features)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 18, color: context.ds.textSecondary),
                    const SizedBox(width: AppDesign.space1),
                    Text(text, style: context.textStyle(FontSizeType.body2, color: context.ds.textPrimary)),
                  ]),
              ],
            ),
          ],
          const Divider(height: AppDesign.space6),
          if (!unit.isAvailable)
            Text('immo.card.unavailable'.tr, style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w700, color: AppDesign.danger))
          else ...[
            if (threshold)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDesign.space1),
                child: Row(children: [
                  const Icon(Icons.error_rounded, size: 18, color: AppDesign.danger),
                  const SizedBox(width: AppDesign.space1),
                  Text(
                    'immo.detail.last_places'.trParams({'count': '${unit.unitsAvailable}'}),
                    style: context.textStyle(FontSizeType.body2, fontWeight: FontWeight.w700, color: AppDesign.danger),
                  ),
                ]),
              ),
            Row(children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppDesign.success, shape: BoxShape.circle)),
              const SizedBox(width: AppDesign.space2),
              Text(
                unit.availableFrom == null || !unit.availableFrom!.isAfter(DateTime.now())
                    ? (listing.isLand ? 'immo.card.land_available'.tr : 'immo.card.available_now'.tr)
                    : 'immo.card.available_from'.trParams({'date': immoDate(unit.availableFrom!)}),
                style: context.textStyle(FontSizeType.body2, color: context.ds.textPrimary),
              ),
            ]),
          ],
          const SizedBox(height: AppDesign.space3),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'immo.detail.contact_short'.tr,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: onContact,
                ),
              ),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                child: AppButton(
                  label: listing.isLand ? 'immo.detail.pay_deposit'.tr : 'immo.detail.reserve'.tr,
                  size: AppButtonSize.small,
                  onPressed: onReserve,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Protection ASSO, en accordéon (capture « Protection des locataires »).
class _Protection extends StatelessWidget {
  const _Protection({required this.listing});

  final RealEstateListing listing;

  @override
  Widget build(BuildContext context) {
    final days = '${listing.visitWindowDays}';
    final items = <(IconData, String, String)>[
      if (listing.isLand)
        (Icons.account_balance_outlined, 'immo.protection.partner_title'.tr, 'immo.protection.partner_body'.tr)
      else
        (Icons.badge_outlined, 'immo.protection.verified_title'.tr, 'immo.protection.verified_body'.tr),
      (
        Icons.verified_user_outlined,
        'immo.protection.payment_title'.tr,
        (listing.isLand ? 'immo.protection.payment_body_land' : 'immo.protection.payment_body').trParams({'days': days}),
      ),
      (Icons.gavel_rounded, 'immo.protection.dispute_title'.tr, 'immo.protection.dispute_body'.tr),
      (Icons.info_outline_rounded, 'immo.protection.fees_title'.tr, 'immo.protection.fees_body'.tr),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDesign.space2, vertical: AppDesign.space3),
      decoration: BoxDecoration(
        color: AppDesign.accentSubtle,
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesign.space2),
            child: Text(
              listing.isLand ? 'immo.protection.title_land'.tr : 'immo.protection.title'.tr,
              style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: AppDesign.accentText),
            ),
          ),
          for (final (icon, title, body) in items)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: AppDesign.space2),
                childrenPadding: const EdgeInsets.fromLTRB(48, 0, AppDesign.space2, AppDesign.space2),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                leading: Icon(icon, color: AppDesign.accentText),
                iconColor: AppDesign.accentText,
                collapsedIconColor: AppDesign.accentText,
                title: Text(title, style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600, color: AppDesign.neutral900)),
                children: [
                  Text(body, style: context.textStyle(FontSizeType.body2, color: AppDesign.neutral800, height: 1.45)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Carte du bailleur : vérifié, masqué avant paiement.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.listing, required this.onContact});

  final RealEstateListing listing;
  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    final owner = listing.owner;
    final name = listing.unlocked && (owner?.name?.isNotEmpty ?? false) ? owner!.name! : 'immo.owner.hidden_name'.tr;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDesign.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppDesign.accentSubtle,
                          child: const Icon(Icons.person_rounded, color: AppDesign.accent, size: 30),
                        ),
                        if (owner?.isVerified ?? false)
                          const Positioned(
                            right: -2,
                            bottom: -2,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.verified_rounded, size: 18, color: AppDesign.success),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: AppDesign.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
                          if (owner?.memberSince != null)
                            Text(
                              'immo.owner.member_since'.trParams({'year': '${owner!.memberSince}'}),
                              style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDesign.space3),
                if (owner?.isVerified ?? false) _bullet(context, 'immo.owner.identity_verified'.tr),
                _bullet(context, 'immo.owner.charter'.tr),
                const SizedBox(height: AppDesign.space2),
                if (listing.unlocked && owner?.phone != null)
                  Row(children: [
                    const Icon(Icons.phone_outlined, size: 18, color: AppDesign.success),
                    const SizedBox(width: AppDesign.space2),
                    Text(owner!.phone!, style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
                  ])
                else
                  Text('immo.owner.hidden_help'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDesign.space3),
            decoration: BoxDecoration(
              color: context.ds.surfaceMuted,
              border: Border(top: BorderSide(color: context.ds.border)),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'immo.detail.contact'.tr,
                variant: AppButtonVariant.secondary,
                expand: false,
                icon: Icons.chat_bubble_outline_rounded,
                onPressed: onContact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDesign.space1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Icon(Icons.circle, size: 6, color: AppDesign.accent),
            ),
            const SizedBox(width: AppDesign.space2),
            Expanded(child: Text(text, style: context.textStyle(FontSizeType.body1, color: context.ds.textPrimary))),
          ],
        ),
      );
}

/// Carte du cabinet partenaire d'un terrain.
class _CabinetCard extends StatelessWidget {
  const _CabinetCard({required this.listing});

  final RealEstateListing listing;

  @override
  Widget build(BuildContext context) {
    final cabinet = listing.cabinet!;
    final contact = cabinet.contact;

    return AppCard(
      onTap: () => ImmoNav.push(ImmoNav.cabinet, arguments: cabinet.id),
      padding: const EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ImmoCabinetLogo(url: cabinet.logoUrl, size: 52),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(cabinet.name, style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w700, color: context.ds.textPrimary)),
                      ),
                      if (cabinet.isVerified) ...[
                        const SizedBox(width: AppDesign.space1),
                        const Icon(Icons.verified_rounded, size: 18, color: AppDesign.success),
                      ],
                    ]),
                    if (cabinet.tagline != null)
                      Text(cabinet.tagline!, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.ds.textTertiary),
            ],
          ),
          const SizedBox(height: AppDesign.space3),
          if (cabinet.contactUnlocked && contact != null) ...[
            if (contact['phone'] != null) _line(context, Icons.phone_outlined, contact['phone'].toString()),
            if (contact['whatsapp'] != null) _line(context, Icons.chat_outlined, contact['whatsapp'].toString()),
            if (contact['email'] != null) _line(context, Icons.mail_outline_rounded, contact['email'].toString()),
            if (contact['address'] != null) _line(context, Icons.location_on_outlined, contact['address'].toString()),
          ] else
            Text('immo.cabinet.contact_hidden'.tr, style: context.textStyle(FontSizeType.body2, color: context.ds.textSecondary)),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: AppDesign.space1),
        child: Row(children: [
          Icon(icon, size: 18, color: AppDesign.success),
          const SizedBox(width: AppDesign.space2),
          Expanded(child: Text(text, style: context.textStyle(FontSizeType.body1, fontWeight: FontWeight.w600, color: context.ds.textPrimary))),
        ]),
      );
}

/// Barre fixe : prix, « Contacter ASSO », « Réserver ».
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.listing, required this.unit, required this.onContact, required this.onReserve});

  final RealEstateListing listing;
  final RealEstateUnit? unit;
  final VoidCallback onContact;
  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    final price = unit?.price ?? listing.price;
    final old = unit?.oldPrice ?? listing.oldPrice;
    final available = unit?.isAvailable ?? listing.unitsAvailable > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(context.ds.gutter, AppDesign.space3, context.ds.gutter, AppDesign.space3),
      decoration: BoxDecoration(
        color: context.ds.surface,
        border: Border(top: BorderSide(color: context.ds.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Obx(() => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (unit == null && listing.priceFrom)
                      Text('immo.card.from'.tr, style: context.textStyle(FontSizeType.caption, color: context.ds.textSecondary)),
                    Text(
                      listing.isLand ? immoPrice(price) : '${immoPrice(price)} ${'immo.card.per_month'.tr}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyle(FontSizeType.subtitle1, fontWeight: FontWeight.w800, color: context.ds.textPrimary),
                    ),
                    if (old != null && old > price)
                      Text(
                        immoPrice(old),
                        style: context.textStyle(FontSizeType.caption, color: context.ds.textTertiary)
                            .copyWith(decoration: TextDecoration.lineThrough),
                      ),
                  ],
                )),
          ),
          IconButton.outlined(
            tooltip: 'immo.detail.contact'.tr,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            onPressed: onContact,
          ),
          const SizedBox(width: AppDesign.space2),
          AppButton(
            label: listing.isLand ? 'immo.detail.pay_deposit'.tr : 'immo.detail.reserve'.tr,
            expand: false,
            onPressed: available ? onReserve : null,
          ),
        ],
      ),
    );
  }
}
