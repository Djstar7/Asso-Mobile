import 'package:image_picker/image_picker.dart';

import '../../core/values/constants.dart';
import 'api_provider.dart';

/// Réclamations / litiges : fenêtre de contrôle de 48 h après la livraison,
/// réclamation par article, remplacement ou retour, course payée par le vendeur.
class DisputeService {
  static const String _clientUrl = '/v1/disputes';
  static const String _vendorUrl = '/v1/vendor/disputes';

  // ── Client ──────────────────────────────────────────────────────────────

  /// « Tout est conforme » : la commande est validée, le vendeur payé.
  static Future<ApiResponse> confirmConformity(int orderId) {
    return ApiProvider.post('${AppConstants.ordersUrl}/$orderId/conform', body: {});
  }

  /// Réclamation sur un article (motif, explication, photos).
  static Future<ApiResponse> open({
    required int orderId,
    required int orderItemId,
    required String reason,
    required String description,
    List<XFile> photos = const [],
  }) {
    return ApiProvider.multipart(
      '${AppConstants.ordersUrl}/$orderId/disputes',
      fields: {
        'order_item_id': '$orderItemId',
        'reason': reason,
        'description': description,
      },
      mediaFileLists: photos.isEmpty ? null : {'photos[]': photos},
    );
  }

  static Future<ApiResponse> clientDisputes() => ApiProvider.get(_clientUrl);

  static Future<ApiResponse> clientDispute(int id) => ApiProvider.get('$_clientUrl/$id');

  static Future<ApiResponse> confirmReplacement(int id) {
    return ApiProvider.post('$_clientUrl/$id/confirm-replacement', body: {});
  }

  /// Remplacement encore non conforme : le retour avec remboursement est imposé.
  static Future<ApiResponse> reportReplacement(int id, {required String description, List<XFile> photos = const []}) {
    return ApiProvider.multipart(
      '$_clientUrl/$id/report-replacement',
      fields: {'description': description},
      mediaFileLists: photos.isEmpty ? null : {'photos[]': photos},
    );
  }

  /// Après remboursement : produits similaires dont le vendeur offre la livraison.
  static Future<ApiResponse> similarProducts(int id) {
    return ApiProvider.get('$_clientUrl/$id/similar-products');
  }

  // ── Vendeur ─────────────────────────────────────────────────────────────

  static Future<ApiResponse> vendorDisputes({String? status}) {
    return ApiProvider.get(_vendorUrl, queryParams: {'status': ?status});
  }

  static Future<ApiResponse> vendorDispute(int id) => ApiProvider.get('$_vendorUrl/$id');

  static Future<ApiResponse> sendEvidence(int id, {String? note, List<XFile> files = const []}) {
    return ApiProvider.multipart(
      '$_vendorUrl/$id/evidence',
      fields: {'note': ?note},
      mediaFileLists: files.isEmpty ? null : {'files[]': files},
    );
  }

  static Future<ApiResponse> replace(int id) => ApiProvider.post('$_vendorUrl/$id/replace', body: {});

  static Future<ApiResponse> organizeReturn(int id) => ApiProvider.post('$_vendorUrl/$id/return', body: {});

  static Future<ApiResponse> shipmentPartners(int shipmentId) {
    return ApiProvider.get('$_vendorUrl/shipments/$shipmentId/partners');
  }

  static Future<ApiResponse> choosePartner(int shipmentId, Map<String, dynamic> partner) {
    return ApiProvider.post('$_vendorUrl/shipments/$shipmentId/partner', body: {
      'company_id': partner['company_id'],
      'zone_id': ?partner['zone_id'],
      'route_id': ?partner['route_id'],
      'grid_id': ?partner['grid_id'],
      'vehicle': ?partner['vehicle'],
    });
  }

  static Future<ApiResponse> payShipment(int shipmentId, {required String paymentMode, String? provider, String? phone}) {
    return ApiProvider.post('$_vendorUrl/shipments/$shipmentId/pay', body: {
      'payment_mode': paymentMode,
      'provider': ?provider,
      'phone_number': ?phone,
    });
  }

  static Future<ApiResponse> shipmentPaymentStatus(int shipmentId) {
    return ApiProvider.get('$_vendorUrl/shipments/$shipmentId/payment-status');
  }

  /// Le vendeur remet le remplacement au livreur, ou confirme la réception du retour.
  static Future<ApiResponse> shipmentStep(int shipmentId, String step, {String? trackingNumber}) {
    return ApiProvider.post('$_vendorUrl/shipments/$shipmentId/step', body: {
      'step': step,
      'carrier_tracking_number': ?trackingNumber,
    });
  }
}
