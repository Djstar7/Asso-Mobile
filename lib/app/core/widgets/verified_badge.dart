import 'package:flutter/material.dart';
import '../../core/utils/app_design.dart';

/// Blue verified badge widget for certified shops/vendors
/// Usage: VerifiedBadge(isCertified: shop['is_certified'] ?? false)
class VerifiedBadge extends StatelessWidget {
  final bool isCertified;
  final double size;
  final Color? color;

  const VerifiedBadge({
    super.key,
    required this.isCertified,
    this.size = 16,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCertified) return const SizedBox.shrink();

    return Icon(
      Icons.verified,
      size: size,
      color: color ?? AppDesign.info, // Twitter blue
    );
  }
}

/// Blue verified badge with text label
class VerifiedBadgeWithLabel extends StatelessWidget {
  final bool isCertified;
  final double iconSize;
  final TextStyle? textStyle;
  final Color? color;

  const VerifiedBadgeWithLabel({
    super.key,
    required this.isCertified,
    this.iconSize = 14,
    this.textStyle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCertified) return const SizedBox.shrink();

    final badgeColor = color ?? AppDesign.info;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.verified,
          size: iconSize,
          color: badgeColor,
        ),
        const SizedBox(width: 4),
        Text(
          'Certifié',
          style: textStyle ??
              TextStyle(
                fontSize: iconSize - 2,
                color: badgeColor,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
