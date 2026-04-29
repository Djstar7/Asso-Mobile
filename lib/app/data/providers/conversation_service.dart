import '../providers/api_provider.dart';
import '../../core/values/constants.dart';

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
}
