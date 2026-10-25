import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/values/constants.dart';
import '../models/real_estate_models.dart';
import 'api_provider.dart';
import 'authenticated_download.dart';
import 'private_exports.dart';
import '../../core/utils/session_scope.dart';
import 'package:flutter/foundation.dart';

/// Rubrique Immobilier : listes, fiches, cabinets, favoris, critères,
/// « Confier mon projet » et conversation avec ASSO.
class RealEstateService {
  static const String _base = '/v1/real-estate';

  static Future<RealEstatePage?> listings(Map<String, dynamic> query) async {
    final res = await ApiProvider.get('$_base/listings', queryParams: query);
    if (!res.success || res.data == null) return null;

    final data = (res.data!['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => RealEstateListing.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final meta = Map<String, dynamic>.from(
      res.data!['meta'] as Map? ?? const {},
    );

    return RealEstatePage(
      items: data,
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? data.length,
    );
  }

  static Future<RealEstateListing?> listing(int id) async {
    final res = await ApiProvider.get('$_base/listings/$id');
    if (!res.success || res.data?['data'] is! Map) return null;

    return RealEstateListing.fromJson(
      Map<String, dynamic>.from(res.data!['data']),
    );
  }

  static Future<RealEstateQuote?> quote(
    int id, {
    int? unitId,
    int? advanceMonths,
  }) async {
    final res = await ApiProvider.get(
      '$_base/listings/$id/quote',
      queryParams: {
        if (unitId != null) 'unit_id': unitId,
        if (advanceMonths != null) 'advance_months': advanceMonths,
      },
    );
    if (!res.success || res.data?['data'] is! Map) return null;

    return RealEstateQuote.fromJson(
      Map<String, dynamic>.from(res.data!['data']),
    );
  }

  static Future<RealEstateCabinet?> cabinet(int id) async {
    final res = await ApiProvider.get('$_base/cabinets/$id');
    if (!res.success || res.data?['data'] is! Map) return null;

    return RealEstateCabinet.fromJson(
      Map<String, dynamic>.from(res.data!['data']),
    );
  }

  static Future<List<String>> cities() async {
    final res = await ApiProvider.get('$_base/meta');
    final list = (res.data?['data'] as Map?)?['cities'];

    return list is List ? list.map((e) => e.toString()).toList() : const [];
  }

  static Future<List<RealEstateListing>> favorites() async {
    final res = await ApiProvider.get('$_base/favorites');
    if (!res.success) return const [];

    return (res.data?['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => RealEstateListing.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<bool> setFavorite(int id, bool favorite) async {
    final res = favorite
        ? await ApiProvider.post('$_base/listings/$id/favorite')
        : await ApiProvider.delete('$_base/listings/$id/favorite');

    return res.success;
  }

  static Future<RealEstateCriteria?> criteria() async {
    final res = await ApiProvider.get('$_base/alert');
    final data = res.data?['data'];

    return data is Map
        ? RealEstateCriteria.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  static Future<bool> saveCriteria(RealEstateCriteria criteria) async {
    final res = await ApiProvider.put('$_base/alert', body: criteria.toJson());

    return res.success;
  }

  static Future<ApiResponse> sendProjectRequest(Map<String, dynamic> body) {
    return ApiProvider.post('$_base/project-requests', body: body);
  }

  /// Ouvre (ou reprend) la conversation avec ASSO au sujet d'une annonce.
  static Future<ApiResponse> contact(int listingId) {
    return ApiProvider.post('$_base/listings/$listingId/contact');
  }

  // ── Espace bailleur ─────────────────────────────────────────────────────

  static const String _landlord = '$_base/landlord';
  static const String _statusKey = 'landlord_verification_status';

  /// Dernier statut connu, pour le libellé du menu sans attendre le réseau.
  static String get cachedLandlordStatus =>
      GetStorage().read<String>(_statusKey) ?? 'none';

  static Future<LandlordStatus?> landlordStatus() async {
    final res = await ApiProvider.get('$_landlord/verification');
    if (!res.success || res.data?['data'] is! Map) return null;
    final status = LandlordStatus.fromJson(
      Map<String, dynamic>.from(res.data!['data']),
    );
    GetStorage().write(_statusKey, status.status);

    return status;
  }

  static Future<ApiResponse> submitVerification({
    required String idType,
    required XFile idFront,
    XFile? idBack,
    required String proofType,
    required XFile proof,
    required XFile video,
  }) async {
    final res = await ApiProvider.multipart(
      '$_landlord/verification',
      fields: {'id_document_type': idType, 'ownership_proof_type': proofType},
      mediaFiles: {
        'id_front': idFront,
        if (idBack != null) 'id_back': idBack,
        'ownership_proof': proof,
        'video': video,
      },
    );
    if (res.success) GetStorage().write(_statusKey, 'pending');

    return res;
  }

  static Future<List<RealEstateListing>> myListings() async {
    final res = await ApiProvider.get('$_landlord/listings');
    if (!res.success) return const [];

    return (res.data?['data'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => RealEstateListing.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<Map<String, dynamic>?> myListing(int id) async {
    final res = await ApiProvider.get('$_landlord/listings/$id');
    final data = res.data?['data'];

    return res.success && data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// Crée ([id] nul) ou modifie une annonce ; renvoie la réponse complète.
  static Future<ApiResponse> saveListing(int? id, Map<String, dynamic> body) {
    return id == null
        ? ApiProvider.post('$_landlord/listings', body: body)
        : ApiProvider.put('$_landlord/listings/$id', body: body);
  }

  static Future<ApiResponse> submitListing(int id) =>
      ApiProvider.post('$_landlord/listings/$id/submit');

  static Future<ApiResponse> deleteListing(int id) =>
      ApiProvider.delete('$_landlord/listings/$id');

  static Future<ApiResponse> uploadMedia(
    int id,
    XFile file, {
    int? roomId,
    bool cover = false,
  }) {
    return ApiProvider.multipart(
      '$_landlord/listings/$id/media',
      fields: {
        if (roomId != null) 'room_id': '$roomId',
        if (cover) 'is_cover': '1',
      },
      mediaFiles: {'file': file},
    );
  }

  static Future<ApiResponse> deleteMedia(int id, int mediaId) =>
      ApiProvider.delete('$_landlord/listings/$id/media/$mediaId');

  static Future<Map<String, dynamic>?> pricePreview(
    int netPrice,
    int? advanceMonths,
  ) async {
    final res = await ApiProvider.post(
      '$_landlord/price-preview',
      body: {
        'net_price': netPrice,
        if (advanceMonths != null) 'advance_months': advanceMonths,
      },
    );
    final data = res.data?['data'];

    return res.success && data is Map ? Map<String, dynamic>.from(data) : null;
  }

  static Future<List<RealEstateAmenity>> amenities() async {
    final res = await ApiProvider.get('$_base/meta');
    final list = (res.data?['data'] as Map?)?['amenities'];

    return list is List
        ? list
              .whereType<Map>()
              .map(
                (e) => RealEstateAmenity.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList()
        : const [];
  }

  // ── Réservations ────────────────────────────────────────────────────────

  static RealEstateReservation? _reservation(ApiResponse res) {
    final data = res.data?['data'];

    return res.success && data is Map
        ? RealEstateReservation.fromJson(Map<String, dynamic>.from(data))
        : null;
  }

  static List<RealEstateReservation> _reservations(ApiResponse res) =>
      res.success
      ? (res.data?['data'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (e) =>
                  RealEstateReservation.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
      : const [];

  static Future<ApiResponse> reserve(
    int listingId,
    Map<String, dynamic> body,
  ) => ApiProvider.post('$_base/listings/$listingId/reservations', body: body);

  static Future<List<RealEstateReservation>> reservations() async =>
      _reservations(await ApiProvider.get('$_base/reservations'));

  static Future<List<RealEstateReservation>> receivedReservations() async =>
      _reservations(await ApiProvider.get('$_base/landlord/reservations'));

  static Future<RealEstateReservation?> reservation(int id) async =>
      _reservation(await ApiProvider.get('$_base/reservations/$id'));

  static Future<RealEstateReservation?> reservationPaymentStatus(
    int id,
  ) async => _reservation(
    await ApiProvider.get('$_base/reservations/$id/payment-status'),
  );

  static Future<ApiResponse> confirmReservation(int id) =>
      ApiProvider.post('$_base/reservations/$id/confirm');

  static Future<List<RealEstateDisputeReason>> disputeReasons(
    String kind,
  ) async {
    final res = await ApiProvider.get(
      '$_base/dispute-reasons',
      queryParams: {'kind': kind},
    );
    final list = res.data?['data'];

    return res.success && list is List
        ? list
              .whereType<Map>()
              .map(
                (e) => RealEstateDisputeReason.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : const [];
  }

  static Future<ApiResponse> openDispute(
    int reservationId, {
    required int reasonId,
    required String description,
    List<XFile> photos = const [],
  }) => ApiProvider.multipart(
    '$_base/reservations/$reservationId/dispute',
    fields: {'reason_id': '$reasonId', 'description': description},
    mediaFileLists: photos.isEmpty ? null : {'photos[]': photos},
  );

  /// Nouvelles pièces du locataire, ou réponse du bailleur.
  static Future<ApiResponse> addDisputeEvidence(
    int reservationId, {
    String? message,
    List<XFile> photos = const [],
  }) => ApiProvider.multipart(
    '$_base/reservations/$reservationId/dispute/evidence',
    fields: {if (message != null && message.isNotEmpty) 'message': message},
    mediaFileLists: photos.isEmpty ? null : {'photos[]': photos},
  );

  /// PDF authentifié en mémoire, téléchargeable sur le web et partageable sur mobile.
  static Future<XFile?> downloadDocument(
    RealEstateReservation r,
    String kind,
  ) async {
    final session = SessionScope.current;
    final response = await AuthenticatedDownload.get(
      Uri.parse(
        '${AppConstants.baseUrl}$_base/reservations/${r.id}/documents/$kind',
      ),
      accept: 'application/pdf',
    );
    if (response == null || response.bodyBytes.isEmpty) return null;
    if (!kIsWeb) {
      final file = await PrivateExports.write(
        '${r.reference}-$kind.pdf',
        response.bodyBytes,
        session,
      );
      return file == null
          ? null
          : XFile(file.path, mimeType: 'application/pdf');
    }
    return XFile.fromData(
      response.bodyBytes,
      mimeType: 'application/pdf',
      name: '${r.reference}-$kind.pdf',
    );
  }
}
