import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/providers/storage_service.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../core/utils/string_utils.dart';

class ChatController extends GetxController {
  final RxList<Map<String, dynamic>> conversations = <Map<String, dynamic>>[].obs;
  final RxString searchQuery = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;
  int _currentPage = 1;

  @override
  void onInit() {
    super.onInit();
    // Charger les conversations uniquement si l'utilisateur est connecté
    if (StorageService.isAuthenticated) {
      _loadConversations();
    } else {
      // Mode invité - ne pas charger
      isLoading.value = false;
    }
  }


  Future<void> _loadConversations({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      hasMore.value = true;
    }

    isLoading.value = true;

    try {
      final response = await ConversationService.getConversations(page: _currentPage);

      if (response.success && response.data != null) {
        final convList = response.data!['conversations'] as List? ??
            response.data!['data'] as List? ??
            [];

        final converted = convList.map((c) {
          final conv = Map<String, dynamic>.from(c);

          // Gérer le dernier message (peut être un String ou un Map)
          String lastMessageText = '';
          final lastMsg = conv['last_message'];

          if (lastMsg is Map) {
            // Le backend retourne un objet message complet
            final msgText = lastMsg['message'];
            final hasImage = lastMsg['image_path'] != null;

            if (msgText != null && msgText.toString().isNotEmpty) {
              lastMessageText = msgText.toString();
            } else if (hasImage) {
              lastMessageText = '📷 Image';
            } else {
              lastMessageText = '';
            }
          } else if (lastMsg is String) {
            lastMessageText = lastMsg;
          }

          return <String, dynamic>{
            'id': conv['id']?.toString() ?? '',
            'name': conv['other_user']?['name'] ?? conv['name'] ?? 'Utilisateur',
            'avatar': StringUtils.getInitials(conv['other_user']?['name'] ?? conv['name'] ?? ''),
            'lastMessage': lastMessageText,
            'timestamp': _formatTimestamp(conv['updated_at'] ?? conv['last_message_at']),
            'unreadCount': conv['unread_count'] ?? 0,
            'isOnline': conv['other_user']?['is_online'] ?? false,
            'productImage': conv['product']?['image'] ?? conv['product_image'],
            'userId': conv['other_user']?['id'] ?? conv['user_id'],
            'productId': conv['product']?['id'] ?? conv['product_id'],
          };
        }).toList();

        if (refresh || _currentPage == 1) {
          conversations.value = converted;
        } else {
          conversations.addAll(converted);
        }

        final pagination = response.data!['pagination'] as Map<String, dynamic>?;
        hasMore.value = pagination?['has_more'] ?? false;
      } else {
        // No fallback - just keep empty if no data
        if (refresh || _currentPage == 1) {
          conversations.value = [];
        }
      }
    } catch (e) {
      // No fallback - just keep empty on error
      if (refresh || _currentPage == 1) {
        conversations.value = [];
      }
    } finally {
      isLoading.value = false;
    }
  }

  String _formatTimestamp(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}min';
      if (diff.inHours < 24) return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      if (diff.inDays == 1) return 'Hier';
      if (diff.inDays < 7) {
        const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
        return days[date.weekday - 1];
      }
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  List<Map<String, dynamic>> get filteredConversations {
    if (searchQuery.value.isEmpty) {
      return conversations;
    }
    return conversations
        .where((conv) => conv['name']
            .toString()
            .toLowerCase()
            .contains(searchQuery.value.toLowerCase()))
        .toList();
  }

  void openConversation(Map<String, dynamic> conversation) {
    Get.toNamed('/chatdetail', arguments: conversation);
  }

  /// Start a new conversation with a user (optionally about a product)
  Future<void> startConversation({required int userId, int? productId}) async {
    try {
      isLoading.value = true;
      final response = await ConversationService.startConversation(
        userId: userId,
        productId: productId,
      );

      if (response.success && response.data != null) {
        final conv = response.data!['conversation'] ?? response.data!;
        final otherUser = conv['other_user'];
        final userName = otherUser?['name'] ?? 'Utilisateur';

        Get.toNamed('/chatdetail', arguments: {
          'id': conv['id']?.toString(),
          'name': userName,
          'avatar': StringUtils.getInitials(userName),
          'userId': userId,
          'productId': productId,
          'isOnline': false, // On ne connaît pas le statut au démarrage
        });
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de démarrer la conversation');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshConversations() async {
    await _loadConversations(refresh: true);
  }

  /// Supprimer (cacher) une conversation
  Future<void> deleteConversation(Map<String, dynamic> conversation) async {
    try {
      final conversationId = int.tryParse(conversation['id']?.toString() ?? '');

      if (conversationId == null) {
        Get.snackbar(
          'Erreur',
          'Impossible de supprimer la conversation',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Retirer immédiatement de la liste (UI optimiste)
      conversations.removeWhere((c) => c['id'] == conversation['id']);

      // Appeler l'API pour cacher la conversation
      final response = await ConversationService.hideConversation(conversationId);

      if (response.success) {
        Get.snackbar(
          'Succès',
          'Conversation supprimée',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppThemeSystem.primaryColor,
          colorText: Colors.white,
          duration: Duration(seconds: 2),
        );
      } else {
        // En cas d'échec, recharger la liste
        Get.snackbar(
          'Erreur',
          'Impossible de supprimer la conversation',
          snackPosition: SnackPosition.BOTTOM,
        );
        await _loadConversations(refresh: true);
      }
    } catch (e) {
      Get.snackbar(
        'Erreur',
        'Une erreur est survenue',
        snackPosition: SnackPosition.BOTTOM,
      );
      // Recharger la liste en cas d'erreur
      await _loadConversations(refresh: true);
    }
  }
}
