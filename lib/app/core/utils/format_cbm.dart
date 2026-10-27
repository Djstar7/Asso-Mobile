import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Volume sans séparateur de milliers ni décimales inutiles : 1 CBM,
/// 10 CBM, ou 0,123 CBM en français. La précision métier reste au millième.
String formatCbm(num volume) =>
    NumberFormat('0.###', Get.locale?.toLanguageTag() ?? 'fr').format(volume);
