import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/services/locale_service.dart';
import '../../core/utils/session_scope.dart';
import '../../core/values/constants.dart';
import 'storage_service.dart';

/// Attach a credential only to the configured API origin, without redirects.
class AuthenticatedDownload {
  AuthenticatedDownload._();

  static bool isAllowed(Uri uri) {
    final api = Uri.parse(AppConstants.baseUrl);
    return (uri.scheme == 'https' || (kDebugMode && uri.scheme == 'http')) &&
        uri.scheme == api.scheme &&
        uri.host == api.host &&
        uri.port == api.port &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment;
  }

  static Future<http.Response?> get(Uri uri, {required String accept}) async {
    final token = StorageService.getToken();
    if (!isAllowed(uri) || token == null || token.isEmpty) return null;
    final session = SessionScope.current;
    final client = http.Client();
    try {
      final request = http.Request('GET', uri)
        ..followRedirects = false
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Accept': accept,
          'Accept-Language': LocaleService.currentLanguage,
        });
      final response = await (() async {
        final streamed = await client.send(request);
        if (streamed.statusCode != 200) return null;
        final bytes = <int>[];
        await for (final chunk in streamed.stream) {
          if (bytes.length + chunk.length > 20 * 1024 * 1024) return null;
          bytes.addAll(chunk);
        }
        return http.Response.bytes(bytes, 200, headers: streamed.headers);
      })().timeout(AppConstants.apiTimeout);
      return SessionScope.isCurrent(session) ? response : null;
    } finally {
      client.close();
    }
  }
}
