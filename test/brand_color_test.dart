@Tags(['lint'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : une seule couleur primaire dans l'interface.
///
/// L'application avait accumulé plusieurs oranges concurrents (#FF7900,
/// #F59E0B…) écrits en dur, qui donnaient l'impression de deux marques. Ce
/// test relit les sources et signale tout nouvel orange saturé hors des
/// exceptions listées.
void main() {
  /// Fichiers où un orange en dur est légitime, avec sa raison.
  const allowed = <String, String>{
    'lib/app/core/utils/app_design.dart': 'définit les tokens de marque',
    'lib/app/core/utils/app_theme_system.dart':
        'couleur identité du prestataire de paiement KPay',
    'lib/app/core/widgets/product_variant_selector.dart':
        'pastilles de couleur produit : un article « orange » doit être orange',
    'lib/app/modules/product/views/map_selection_view.dart':
        'couleurs de zones logistiques, alignées sur l\'admin',
    'lib/app/modules/wallet/views/wallet_view.dart':
        'puce dorée de la carte bancaire dessinée',
    'lib/app/modules/wallet/widgets/recharge_bottom_sheet.dart':
        'couleur identité KPay, en regard du bleu PayPal',
    'lib/app/modules/certificationPackages/views/certification_packages_view.dart':
        'métaux des paliers (bronze, argent, or)',
  };

  test('aucun orange en dur hors des exceptions déclarées', () {
    final offenders = <String>[];
    final pattern = RegExp(r'0x(?:[Ff][Ff])?([0-9A-Fa-f]{6})\b');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (allowed.containsKey(entity.path)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final match in pattern.allMatches(lines[i])) {
          if (_isBrandOrange(match.group(1)!)) {
            offenders.add('${entity.path}:${i + 1}  #${match.group(1)}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Utilisez AppDesign.accent (ou un token sémantique) plutôt qu\'un '
          'orange en dur :\n${offenders.join('\n')}',
    );
  });
}

/// Vrai pour un orange/ambre saturé, celui qui entre en concurrence avec
/// l'accent de marque.
bool _isBrandOrange(String hex) {
  final r = int.parse(hex.substring(0, 2), radix: 16) / 255;
  final g = int.parse(hex.substring(2, 4), radix: 16) / 255;
  final b = int.parse(hex.substring(4, 6), radix: 16) / 255;

  final max = [r, g, b].reduce((a, b) => a > b ? a : b);
  final min = [r, g, b].reduce((a, b) => a < b ? a : b);
  final delta = max - min;
  if (delta == 0 || max < 0.45) return false;

  final saturation = delta / max;
  if (saturation < 0.45) return false;

  var hue = 0.0;
  if (max == r) {
    hue = ((g - b) / delta) % 6;
  } else if (max == g) {
    hue = (b - r) / delta + 2;
  } else {
    hue = (r - g) / delta + 4;
  }
  hue *= 60;
  if (hue < 0) hue += 360;

  // Bande orange/ambre : du rouge-orangé au jaune d'or.
  return hue >= 8 && hue <= 47;
}
