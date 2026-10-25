import 'package:flutter/material.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';

/// Motif discret natif : bulles et colis, sans image ni téléchargement.
class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = AppThemeSystem.isDarkMode(context);
    return ColoredBox(
      color: Color.alphaBlend(
        AppDesign.accent.withValues(alpha: dark ? .025 : .035),
        AppDesign.canvas(context),
      ),
      child: CustomPaint(
        painter: _ChatWallpaperPainter(
          color: (dark ? AppDesign.neutral400 : AppDesign.neutral600)
              .withValues(alpha: dark ? .06 : .065),
        ),
        child: child,
      ),
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
  const _ChatWallpaperPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var row = 0; row * 120 < size.height + 120; row++) {
      for (var col = 0; col * 112 < size.width + 112; col++) {
        final x = col * 112.0 + (row.isOdd ? 56 : 0) + 20;
        final y = row * 120.0 + 30;
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate((row + col).isEven ? -.18 : .15);
        if ((row + col) % 3 == 0) {
          // Un colis, écho aux échanges entre acheteurs et boutiques.
          final parcel = Path()
            ..moveTo(0, 7)
            ..lineTo(15, 0)
            ..lineTo(30, 7)
            ..lineTo(30, 25)
            ..lineTo(15, 33)
            ..lineTo(0, 25)
            ..close()
            ..moveTo(0, 7)
            ..lineTo(15, 15)
            ..lineTo(30, 7)
            ..moveTo(15, 15)
            ..lineTo(15, 33)
            ..moveTo(8, 4)
            ..lineTo(23, 11);
          canvas.drawPath(parcel, pen);
        } else if ((row + col) % 3 == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(0, 0, 32, 23),
              const Radius.circular(7),
            ),
            pen,
          );
          canvas.drawPath(
            Path()
              ..moveTo(7, 23)
              ..lineTo(5, 29)
              ..lineTo(14, 23),
            pen,
          );
          canvas.drawLine(const Offset(8, 8), const Offset(24, 8), pen);
          canvas.drawLine(const Offset(8, 14), const Offset(18, 14), pen);
        } else {
          canvas.drawCircle(const Offset(7, 8), 3, pen);
          canvas.drawLine(const Offset(22, 20), const Offset(28, 20), pen);
          canvas.drawLine(const Offset(25, 17), const Offset(25, 23), pen);
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ChatWallpaperPainter oldDelegate) =>
      oldDelegate.color != color;
}
