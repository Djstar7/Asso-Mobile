import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Délai de livraison annoncé, en jours ouvrables (lundi → vendredi).
///
/// Le serveur le résout (produit → catégorie → défaut ASSO) et l'envoie en
/// `delivery_delay: {min, max}` ; la commande fige en plus une fourchette de
/// dates (`estimated_delivery_from` / `estimated_delivery_to`).
class DeliveryDelay {
  const DeliveryDelay(this.min, this.max);

  final int min;
  final int max;

  static DeliveryDelay? fromApi(dynamic raw) {
    if (raw is! Map) return null;
    final min = int.tryParse('${raw['min'] ?? ''}');
    final max = int.tryParse('${raw['max'] ?? ''}');
    if (min == null && max == null) return null;
    return DeliveryDelay(min ?? max!, max ?? min!);
  }

  /// « 3 à 7 jours ouvrables », ou « 5 jours ouvrables » si min = max.
  String get label {
    if (min == max) {
      return (max > 1
              ? 'product.delivery_delay.days'
              : 'product.delivery_delay.day')
          .trParams({'count': '$max'});
    }
    return 'product.delivery_delay.range'.trParams({
      'min': '$min',
      'max': '$max',
    });
  }

  /// « entre le 16 oct. et le 23 oct. », depuis les dates figées sur la commande.
  static String? estimatedLabel(String? from, String? to) {
    final start = DateTime.tryParse(from ?? '');
    final end = DateTime.tryParse(to ?? '');
    if (start == null || end == null) return null;
    final fmt = DateFormat('d MMM', Get.locale?.toLanguageTag());
    if (start == end) {
      return 'product.delivery_delay.estimated_on'.trParams({
        'date': fmt.format(start),
      });
    }
    return 'product.delivery_delay.estimated_between'.trParams({
      'from': fmt.format(start),
      'to': fmt.format(end),
    });
  }
}
