import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/models/real_estate_models.dart';
import '../../../data/providers/currency_service.dart';
import '../controllers/immo_home_controller.dart';

/// Obx seulement si [watch] : un Obx qui ne lit aucun prix (donc aucune
/// devise observable) lève « improper use of GetX ».
Widget immoCurrencyObx(bool watch, Widget Function() builder) =>
    watch ? Obx(builder) : builder();

/// Montant FCFA affiché dans la devise de l'utilisateur.
String immoPrice(num amount) =>
    CurrencyService.formatFromPivot(amount.toDouble());

bool immoHasDiscount(RealEstateListing listing, {RealEstateUnit? unit}) {
  if (listing.isLand) return ImmoLandPrice.of(listing, unit: unit).hasDiscount;
  final price = unit?.price ?? listing.price;
  final old = unit == null ? listing.oldPrice : unit.oldPrice;
  return old != null && old > price;
}

/// Land prices are displayed per m². Totals remain in the payment quote.
String immoOfferPrice(
  RealEstateListing listing, {
  RealEstateUnit? unit,
  bool old = false,
}) {
  if (listing.isLand) {
    final price = ImmoLandPrice.of(listing, unit: unit);
    final rate = old ? price.oldPerM2 : price.perM2;
    return rate == null ? 'immo.card.price_on_request'.tr : immoPerM2(rate);
  }
  final amount = unit == null
      ? (old ? listing.oldPrice : listing.price)
      : (old ? unit.oldPrice : unit.price);
  return '${immoPrice(amount ?? 0)}${listing.isRent ? ' ${'immo.card.per_month'.tr}' : ''}';
}

/// « 25 000 FCFA / m² » dans la devise de l'utilisateur.
String immoPerM2(double rate) => '${immoPrice(rate)} / m²';

/// Surface d'un morceau : « 1 000 m² » ou « 300 à 400 m² ».
String? immoLotSurface(RealEstateSubdivision sub) {
  final min = sub.lotSurfaceMin, max = sub.lotSurfaceMax;
  if (min == null) return null;
  final fmt = NumberFormat.decimalPattern(Get.locale?.languageCode ?? 'fr');
  return max == null || max == min
      ? '${fmt.format(min)} m²'
      : 'immo.land.surface_range'.trParams({
          'min': fmt.format(min),
          'max': fmt.format(max),
        });
}

/// Surface totale du terrain : « 1 000 m² », null si elle n'est pas connue.
String? immoTotalSurface(RealEstateListing listing) {
  final total = listing.subdivision?.totalSurfaceM2;
  if (total == null) return null;
  final fmt = NumberFormat.decimalPattern(Get.locale?.languageCode ?? 'fr');
  return '${fmt.format(total)} m²';
}

/// Terrain : « Morcelable · 7/8 disponibles » ou « Non morcelable ».
class ImmoSaleModeBadge extends StatelessWidget {
  const ImmoSaleModeBadge({super.key, required this.listing});

  final RealEstateListing listing;

  @override
  Widget build(BuildContext context) {
    final sub = listing.subdivision;
    if (!listing.isLand || sub == null) return const SizedBox.shrink();
    if (!sub.isPerLot) {
      return AppBadge(
        label: 'immo.land.sold_whole'.tr,
        icon: Icons.crop_square_rounded,
      );
    }
    return AppBadge(
      label: 'immo.land.sold_per_lot'.trParams({
        'available': '${sub.lotsAvailable}',
        'total': '${sub.lotsTotal}',
      }),
      tone: sub.lotsAvailable > 0 ? AppBadgeTone.info : AppBadgeTone.danger,
      icon: Icons.grid_view_rounded,
    );
  }
}

String immoDate(DateTime date) =>
    DateFormat.yMMMd(Get.locale?.languageCode ?? 'fr').format(date);

/// « Maison », « Villa », « Terrain constructible »…
String immoKindLabel(RealEstateListing listing) {
  final kind =
      listing.propertyKind ?? (listing.isLand ? 'building_land' : 'house');

  return 'immo.kinds.$kind'.tr;
}

/// « 3 pièces · 2 chambres ».
String immoRoomsLabel(RealEstateListing listing) {
  final parts = <String>[
    if (listing.rooms != null)
      'immo.card.rooms'.trParams({'count': '${listing.rooms}'}),
    if (listing.bedrooms != null)
      'immo.card.bedrooms'.trParams({'count': '${listing.bedrooms}'}),
    if (listing.rooms == null && listing.surfaceLabel != null)
      listing.surfaceLabel!,
  ];

  return parts.join(' · ');
}

/// Icône Material d'un équipement, à partir du nom renvoyé par l'API.
IconData immoAmenityIcon(String? name) {
  const icons = <String, IconData>{
    'bathtub': Icons.bathtub_outlined,
    'wifi': Icons.wifi_rounded,
    'grid_view': Icons.grid_view_rounded,
    'roofing': Icons.roofing_rounded,
    'new_releases': Icons.new_releases_outlined,
    'nights_stay': Icons.nights_stay_outlined,
    'water_drop': Icons.water_drop_outlined,
    'water': Icons.water_outlined,
    'bolt': Icons.bolt_rounded,
    'solar_power': Icons.solar_power_outlined,
    'ac_unit': Icons.ac_unit_rounded,
    'mode_fan_off': Icons.mode_fan_off_outlined,
    'hot_tub': Icons.hot_tub_outlined,
    'kitchen': Icons.kitchen_outlined,
    'tv': Icons.tv_rounded,
    'bed': Icons.bed_outlined,
    'door_sliding': Icons.door_sliding_outlined,
    'balcony': Icons.balcony_outlined,
    'yard': Icons.yard_outlined,
    'local_parking': Icons.local_parking_rounded,
    'security': Icons.security_rounded,
    'videocam': Icons.videocam_outlined,
    'fence': Icons.fence_rounded,
    'cleaning_services': Icons.cleaning_services_outlined,
    'delete': Icons.delete_outline_rounded,
    'support_agent': Icons.support_agent_rounded,
  };

  return icons[name] ?? Icons.check_circle_outline_rounded;
}

/// Carrousel de photos avec points, posé en haut des cartes et de la fiche.
class ImmoPhotoCarousel extends StatefulWidget {
  const ImmoPhotoCarousel({
    super.key,
    required this.images,
    required this.height,
    this.overlay = const [],
    this.borderRadius,
    this.onTap,
  });

  final List<String> images;
  final double height;
  final List<Widget> overlay;
  final BorderRadius? borderRadius;
  final ValueChanged<int>? onTap;

  @override
  State<ImmoPhotoCarousel> createState() => _ImmoPhotoCarouselState();
}

class _ImmoPhotoCarouselState extends State<ImmoPhotoCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final images = widget.images;

    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (images.isEmpty)
              ColoredBox(
                color: context.ds.surfaceMuted,
                child: Icon(
                  Icons.home_work_outlined,
                  size: 48,
                  color: context.ds.textTertiary,
                ),
              )
            else
              PageView.builder(
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: widget.onTap == null ? null : () => widget.onTap!(i),
                  child: AppNetworkImage(
                    url: images[i],
                    decodeSize: Size(width, widget.height),
                  ),
                ),
              ),
            if (images.length > 1)
              Positioned(
                bottom: AppDesign.space2,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(images.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: active ? 14 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: active ? 1 : 0.6),
                        borderRadius: BorderRadius.circular(
                          AppDesign.radiusPill,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ...widget.overlay,
          ],
        ),
      ),
    );
  }
}

/// Bouton cœur rond, sur fond blanc, posé sur une photo.
class ImmoFavoriteButton extends StatelessWidget {
  const ImmoFavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(AppDesign.space2),
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20,
            color: isFavorite ? AppDesign.accent : AppDesign.neutral800,
          ),
        ),
      ),
    );
  }
}

/// Pastille posée sur une photo (À la une, Réduction, Visite pièce par pièce).
class ImmoPhotoTag extends StatelessWidget {
  const ImmoPhotoTag({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.textColor,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space2,
        vertical: AppDesign.space1,
      ),
      decoration: BoxDecoration(
        color: color ?? AppDesign.neutral900.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: AppDesign.space1),
          ],
          Text(
            label,
            style: context.textStyle(
              FontSizeType.caption,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Disponibilité : « Disponible immédiatement » ou « à partir du … ».
class ImmoAvailability extends StatelessWidget {
  const ImmoAvailability({super.key, required this.listing});

  final RealEstateListing listing;

  @override
  Widget build(BuildContext context) {
    final soldOut = listing.unitsAvailable <= 0;
    final now = listing.availableNow || listing.availableFrom == null;
    final color = soldOut
        ? AppDesign.danger
        : (now ? AppDesign.success : AppDesign.info);
    final label = soldOut
        ? (listing.isLand ? 'immo.card.unavailable'.tr : 'immo.card.reserved'.tr)
        : now
        ? (listing.isLand
              ? 'immo.card.land_available'.tr
              : 'immo.card.available_now'.tr)
        : 'immo.card.available_from'.trParams({
            'date': immoDate(listing.availableFrom!),
          });

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppDesign.space2),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.body2,
              fontWeight: FontWeight.w600,
              color: context.ds.textPrimary,
            ),
          ),
        ),
        if (listing.lowStock && !soldOut)
          AppBadge(
            label: 'immo.card.places_left'.trParams({
              'count': '${listing.unitsAvailable}',
            }),
            tone: AppBadgeTone.danger,
            icon: Icons.error_outline_rounded,
          ),
      ],
    );
  }
}

/// Prix orange, avec « À partir de » et ancien prix barré. Un terrain
/// affiche son prix au m² et son prix global ([ImmoLandPriceText]).
class ImmoPriceText extends StatelessWidget {
  const ImmoPriceText({
    super.key,
    required this.listing,
    this.large = false,
    this.landPrice,
  });

  final RealEstateListing listing;
  final bool large;

  /// Prix déjà calculé par le contrôleur ; sinon calculé ici.
  final ImmoLandPrice? landPrice;

  @override
  Widget build(BuildContext context) {
    if (listing.isLand) {
      final sub = listing.subdivision;
      return ImmoLandPriceText(
        price: landPrice ?? ImmoLandPrice.of(listing),
        lotSurface: sub == null ? null : immoLotSurface(sub),
        large: large,
      );
    }
    return Obx(() {
      final price = immoOfferPrice(listing);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (listing.priceFrom && !listing.isSale)
            Text(
              'immo.card.from'.tr,
              style: context.textStyle(
                FontSizeType.caption,
                color: context.ds.textSecondary,
              ),
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppDesign.space2,
            children: [
              Text(
                price,
                style: context.textStyle(
                  large ? FontSizeType.h5 : FontSizeType.subtitle1,
                  fontWeight: FontWeight.w800,
                  color: AppDesign.accent,
                ),
              ),
              if (immoHasDiscount(listing))
                Text(
                  immoOfferPrice(listing, old: true),
                  style: context
                      .textStyle(
                        FontSizeType.body2,
                        color: context.ds.textTertiary,
                      )
                      .copyWith(decoration: TextDecoration.lineThrough),
                ),
            ],
          ),
        ],
      );
    });
  }
}

/// Prix d'un terrain : prix au m² en grand (ancien prix barré), prix global
/// en dessous. Sans prix au m² connu, le prix global passe en grand.
/// Montants convertis dans la devise de l'utilisateur.
class ImmoLandPriceText extends StatelessWidget {
  const ImmoLandPriceText({
    super.key,
    required this.price,
    this.lotSurface,
    this.large = false,
    this.end = false,
    this.color,
    this.showFrom = true,
  });

  final ImmoLandPrice price;

  /// « 1 000 m² » : complète « le morceau de … » sous le prix global.
  final String? lotSurface;
  final bool large;

  /// Aligné à droite (carte d'un lot).
  final bool end;
  final Color? color;
  final bool showFrom;

  /// Surface du morceau affiché ; à défaut, la fourchette de l'annonce.
  String? get _lotSurface {
    final m2 = price.lotSurface;
    if (m2 == null) return lotSurface;
    final fmt = NumberFormat.decimalPattern(Get.locale?.languageCode ?? 'fr');
    return '${fmt.format(m2)} m²';
  }

  String _totalLine(int total) {
    final amount = immoPrice(total);
    if (!price.perLot) {
      return 'immo.land.total_price'.trParams({'amount': amount});
    }
    final lot = _lotSurface == null
        ? 'immo.land.per_lot'.tr
        : 'immo.land.per_lot_of'.trParams({'surface': _lotSurface!});
    return '$amount $lot';
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.textStyle(
      FontSizeType.caption,
      color: context.ds.textSecondary,
    );
    final main = context.textStyle(
      large ? FontSizeType.h5 : FontSizeType.subtitle1,
      fontWeight: FontWeight.w800,
      color: color ?? context.ds.textPrimary,
    );
    final struck = context
        .textStyle(FontSizeType.body2, color: context.ds.textTertiary)
        .copyWith(decoration: TextDecoration.lineThrough);
    final align = end ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return immoCurrencyObx(price.perM2 != null || price.total != null, () {
      final perM2 = price.perM2;
      final total = price.total;
      final String headline;
      String? old;
      String? sub;
      if (perM2 != null) {
        headline = immoPerM2(perM2);
        if (price.hasDiscount) old = immoPerM2(price.oldPerM2!);
        if (total != null) sub = _totalLine(total);
      } else if (total != null) {
        headline = price.perLot ? immoPrice(total) : _totalLine(total);
        if (price.hasDiscount) old = immoPrice(price.oldTotal!);
        if (price.perLot) {
          sub = _lotSurface == null
              ? 'immo.land.per_lot'.tr
              : 'immo.land.per_lot_of'.trParams({'surface': _lotSurface!});
        }
      } else {
        headline = 'immo.card.price_on_request'.tr;
      }

      return Column(
        crossAxisAlignment: align,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showFrom && price.from)
            Text(
              price.perLot ? 'immo.land.from'.tr : 'immo.card.from'.tr,
              style: muted,
            ),
          Wrap(
            alignment: end ? WrapAlignment.end : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: AppDesign.space2,
            children: [
              Text(headline, style: main),
              if (old != null) Text(old, style: struck),
            ],
          ),
          if (sub != null)
            Text(sub, style: muted, textAlign: end ? TextAlign.end : null),
        ],
      );
    });
  }
}

/// Carte d'une maison à louer ou à vendre (maquette ASSO + Studapart).
class ImmoHouseCard extends StatelessWidget {
  const ImmoHouseCard({
    super.key,
    required this.listing,
    required this.onTap,
    required this.onFavorite,
  });

  final RealEstateListing listing;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final details = immoRoomsLabel(listing);
    final extras = [
      if (listing.furnished && !listing.isSale) 'immo.card.furnished'.tr,
      ...listing.amenityNames,
    ].take(3).join(' - ');

    return AppCard(
      padding: EdgeInsets.zero,
      clipContent: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImmoPhotoCarousel(
            images: listing.images,
            height: 190,
            onTap: (_) => onTap(),
            overlay: [
              Positioned(
                top: AppDesign.space2,
                left: AppDesign.space2,
                right: 56,
                child: Wrap(
                  spacing: AppDesign.space1,
                  runSpacing: AppDesign.space1,
                  children: [
                    ImmoPhotoTag(
                      label:
                          (listing.isSale
                                  ? 'immo.card.house_for_sale'
                                  : 'immo.home.transaction_rent')
                              .tr,
                    ),
                    if (listing.isFeatured)
                      ImmoPhotoTag(
                        label: 'immo.card.featured'.tr,
                        color: AppDesign.accent,
                        icon: Icons.star_rounded,
                      ),
                    if (listing.oldPrice != null ||
                        (listing.promoText?.isNotEmpty ?? false))
                      ImmoPhotoTag(
                        label: 'immo.card.discount'.tr,
                        color: AppDesign.info,
                        icon: Icons.bolt_rounded,
                      ),
                    if (listing.hasRoomTour)
                      ImmoPhotoTag(
                        label: 'immo.card.room_tour'.tr,
                        icon: Icons.view_carousel_outlined,
                      ),
                  ],
                ),
              ),
              Positioned(
                top: AppDesign.space2,
                right: AppDesign.space2,
                child: ImmoFavoriteButton(
                  isFavorite: listing.isFavorite,
                  onPressed: onFavorite,
                ),
              ),
              if (listing.hasVideo)
                Positioned(
                  bottom: AppDesign.space2,
                  right: AppDesign.space2,
                  child: ImmoPhotoTag(
                    label: 'immo.card.video'.tr,
                    icon: Icons.play_circle_outline_rounded,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppDesign.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.subtitle1,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textPrimary,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: AppDesign.space1),
                  _IconLine(icon: Icons.bed_outlined, text: details),
                ],
                const SizedBox(height: AppDesign.space1),
                _IconLine(
                  icon: Icons.location_on_outlined,
                  text: listing.place,
                ),
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: AppDesign.space1),
                  Text(
                    extras,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyle(
                      FontSizeType.body2,
                      color: context.ds.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppDesign.space2),
                ImmoPriceText(listing: listing),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesign.space3,
              vertical: AppDesign.space2 + 2,
            ),
            decoration: BoxDecoration(
              color: context.ds.surfaceMuted,
              border: Border(top: BorderSide(color: context.ds.border)),
            ),
            child: ImmoAvailability(listing: listing),
          ),
        ],
      ),
    );
  }
}

/// Carte d'un terrain à vendre (SeLoger Construire + affiche du cabinet).
class ImmoLandCard extends StatelessWidget {
  const ImmoLandCard({
    super.key,
    required this.listing,
    required this.onTap,
    required this.onFavorite,
    this.onCabinet,
    this.landPrice,
  });

  final RealEstateListing listing;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback? onCabinet;

  /// Prix préparé par [ImmoHomeController] ; calculé ici à défaut.
  final ImmoLandPrice? landPrice;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      clipContent: true,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImmoPhotoCarousel(
            images: listing.images,
            height: 190,
            onTap: (_) => onTap(),
            overlay: [
              if (listing.isFeatured)
                Positioned(
                  top: AppDesign.space2,
                  left: AppDesign.space2,
                  child: ImmoPhotoTag(
                    label: 'immo.card.featured'.tr,
                    color: AppDesign.warningSubtle,
                    textColor: AppDesign.warningText,
                  ),
                ),
              Positioned(
                top: AppDesign.space2,
                right: AppDesign.space2,
                child: ImmoFavoriteButton(
                  isFavorite: listing.isFavorite,
                  onPressed: onFavorite,
                ),
              ),
              if (listing.photosCount > 0)
                Positioned(
                  bottom: AppDesign.space2,
                  right: AppDesign.space2,
                  child: ImmoPhotoTag(
                    label: '${listing.photosCount}',
                    icon: Icons.photo_camera_outlined,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppDesign.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  immoKindLabel(listing),
                  style: context.textStyle(
                    FontSizeType.body2,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDesign.space1),
                ImmoPriceText(
                  listing: listing,
                  large: true,
                  landPrice: landPrice,
                ),
                if (listing.subdivision != null) ...[
                  const SizedBox(height: AppDesign.space2),
                  ImmoSaleModeBadge(listing: listing),
                ],
                const SizedBox(height: AppDesign.space1),
                Text(
                  listing.place,
                  style: context.textStyle(
                    FontSizeType.body1,
                    color: context.ds.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDesign.space3),
                _LandRow(
                  icon: Icons.description_outlined,
                  label: 'immo.land.title_deed'.tr,
                  value: listing.landTitled
                      ? 'immo.land.titled'.tr
                      : 'immo.land.not_titled'.tr,
                  highlighted: listing.landTitled,
                ),
                if (immoTotalSurface(listing) case final total?) ...[
                  const SizedBox(height: AppDesign.space2),
                  _LandRow(
                    icon: Icons.straighten_rounded,
                    label: 'immo.land.total_surface'.tr,
                    value: total,
                    highlighted: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandRow extends StatelessWidget {
  const _LandRow({
    required this.icon,
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AppDesign.successText : context.ds.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesign.space3,
        vertical: AppDesign.space2 + 2,
      ),
      decoration: BoxDecoration(
        color: highlighted ? AppDesign.successSubtle : context.ds.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: AppDesign.space2),
          Text(
            label,
            style: context.textStyle(
              FontSizeType.body2,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
          const SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.body2,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.ds.textSecondary),
        const SizedBox(width: AppDesign.space1 + 2),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.body2,
              color: context.ds.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo d'un cabinet, avec repli sur une icône.
class ImmoCabinetLogo extends StatelessWidget {
  const ImmoCabinetLogo({super.key, required this.url, this.size = 40});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.ds.surface,
        shape: BoxShape.circle,
        border: Border.all(color: context.ds.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? Icon(
              Icons.account_balance_outlined,
              size: size * 0.5,
              color: context.ds.textSecondary,
            )
          : AppNetworkImage(
              url: url!,
              decodeSize: Size(size, size),
              fit: BoxFit.contain,
            ),
    );
  }
}

/// Puce de filtre (Tous, Prix, Localisation…).
class ImmoFilterChip extends StatelessWidget {
  const ImmoFilterChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.trailing = Icons.keyboard_arrow_down_rounded,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : context.ds.textPrimary;

    return Material(
      color: selected ? AppDesign.accent : context.ds.surfaceMuted,
      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesign.space3,
            vertical: AppDesign.space2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.body2,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
              if (icon != null || trailing != null) ...[
                const SizedBox(width: AppDesign.space1),
                Icon(icon ?? trailing, size: 18, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Squelette d'une carte pendant le chargement.
class ImmoCardSkeleton extends StatelessWidget {
  const ImmoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final base = isDark ? AppThemeSystem.grey800 : AppThemeSystem.grey200;
    final highlight = isDark ? AppThemeSystem.grey700 : AppThemeSystem.grey100;
    Widget block(double height, {double? width}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(AppDesign.radiusXs),
      ),
    );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(190),
          const SizedBox(height: AppDesign.space3),
          block(16, width: 180),
          const SizedBox(height: AppDesign.space2),
          block(14, width: 140),
          const SizedBox(height: AppDesign.space2),
          block(18, width: 120),
        ],
      ),
    );
  }
}
