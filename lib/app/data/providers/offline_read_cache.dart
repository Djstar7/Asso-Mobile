import 'offline_store.dart';
import '../../core/values/constants.dart';
import '../../core/utils/session_scope.dart';

/// Deliberately limited to account-owned read models, never payment decisions.
class OfflineReadCache {
  OfflineReadCache._();
  static bool supports(Uri uri) => {
    '${Uri.parse(AppConstants.baseUrl).path}/v1/vendor/products',
    '${Uri.parse(AppConstants.baseUrl).path}/v1/wallet',
    '${Uri.parse(AppConstants.baseUrl).path}/v1/wallet/transactions',
    '${Uri.parse(AppConstants.baseUrl).path}/v1/wallet/withdrawal-balances',
    '${Uri.parse(AppConstants.baseUrl).path}/v1/wallet/payout-account',
  }.contains(uri.path);

  static String key(Uri uri) {
    final keys = uri.queryParameters.keys.toList()..sort();
    final canonical = uri.replace(
      queryParameters: {for (final key in keys) key: uri.queryParameters[key]!},
    );
    return 'api:$canonical';
  }

  static Future<void> save(Uri uri, Map<String, dynamic> data) async {
    if (!supports(uri)) return;
    final session = SessionScope.current;
    if (uri.path.endsWith('/vendor/products') &&
        !uri.queryParameters.containsKey('search') &&
        !uri.queryParameters.containsKey('status') &&
        data['data'] is List) {
      final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
      final previous = OfflineStore.readSnapshot('vendor_product_list');
      final products = <String, dynamic>{};
      if (page > 1 && previous is Map && previous['products'] is List) {
        for (final product in previous['products']) {
          if (product is Map) products['${product['id']}'] = product;
        }
      }
      for (final product in data['data']) {
        if (product is Map) products['${product['id']}'] = product;
      }
      await OfflineStore.saveSnapshot('vendor_product_list', {
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'products': products.values.take(200).toList(),
      });
    }
    if (!SessionScope.isCurrent(session)) return;
    await OfflineStore.saveSnapshot(key(uri), {
      'saved_at': DateTime.now().toUtc().toIso8601String(),
      'response': data,
    });
  }

  static Map<String, dynamic>? read(Uri uri) {
    if (!supports(uri)) return null;
    final snapshot = OfflineStore.readSnapshot(key(uri));
    if (snapshot is! Map || snapshot['response'] is! Map) return null;
    return {
      ...Map<String, dynamic>.from(snapshot['response']),
      '_offline': true,
      '_saved_at': snapshot['saved_at'],
    };
  }
}
