import '../models/real_estate_models.dart';
import 'api_provider.dart';

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
    final meta = Map<String, dynamic>.from(res.data!['meta'] as Map? ?? const {});

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

    return RealEstateListing.fromJson(Map<String, dynamic>.from(res.data!['data']));
  }

  static Future<RealEstateQuote?> quote(int id, {int? unitId, int? advanceMonths}) async {
    final res = await ApiProvider.get('$_base/listings/$id/quote', queryParams: {
      if (unitId != null) 'unit_id': unitId,
      if (advanceMonths != null) 'advance_months': advanceMonths,
    });
    if (!res.success || res.data?['data'] is! Map) return null;

    return RealEstateQuote.fromJson(Map<String, dynamic>.from(res.data!['data']));
  }

  static Future<RealEstateCabinet?> cabinet(int id) async {
    final res = await ApiProvider.get('$_base/cabinets/$id');
    if (!res.success || res.data?['data'] is! Map) return null;

    return RealEstateCabinet.fromJson(Map<String, dynamic>.from(res.data!['data']));
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

    return data is Map ? RealEstateCriteria.fromJson(Map<String, dynamic>.from(data)) : null;
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
}
