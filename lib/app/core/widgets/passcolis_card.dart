import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/diaspo_offer.dart';
import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import 'app_ui.dart';

/// Carte d'une offre Passcolis (trajet diaspo avec des kilos à vendre).
///
/// Deux présentations pour un même objet, afin que l'utilisateur reconnaisse
/// une offre qu'il l'ait croisée sur l'accueil ou dans la recherche :
/// - [PasscolisCard.compact] pour le carrousel horizontal de l'accueil,
///   à largeur contrainte ;
/// - [PasscolisCard] (par défaut) pour une liste verticale pleine largeur.
class PasscolisCard extends StatelessWidget {
  const PasscolisCard({super.key, required this.offer, this.onTap})
    : compact = false;

  const PasscolisCard.compact({super.key, required this.offer, this.onTap})
    : compact = true;

  final DiaspoOffer offer;
  final VoidCallback? onTap;
  final bool compact;

  /// Largeur d'une vignette du carrousel d'accueil : toute la largeur utile.
  ///
  /// Une seule offre à la fois, lisible d'un coup d'œil ; les points sous le
  /// carrousel disent qu'il y en a d'autres, là où une carte tronquée sur le
  /// bord ne faisait que rogner l'information.
  static double compactWidth(BuildContext context) {
    return MediaQuery.sizeOf(context).width - context.ds.gutter * 2;
  }

  /// Hauteur fixe du carrousel, pour que le `SizedBox` parent n'ait pas à
  /// mesurer ses enfants. Deux lignes de contenu et les marges de la carte.
  static const double compactHeight = 96;

  void _open() {
    if (onTap != null) {
      onTap!();
      return;
    }
    Get.toNamed('/diaspo/detail', arguments: {'offer': offer});
  }

  @override
  Widget build(BuildContext context) {
    // En compact, la carte est réduite à ce qu'on lit d'un coup d'œil : le
    // trajet, la date, le prix. Pas de séparateur ni de libellé « Prix par
    // kilo » — le « /kg » le dit déjà, et chaque ligne gagnée était du vide
    // sous le contenu.
    if (compact) {
      return AppCard(
        onTap: _open,
        padding: EdgeInsets.symmetric(
          horizontal: AppDesign.space3,
          vertical: AppDesign.space3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoute(context),
            SizedBox(height: AppDesign.space2),
            _buildCompactFooter(context),
          ],
        ),
      );
    }

    return AppCard(
      onTap: _open,
      padding: EdgeInsets.all(AppDesign.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRoute(context),
          SizedBox(height: AppDesign.space3),
          _buildDepartureDate(context),
          SizedBox(height: AppDesign.space3),
          Divider(height: 1, color: context.ds.border),
          SizedBox(height: AppDesign.space3),
          _buildPriceRow(context),
        ],
      ),
    );
  }

  /// Pied de la carte compacte : date à gauche, prix et kilos à droite.
  ///
  /// Tout tient sur une ligne, ce qui évite la pile date / séparateur / prix
  /// qui allongeait la carte pour trois informations courtes.
  Widget _buildCompactFooter(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.event_rounded, size: 13, color: context.ds.textTertiary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            _formatShortDate(offer.departureDateTime),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.overline,
              color: context.ds.textSecondary,
            ),
          ),
        ),
        SizedBox(width: AppDesign.space2),
        Text(
          '${offer.formattedPricePerKg} ${offer.currencySymbol}/kg',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyle(
            FontSizeType.body2,
            fontWeight: FontWeight.w700,
            color: AppThemeSystem.primaryColor,
          ),
        ),
      ],
    );
  }

  /// Trajet départ → arrivée.
  ///
  /// En compact, les deux villes tiennent sur une ligne avec une flèche :
  /// la carte est trop courte pour la timeline verticale de la liste.
  Widget _buildRoute(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          const Icon(
            Icons.flight_takeoff_rounded,
            size: 16,
            color: AppDesign.success,
          ),
          SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(
              offer.departureCity,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.body2,
                fontWeight: FontWeight.w700,
                color: context.ds.textPrimary,
              ),
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: context.ds.textTertiary,
          ),
          SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(
              offer.arrivalCity,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyle(
                FontSizeType.body2,
                fontWeight: FontWeight.w700,
                color: context.ds.textPrimary,
              ),
            ),
          ),
          SizedBox(width: AppDesign.space2),
          // Les kilos restants décident de la réservation : ils remontent sur
          // la ligne du trajet plutôt que d'occuper une rangée à eux seuls.
          Text(
            '${_formatKg(offer.remainingKg)} kg',
            style: context.textStyle(
              FontSizeType.overline,
              fontWeight: FontWeight.w700,
              color: offer.remainingKg > 0
                  ? AppDesign.successText
                  : context.ds.textTertiary,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCityLine(
          context,
          Icons.flight_takeoff_rounded,
          AppDesign.success,
          '${offer.departureCity}, ${offer.departureCountry}',
        ),
        Padding(
          padding: EdgeInsets.only(left: AppDesign.space2 - 1),
          child: Container(
            width: 2,
            height: 14,
            margin: const EdgeInsets.symmetric(vertical: 3),
            color: context.ds.border,
          ),
        ),
        _buildCityLine(
          context,
          Icons.flight_land_rounded,
          AppDesign.danger,
          '${offer.arrivalCity}, ${offer.arrivalCountry}',
        ),
      ],
    );
  }

  Widget _buildCityLine(
    BuildContext context,
    IconData icon,
    Color color,
    String label,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        SizedBox(width: AppDesign.space2),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.body2,
              fontWeight: FontWeight.w700,
              color: context.ds.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartureDate(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.event_rounded, size: 14, color: context.ds.textTertiary),
        SizedBox(width: AppDesign.space2 - 2),
        Expanded(
          child: Text(
            _formatDate(offer.departureDateTime),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyle(
              FontSizeType.caption,
              color: context.ds.textSecondary,
            ),
          ),
        ),
        // Sur une liste large, l'avertissement tient à côté de la date ;
        // en compact il ferait passer la carte à la ligne.
        if (!compact && !offer.profileVerified)
          const AppBadge(
            label: 'Profil non vérifié',
            tone: AppBadgeTone.warning,
          ),
      ],
    );
  }

  Widget _buildPriceRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prix par kilo',
                style: context.textStyle(
                  FontSizeType.caption,
                  color: context.ds.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${offer.formattedPricePerKg} ${offer.currencySymbol}/kg',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyle(
                  compact ? FontSizeType.body2 : FontSizeType.body1,
                  fontWeight: FontWeight.w700,
                  color: AppThemeSystem.primaryColor,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: AppDesign.space2),
        AppBadge(
          label: '${_formatKg(offer.remainingKg)} kg dispo',
          tone: offer.remainingKg > 0
              ? AppBadgeTone.success
              : AppBadgeTone.neutral,
        ),
      ],
    );
  }

  /// Date sans l'année : sur une carte étroite, un départ se lit « 12 mars ».
  /// L'année n'apparaît que si le voyage déborde sur la suivante.
  static String _formatShortDate(DateTime date) {
    final now = DateTime.now();
    final short = '${date.day} ${_months[date.month - 1]}';
    return date.year == now.year ? short : '$short ${date.year}';
  }

  static const _months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  static String _formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  /// Les décimales n'ont de sens que si le voyageur en a saisi.
  static String _formatKg(double kg) {
    return kg == kg.roundToDouble()
        ? kg.toStringAsFixed(0)
        : kg.toStringAsFixed(1);
  }
}

/// Squelette d'une carte compacte, affiché pendant le chargement du carrousel.
class PasscolisCardShimmer extends StatelessWidget {
  const PasscolisCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final base = context.ds.surfaceMuted;

    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(AppDesign.space1),
      ),
    );

    return AppCard(
      padding: EdgeInsets.all(AppDesign.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          bar(double.infinity, 16),
          SizedBox(height: AppDesign.space3),
          bar(120, 12),
          SizedBox(height: AppDesign.space3),
          Divider(height: 1, color: context.ds.border),
          SizedBox(height: AppDesign.space3),
          Row(
            children: [
              Expanded(child: bar(80, 24)),
              SizedBox(width: AppDesign.space2),
              bar(72, 22),
            ],
          ),
        ],
      ),
    );
  }
}
