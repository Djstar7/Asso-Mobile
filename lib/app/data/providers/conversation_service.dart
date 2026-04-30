import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../providers/api_provider.dart';
import '../../core/values/constants.dart';
import '../providers/storage_service.dart';

class ConversationService {
  /// Get user's conversations
  static Future<ApiResponse> getConversations({int page = 1}) async {
    return await ApiProvider.get('${AppConstants.conversationsUrl}?page=$page');
  }

  /// Start or get a conversation with a user
  static Future<ApiResponse> startConversation({
    required int userId,
    int? productId,
    int? diaspoOfferId,
  }) async {
    final data = <String, dynamic>{'user_id': userId};
    if (productId != null) data['product_id'] = productId;
    if (diaspoOfferId != null) data['diaspo_offer_id'] = diaspoOfferId;
    return await ApiProvider.post(AppConstants.startConversationUrl, body: data);
  }

  /// Get messages in a conversation
  static Future<ApiResponse> getMessages(int conversationId, {int page = 1}) async {
    return await ApiProvider.get(
      '${AppConstants.conversationsUrl}/$conversationId/messages?page=$page',
    );
  }

  /// Send a message
  static Future<ApiResponse> sendMessage(
    int conversationId,
    String message, {
    int? productId,
    int? diaspoOfferId,
  }) async {
    final data = <String, dynamic>{'message': message};
    if (productId != null) data['product_id'] = productId;
    if (diaspoOfferId != null) data['diaspo_offer_id'] = diaspoOfferId;

    return await ApiProvider.post(
      '${AppConstants.conversationsUrl}/$conversationId/messages',
      body: data,
    );
  }

  /// Send typing indicator
  static Future<ApiResponse> sendTypingIndicator(
    int conversationId,
    bool isTyping,
  ) async {
    return await ApiProvider.post(
      '${AppConstants.conversationsUrl}/$conversationId/typing',
      body: {'is_typing': isTyping},
    );
  }

  /// Update online status
  static Future<ApiResponse> updateOnlineStatus(bool isOnline) async {
    return await ApiProvider.post(
      '/v1/user/online-status',
      body: {'is_online': isOnline},
    );
  }

  /// Hide a conversation for the current user
  static Future<ApiResponse> hideConversation(int conversationId) async {
    return await ApiProvider.post(
      '${AppConstants.conversationsUrl}/$conversationId/hide',
    );
  }

  /// Send a message with an image
  static Future<ApiResponse> sendMessageWithImage(
    int conversationId, {
    String? message,
    File? imageFile,
    int? productId,
    int? diaspoOfferId,
  }) async {
    try {
      final token = StorageService.getToken();
      if (token == null) {
        return ApiResponse(
          success: false,
          message: 'Non authentifié',
          statusCode: 401,
        );
      }

      final uri = Uri.parse('${AppConstants.baseUrl}${AppConstants.conversationsUrl}/$conversationId/messages');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Ajouter le message texte si fourni
      if (message != null && message.isNotEmpty) {
        request.fields['message'] = message;
      }

      // Ajouter le product_id si fourni
      if (productId != null) {
        request.fields['product_id'] = productId.toString();
      }

      // Ajouter le diaspo_offer_id si fourni
      if (diaspoOfferId != null) {
        request.fields['diaspo_offer_id'] = diaspoOfferId.toString();
      }

      // Ajouter l'image si fournie
      if (imageFile != null) {
        final imageStream = http.ByteStream(imageFile.openRead());
        final imageLength = await imageFile.length();

        final multipartFile = http.MultipartFile(
          'image',
          imageStream,
          imageLength,
          filename: imageFile.path.split('/').last,
          contentType: MediaType('image', 'jpeg'),
        );

        request.files.add(multipartFile);
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final Map<String, dynamic> data = json.decode(response.body);

      // Le backend retourne un objet 'message' qui contient les données du message
      // On doit extraire correctement le message de succès
      String successMessage = '';
      if (data['message'] is String) {
        successMessage = data['message'] as String;
      } else if (data['success'] == true) {
        successMessage = 'Message envoyé avec succès';
      } else {
        successMessage = 'Erreur lors de l\'envoi';
      }

      return ApiResponse(
        success: data['success'] ?? false,
        message: successMessage,
        data: data,
        statusCode: response.statusCode,
      );
    } catch (e) {
      print('Erreur lors de l\'envoi du message avec image: $e');
      return ApiResponse(
        success: false,
        message: 'Erreur lors de l\'envoi: $e',
        statusCode: 500,
      );
    }
  }
}
