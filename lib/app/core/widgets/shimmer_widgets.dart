import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../utils/app_theme_system.dart';

/// Shimmer loading widgets for various UI components
class ShimmerWidgets {
  /// Product card shimmer loader
  static Widget productCardShimmer(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final baseColor = isDark ? AppThemeSystem.grey800 : AppThemeSystem.grey200;
    final highlightColor = isDark ? AppThemeSystem.grey700 : AppThemeSystem.grey100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppThemeSystem.getBorderColor(context).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
              ),
            ),
            // Content placeholder
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title lines
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Price
                  Container(
                    width: 80,
                    height: 20,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Location
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Horizontal product card shimmer loader
  static Widget horizontalProductCardShimmer(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final baseColor = isDark ? AppThemeSystem.grey800 : AppThemeSystem.grey200;
    final highlightColor = isDark ? AppThemeSystem.grey700 : AppThemeSystem.grey100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppThemeSystem.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 70,
                    height: 16,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 90,
                    height: 10,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner shimmer loader
  static Widget bannerShimmer(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final baseColor = isDark ? AppThemeSystem.grey800 : AppThemeSystem.grey200;
    final highlightColor = isDark ? AppThemeSystem.grey700 : AppThemeSystem.grey100;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            color: baseColor,
            height: double.infinity,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  /// Category chip shimmer loader
  static Widget categoryChipShimmer(BuildContext context) {
    final isDark = AppThemeSystem.isDarkMode(context);
    final baseColor = isDark ? AppThemeSystem.grey800 : AppThemeSystem.grey200;
    final highlightColor = isDark ? AppThemeSystem.grey700 : AppThemeSystem.grey100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          width: 80,
          height: 16,
          color: baseColor,
        ),
      ),
    );
  }

  /// Grid of product card shimmers
  static Widget productGridShimmer(BuildContext context, {int itemCount = 6}) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(
        horizontal: AppThemeSystem.getHorizontalPadding(context),
      ),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: AppThemeSystem.getDeviceType(context) == DeviceType.mobile ? 2 : 3,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => productCardShimmer(context),
          childCount: itemCount,
        ),
      ),
    );
  }

  /// Horizontal list of product card shimmers
  static Widget horizontalProductListShimmer(BuildContext context, {int itemCount = 5}) {
    return Container(
      height: 280,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppThemeSystem.getHorizontalPadding(context),
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => horizontalProductCardShimmer(context),
      ),
    );
  }

  /// Categories horizontal shimmer
  static Widget categoriesShimmer(BuildContext context, {int itemCount = 5}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppThemeSystem.getHorizontalPadding(context),
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => categoryChipShimmer(context),
      ),
    );
  }
}
