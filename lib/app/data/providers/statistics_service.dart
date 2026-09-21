import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/values/constants.dart';
import 'api_provider.dart';
import 'storage_service.dart';

/// Statistiques boutiques (P8).
///
/// - [track] : signale une interaction acheteur (consultation d'un produit,
///   prise de contact). La visite d'une boutique est comptée côté serveur à
///   l'ouverture de sa page publique. Appel « fire and forget » : un échec ne
///   doit jamais gêner l'acheteur.
/// - [getVendorStatistics] : tableau de bord du vendeur sur une période.
class StatisticsService {
  static const String trackUrl = '/v1/analytics/track';
  static const String vendorStatisticsUrl = '/v1/vendor/statistics';

  static const String productView = 'product_view';
  static const String contact = 'contact';

  static Future<void> track(
    String event, {
    int? productId,
    int? shopId,
  }) async {
    if (productId == null && shopId == null) return;
    try {
      await ApiProvider.post(trackUrl, body: {
        'event': event,
        if (productId != null) 'product_id': productId,
        if (shopId != null) 'shop_id': shopId,
      });
    } catch (_) {
      // Statistique perdue : sans incidence pour l'utilisateur.
    }
  }

  static void trackProductView(dynamic productId) {
    final id = int.tryParse(productId?.toString() ?? '');
    if (id != null) track(productView, productId: id);
  }

  static void trackContact({dynamic productId, dynamic shopId}) {
    track(
      contact,
      productId: int.tryParse(productId?.toString() ?? ''),
      shopId: int.tryParse(shopId?.toString() ?? ''),
    );
  }

  /// [period] : 7d | 30d | 90d | 365d | all
  static Future<ApiResponse> getVendorStatistics({String period = '30d'}) {
    return ApiProvider.get(vendorStatisticsUrl, queryParams: {'period': period});
  }

  /// Télécharge le rapport de la période et renvoie le fichier local.
  ///
  /// [format] : `csv` (tableur) ou `pdf` (document présentable). Le rapport
  /// reprend les chiffres de l'écran, pour que le vendeur retrouve ce qu'il
  /// vient de consulter.
  static Future<File?> downloadReport({
    required String period,
    required String format,
  }) async {
    final token = StorageService.getToken();
    final uri = Uri.parse('${AppConstants.baseUrl}$vendorStatisticsUrl/export')
        .replace(queryParameters: {'period': period, 'format': format});

    final response = await http.get(uri, headers: {
      'Accept': format == 'pdf' ? 'application/pdf' : 'text/csv',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    });

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;

    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/statistiques-$stamp.$format');
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }
}
