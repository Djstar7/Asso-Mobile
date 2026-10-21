import 'package:flutter/material.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';

/// Deux colonnes identiques dans le devis, la confirmation et la réservation.
class ImmoSummaryRow extends StatelessWidget {
  const ImmoSummaryRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
    this.secondary = false,
    this.help,
  });

  final String label;
  final String value;
  final bool bold;
  final bool secondary;
  final String? help;

  @override
  Widget build(BuildContext context) {
    final size = bold
        ? FontSizeType.subtitle1
        : secondary
        ? FontSizeType.body2
        : FontSizeType.body1;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesign.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textStyle(
                    size,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
                    color: secondary
                        ? context.ds.textSecondary
                        : context.ds.textPrimary,
                  ),
                ),
                if (help != null)
                  Text(
                    help!,
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: context.ds.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppDesign.space3),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.textStyle(
                size,
                fontWeight: bold
                    ? FontWeight.w800
                    : secondary
                    ? FontWeight.w400
                    : FontWeight.w600,
                color: bold ? AppDesign.accent : context.ds.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
