import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;
import '../../core/values/constants.dart';
import 'storage_service.dart';

class ApiProvider {
  static http.Client _client = http.Client();

  /// Get stored auth token
  static String? get token => StorageService.getToken();

  /// Check if user is authenticated
  static bool get isAuthenticated => StorageService.isAuthenticated;

  /// Get default headers
  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Build full URL from endpoint
  static Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final url = '${AppConstants.baseUrl}$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      final cleanParams = queryParams.map((key, value) => MapEntry(key, value.toString()));
      return Uri.parse(url).replace(queryParameters: cleanParams);
    }
    return Uri.parse(url);
  }

  /// GET request
  static Future<ApiResponse> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    final uri = _buildUri(endpoint, queryParams);
    developer.log(
      'GET ${uri.toString()}',
      name: 'ApiProvider',
      error: 'Headers: ${_headers.keys.join(", ")}',
    );

    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(AppConstants.apiTimeout);

      developer.log(
        'GET Response [${response.statusCode}]',
        name: 'ApiProvider',
        error: 'Endpoint: $endpoint',
      );

      return _handleResponse(response);
    } on SocketException catch (e) {
      developer.log('Network error', name: 'ApiProvider', error: e);
      return ApiResponse(success: false, message: 'Pas de connexion internet', statusCode: 0);
    } on HttpException catch (e) {
      developer.log('HTTP error', name: 'ApiProvider', error: e);
      return ApiResponse(success: false, message: 'Erreur serveur', statusCode: 500);
    } catch (e, stackTrace) {
      developer.log('GET error', name: 'ApiProvider', error: e, stackTrace: stackTrace);
      return ApiResponse(success: false, message: 'Erreur: ${e.toString()}', statusCode: 0);
    }
  }

  /// POST request
  static Future<ApiResponse> post(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = _buildUri(endpoint);
    developer.log(
      'POST ${uri.toString()}',
      name: 'ApiProvider',
      error: 'Body: ${body?.keys.join(", ")}',
    );

    try {
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(AppConstants.apiTimeout);

      developer.log(
        'POST Response [${response.statusCode}]',
        name: 'ApiProvider',
        error: 'Endpoint: $endpoint',
      );

      return _handleResponse(response);
    } on SocketException catch (e) {
      developer.log('Network error', name: 'ApiProvider', error: e);
      return ApiResponse(success: false, message: 'Pas de connexion internet', statusCode: 0);
    } on HttpException catch (e) {
      developer.log('HTTP error', name: 'ApiProvider', error: e);
      return ApiResponse(success: false, message: 'Erreur serveur', statusCode: 500);
    } catch (e, stackTrace) {
      developer.log('POST error', name: 'ApiProvider', error: e, stackTrace: stackTrace);
      return ApiResponse(success: false, message: 'Erreur: ${e.toString()}', statusCode: 0);
    }
  }

  /// PUT request
  static Future<ApiResponse> put(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = _buildUri(endpoint);
    developer.log(
      'PUT ${uri.toString()}',
      name: 'ApiProvider',
      error: 'Body: ${body?.keys.join(", ")}',
    );

    try {
      final response = await _client
          .put(uri, headers: _headers, body: jsonEncode(body ?? {}))
          .timeout(AppConstants.apiTimeout);

      developer.log(
        'PUT Response [${response.statusCode}]',
        name: 'ApiProvider',
        error: 'Endpoint: $endpoint',
      );

      return _handleResponse(response);
    } on SocketException catch (e) {
      developer.log('Network error', name: 'ApiProvider', error: e);
      return ApiResponse(success: false, message: 'Pas de connexion internet', statusCode: 0);
    } catch (e, stackTrace) {
      developer.log('PUT error', name: 'ApiProvider', error: e, stackTrace: stackTrace);
      return ApiResponse(success: false, message: 'Erreur: ${e.toString()}', statusCode: 0);
    }
  }

  /// DELETE request
  static Future<ApiResponse> delete(String endpoint, {Map<String, dynamic>? body}) async {
    final uri = _buildUri(endpoint);
    developer.log(
      'DELETE ${uri.toString()}',
      name: 'ApiProvider',
      error: body != null ? 'With body: ${body.keys.join(", ")}' : 'No body',
    );

    try {
      final response = await _client
          .delete(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConstants.apiTimeout);

      developer.log(
        'DELETE Response [${response.statusCode}]',
        name: 'ApiProvider',
        error: 'Endpoint: $endpoint',
      );

      return _handleResponse(response);
    } catch (e, stackTrace) {
      developer.log('DELETE error', name: 'ApiProvider', error: e, stackTrace: stackTrace);
      return ApiResponse(success: false, message: 'Erreur: ${e.toString()}', statusCode: 0);
    }
  }

  /// Multipart POST (for file uploads)
  ///
  /// [files] : map champ → chemin local (mobile uniquement, ignoré sur le web
  /// car `dart:io File` n'y existe pas).
  /// [mediaFiles] : map champ → [XFile] pour un fichier unique. Compatible web
  /// ET mobile (upload via octets), à privilégier pour tout nouveau code.
  /// [mediaFileLists] : map champ → liste d'[XFile] pour les champs multi-fichiers
  /// (ex. `images[]`). Compatible web ET mobile.
  static Future<ApiResponse> multipart(
    String endpoint, {
    Map<String, String>? fields,
    Map<String, String>? files,
    Map<String, XFile>? mediaFiles,
    Map<String, List<XFile>>? mediaFileLists,
    String method = 'POST',
  }) async {
    final uri = _buildUri(endpoint);
    developer.log(
      'MULTIPART $method ${uri.toString()}',
      name: 'ApiProvider',
      error: 'Fields: ${fields?.keys.join(", ")}, Files: ${files?.keys.join(", ")}',
    );

    try {
      final request = http.MultipartRequest(method, uri);
      request.headers.addAll(_headers..remove('Content-Type'));

      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Fichiers par chemin local — mobile/desktop uniquement (dart:io).
      // Ignoré sur le web : les appelants doivent alors utiliser [mediaFiles].
      if (files != null && !kIsWeb) {
        for (var entry in files.entries) {
          final file = File(entry.value);
          if (await file.exists()) {
            request.files.add(await http.MultipartFile.fromPath(entry.key, entry.value));
          } else {
            developer.log(
              'File not found: ${entry.value}',
              name: 'ApiProvider',
              error: 'Skipping missing file',
            );
          }
        }
      }

      // Fichiers XFile — via octets, compatibles web ET mobile.
      if (mediaFiles != null) {
        for (var entry in mediaFiles.entries) {
          request.files.add(await _multipartFromXFile(entry.key, entry.value));
        }
      }

      // Champs multi-fichiers (ex. images[]) — via octets, web ET mobile.
      if (mediaFileLists != null) {
        for (var entry in mediaFileLists.entries) {
          for (final xfile in entry.value) {
            request.files.add(await _multipartFromXFile(entry.key, xfile));
          }
        }
      }

      final streamedResponse = await request.send().timeout(AppConstants.apiTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      developer.log(
        'MULTIPART Response [${response.statusCode}]',
        name: 'ApiProvider',
        error: 'Endpoint: $endpoint',
      );

      return _handleResponse(response);
    } catch (e, stackTrace) {
      developer.log('MULTIPART error', name: 'ApiProvider', error: e, stackTrace: stackTrace);
      return ApiResponse(success: false, message: 'Erreur: ${e.toString()}', statusCode: 0);
    }
  }

  /// Construit un [http.MultipartFile] à partir d'un [XFile] via ses octets.
  /// Fonctionne sur le web (URL blob) comme sur mobile (fichier local).
  static Future<http.MultipartFile> _multipartFromXFile(
    String field,
    XFile xfile,
  ) async {
    final bytes = await xfile.readAsBytes();
    final filename = xfile.name.isNotEmpty
        ? xfile.name
        : 'upload_${DateTime.now().millisecondsSinceEpoch}';
    return http.MultipartFile.fromBytes(field, bytes, filename: filename);
  }

  /// Handle response
  static ApiResponse _handleResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      final success = body['success'] == true && response.statusCode >= 200 && response.statusCode < 300;

      // Extract message - can be either String or Map
      final messageField = body['message'];
      final messageString = messageField is String
          ? messageField
          : (success ? 'Succès' : 'Erreur');

      developer.log(
        'Response parsed',
        name: 'ApiProvider',
        error: 'Success: $success, Status: ${response.statusCode}, Message: $messageString',
      );

      // Handle 401 - Unauthorized (token expired)
      if (response.statusCode == 401) {
        developer.log(
          '⚠️ 401 Unauthorized - Session expired',
          name: 'ApiProvider',
        );
        _handleUnauthorized();
        return ApiResponse(
          success: false,
          message: 'Session expirée. Veuillez vous reconnecter.',
          statusCode: 401,
          data: body,
        );
      }

      return ApiResponse(
        success: success,
        message: messageString,
        statusCode: response.statusCode,
        data: body,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Response parsing error',
        name: 'ApiProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return ApiResponse(
        success: false,
        message: 'Erreur de parsing: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Handle unauthorized - clear session and redirect to login
  static void _handleUnauthorized() {
    // En mode vitrine/invité l'utilisateur n'est pas connecté : un 401 sur un
    // endpoint protégé est attendu et ne doit PAS le rediriger vers le login.
    if (StorageService.isGuestMode || !StorageService.isAuthenticated) {
      developer.log(
        'Guest/unauthenticated user - ignoring 401 (no redirect)',
        name: 'ApiProvider',
      );
      return;
    }

    developer.log('Clearing session and redirecting to login', name: 'ApiProvider');
    StorageService.clearAuth();
    // Navigate to login
    Get.offAllNamed('/login');
  }

  /// Save auth data after login (deprecated - use StorageService instead)
  @Deprecated('Use StorageService.saveAuthSession instead')
  static void saveAuth(String authToken, Map<String, dynamic> userData) {
    developer.log('saveAuth called (deprecated)', name: 'ApiProvider');
    StorageService.saveToken(authToken);
  }

  /// Get cached user data (deprecated - use StorageService instead)
  @Deprecated('Use StorageService.getUser instead')
  static Map<String, dynamic>? get cachedUser {
    final user = StorageService.getUser();
    return user?.toJson();
  }

  /// Clear all auth data (deprecated - use StorageService instead)
  @Deprecated('Use StorageService.clearAuth instead')
  static void clearAuth() {
    developer.log('clearAuth called (deprecated)', name: 'ApiProvider');
    StorageService.clearAuth();
  }
}

/// API Response wrapper
class ApiResponse {
  final bool success;
  final String message;
  final int statusCode;
  final Map<String, dynamic>? data;

  ApiResponse({
    required this.success,
    required this.message,
    required this.statusCode,
    this.data,
  });
}
