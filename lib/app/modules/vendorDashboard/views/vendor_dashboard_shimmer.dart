import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';

/// Squelette de chargement du tableau de bord.
///
/// Il reproduit la structure réelle de [VendorDashboardView] — une carte
/// d'en-tête, une statistique principale, deux rangées de cartes, le forfait
/// puis la liste de gestion — pour que le contenu ne se réorganise pas à la
/// fin du chargement.
class VendorDashboardShimmer extends StatelessWidget {
  const VendorDashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ds.maxContentWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              ds.gutter,
              AppDesign.space2,
              ds.gutter,
              MediaQuery.of(context).viewPadding.bottom + AppDesign.space8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerShimmer(context),
                SizedBox(height: AppDesign.space6),
                _sectionTitleShimmer(context),
                SizedBox(height: AppDesign.space3),
                _primaryStatShimmer(context),
                SizedBox(height: AppDesign.space3),
                _statRowShimmer(context),
                SizedBox(height: AppDesign.space3),
                _statRowShimmer(context),
                SizedBox(height: AppDesign.space8),
                _sectionTitleShimmer(context),
                SizedBox(height: AppDesign.space3),
                _packageShimmer(context),
                SizedBox(height: AppDesign.space8),
                _sectionTitleShimmer(context),
                SizedBox(height: AppDesign.space3),
                _actionsShimmer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Enveloppe commune : une seule définition des teintes de shimmer.
  Widget _shimmer(BuildContext context, Widget child) {
    final isDark = context.isDarkMode;
    return Shimmer.fromColors(
      baseColor: isDark ? AppDesign.neutralDark600 : AppDesign.neutral100,
      highlightColor: isDark ? AppDesign.neutralDark700 : AppDesign.neutral25,
      child: child,
    );
  }

  /// Bloc plein servant de substitut à un texte ou une image.
  Widget _block(BuildContext context, {double? width, required double height, double radius = AppDesign.radiusXs}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.ds.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  /// Carte vide aux mêmes bordures que les cartes réelles.
  Widget _card(BuildContext context, {required Widget child, EdgeInsets? padding}) {
    final ds = context.ds;
    return Container(
      padding: padding ?? EdgeInsets.all(AppDesign.space5),
      decoration: BoxDecoration(
        color: ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        border: Border.all(color: ds.border),
      ),
      child: child,
    );
  }

  Widget _sectionTitleShimmer(BuildContext context) =>
      _shimmer(context, _block(context, width: 110, height: 16));

  Widget _headerShimmer(BuildContext context) {
    final logoSize = context.deviceType == DeviceType.mobile ? 56.0 : 72.0;

    return _shimmer(
      context,
      _card(
        context,
        padding: EdgeInsets.all(AppDesign.space4),
        child: Row(
          children: [
            _block(context,
                width: logoSize, height: logoSize, radius: AppDesign.radiusMd),
            SizedBox(width: AppDesign.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _block(context, width: 150, height: 16),
                  SizedBox(height: AppDesign.space2),
                  _block(context, width: 100, height: 12),
                  SizedBox(height: AppDesign.space2),
                  _block(context,
                      width: 130, height: 18, radius: AppDesign.radiusPill),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _primaryStatShimmer(BuildContext context) {
    return _shimmer(
      context,
      _card(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block(context, width: 120, height: 12),
            SizedBox(height: AppDesign.space2),
            _block(context, width: 180, height: 32),
            SizedBox(height: AppDesign.space1),
            _block(context, width: 110, height: 11),
          ],
        ),
      ),
    );
  }

  Widget _statRowShimmer(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _statCardShimmer(context)),
          SizedBox(width: AppDesign.space3),
          Expanded(child: _statCardShimmer(context)),
        ],
      ),
    );
  }

  Widget _statCardShimmer(BuildContext context) {
    return _shimmer(
      context,
      _card(
        context,
        padding: EdgeInsets.all(AppDesign.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _block(context, width: 18, height: 18),
            SizedBox(height: AppDesign.space3),
            _block(context, width: 70, height: 24),
            SizedBox(height: AppDesign.space1),
            _block(context, width: 90, height: 11),
          ],
        ),
      ),
    );
  }

  Widget _packageShimmer(BuildContext context) {
    return _shimmer(
      context,
      _card(
        context,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _block(context, width: 140, height: 16),
                      SizedBox(height: AppDesign.space1),
                      _block(context, width: 90, height: 12),
                    ],
                  ),
                ),
                _block(context, width: 48, height: 20, radius: AppDesign.radiusPill),
              ],
            ),
            SizedBox(height: AppDesign.space5),
            Row(
              children: [
                Expanded(child: _block(context, height: 12)),
                SizedBox(width: AppDesign.space4),
                _block(context, width: 90, height: 12),
              ],
            ),
            SizedBox(height: AppDesign.space2),
            _block(context,
                width: double.infinity, height: 6, radius: AppDesign.radiusPill),
            SizedBox(height: AppDesign.space2),
            _block(context, width: 190, height: 11),
            SizedBox(height: AppDesign.space4),
            _block(context, width: double.infinity, height: 1, radius: 0),
            SizedBox(height: AppDesign.space4),
            _block(context, width: 210, height: 12),
          ],
        ),
      ),
    );
  }

  Widget _actionsShimmer(BuildContext context) {
    final ds = context.ds;

    return _shimmer(
      context,
      Container(
        decoration: BoxDecoration(
          color: ds.surface,
          borderRadius: BorderRadius.circular(AppDesign.radiusLg),
          border: Border.all(color: ds.border),
        ),
        child: Column(
          children: List.generate(5, (index) {
            return Column(
              children: [
                if (index > 0)
                  Padding(
                    padding: EdgeInsets.only(
                      left: AppDesign.space4 + 20 + AppDesign.space3,
                    ),
                    child: Divider(height: 1, color: ds.border),
                  ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppDesign.space4,
                    vertical: AppDesign.space4,
                  ),
                  child: Row(
                    children: [
                      _block(context, width: 20, height: 20),
                      SizedBox(width: AppDesign.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _block(context, width: 130, height: 14),
                            SizedBox(height: AppDesign.space1),
                            _block(context, width: 180, height: 11),
                          ],
                        ),
                      ),
                      _block(context, width: 18, height: 18),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
