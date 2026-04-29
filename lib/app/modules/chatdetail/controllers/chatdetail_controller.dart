import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/providers/conversation_service.dart';
import '../../../data/services/websocket_service.dart';
import '../../../data/models/message_model.dart';
import '../../../data/providers/storage_service.dart';
import '../../../core/base/safe_controller_mixin.dart';

class ChatdetailController extends GetxController with SafeControllerMixin {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  late Map<String, dynamic> conversation;
  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final RxBool isTyping = false.obs;
  final RxBool otherUserTyping = false.obs;
  final RxString typingUserName = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool hasMore = true.obs;
  int _currentPage = 1;
  int? _conversationId;

  // Produit sélectionné pour taguer dans le prochain message
  final Rx<Map<String, dynamic>?> selectedProduct = Rx<Map<String, dynamic>?>(null);

  // Offre Diaspo sélectionnée pour taguer dans le prochain message
  final Rx<Map<String, dynamic>?> selectedDiaspoOffer = Rx<Map<String, dynamic>?>(null);

  // WebSocket
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  Timer? _typingTimer;
  int get _currentUserId => StorageService.getUser()?.id ?? 0;

  @override
  void onInit() {
    super.onInit();
    conversation = Get.arguments ?? {};
    _conversationId = int.tryParse(conversation['id']?.toString() ?? '');

    // Si une offre Diaspo est passée en argument, la sélectionner automatiquement
    if (conversation['diaspo_offer'] != null) {
      selectedDiaspoOffer.value = conversation['diaspo_offer'];
    }

    // Si un message par défaut est fourni, l'insérer dans le champ de texte
    if (conversation['default_message'] != null) {
      messageController.text = conversation['default_message'];
    }

    _loadMessages();
    _setupWebSocket();

    // Écouter les changements dans le champ de texte pour envoyer typing indicator
    messageController.addListener(_onTextChanged);
  }

  @override
  void onClose() {
    markAsDisposed();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    messageController.removeListener(_onTextChanged);
    messageController.dispose();
    scrollController.dispose();

    // Se désabonner du WebSocket
    if (_conversationId != null) {
      WebSocketService.to.unsubscribeFromConversation(_conversationId!);
    }

    super.onClose();
  }

  void _setupWebSocket() {
    if (_conversationId == null) return;

    // S'abonner à la conversation
    WebSocketService.to.subscribeToConversation(_conversationId!);

    // Écouter les nouveaux messages en temps réel
    _messageSubscription = WebSocketService.to.messageStream.listen((message) {
      if (message.conversationId == _conversationId) {
        _handleNewMessage(message);
      }
    });

    // Écouter l'indicateur "est en train d'écrire"
    _typingSubscription = WebSocketService.to.typingStream.listen((data) {
      if (data['conversation_id'] == _conversationId &&
          data['user_id'] != _currentUserId) {
        typingUserName.value = data['user_name'] ?? '';
        otherUserTyping.value = data['is_typing'] ?? false;

        // Auto-hide après 3 secondes si toujours visible
        if (otherUserTyping.value) {
          Future.delayed(const Duration(seconds: 3), () {
            if (otherUserTyping.value) {
              otherUserTyping.value = false;
            }
          });
        }
      }
    });
  }

  void _handleNewMessage(MessageModel message) {
    // Éviter les doublons
    final exists = messages.any((m) => m['id']?.toString() == message.id.toString());
    if (exists) return;

    // Déterminer si c'est notre message
    final isMine = message.senderId == _currentUserId;

    final newMessage = {
      'id': message.id.toString(),
      'text': message.message,
      'isSentByMe': isMine,
      'timestamp': _formatTime(message.createdAt.toIso8601String()),
      'isRead': message.isRead,
    };

    messages.add(newMessage);
    _scrollToBottom();
  }

  void _onTextChanged() {
    if (_conversationId == null) return;

    final isCurrentlyTyping = messageController.text.trim().isNotEmpty;

    // Envoyer "is typing" seulement si le statut change
    if (isCurrentlyTyping != isTyping.value) {
      isTyping.value = isCurrentlyTyping;
      _sendTypingIndicator(isCurrentlyTyping);
    }

    // Annuler le timer précédent
    _typingTimer?.cancel();

    // Envoyer "stopped typing" après 2 secondes d'inactivité
    if (isCurrentlyTyping) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (isTyping.value) {
          isTyping.value = false;
          _sendTypingIndicator(false);
        }
      });
    }
  }

  Future<void> _sendTypingIndicator(bool typing) async {
    if (_conversationId == null) return;

    try {
      await ConversationService.sendTypingIndicator(_conversationId!, typing);
    } catch (e) {
      print('Error sending typing indicator: $e');
    }
  }

  Future<void> _loadMessages({bool refresh = false}) async {
    if (_conversationId == null) {
      // Pas de conversation, garder la liste vide
      messages.value = [];
      return;
    }

    if (refresh) {
      _currentPage = 1;
      hasMore.value = true;
    }

    isLoading.value = true;

    try {
      final response = await ConversationService.getMessages(
        _conversationId!,
        page: _currentPage,
      );

      if (response.success && response.data != null) {
        final msgList = response.data!['messages'] as List? ??
            response.data!['data'] as List? ??
            [];

        final converted = msgList.map((m) {
          final msg = Map<String, dynamic>.from(m);

          return <String, dynamic>{
            'id': msg['id']?.toString() ?? '',
            'text': msg['message'] ?? msg['text'] ?? '',
            'isSentByMe': msg['is_mine'] ?? msg['is_sent_by_me'] ?? false,
            'timestamp': _formatTime(msg['created_at']),
            'isRead': msg['is_read'] ?? false,
            // Charger le produit depuis le message (nouveau système)
            'product': msg['product'],
            // Charger l'offre Diaspo depuis le message
            'diaspo_offer': msg['diaspo_offer'],
          };
        }).toList();

        if (refresh || _currentPage == 1) {
          messages.value = converted;
        } else {
          messages.insertAll(0, converted);
        }

        final pagination = response.data!['pagination'] as Map<String, dynamic>?;
        hasMore.value = pagination?['has_more'] ?? false;
      } else {
        // Pas de données, garder la liste vide
        if (refresh || _currentPage == 1) {
          messages.value = [];
        }
      }
    } catch (e) {
      // En cas d'erreur, garder la liste vide
      if (refresh || _currentPage == 1) {
        messages.value = [];
      }
    } finally {
      isLoading.value = false;
      _scrollToBottom();
    }
  }

  String _formatTime(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr.toString();
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return;

    // Récupérer le product_id si un produit est sélectionné
    final productId = selectedProduct.value != null
        ? int.tryParse(selectedProduct.value!['id']?.toString() ?? '')
        : null;

    // Récupérer le diaspo_offer_id si une offre Diaspo est sélectionnée
    final diaspoOfferId = selectedDiaspoOffer.value != null
        ? int.tryParse(selectedDiaspoOffer.value!['id']?.toString() ?? '')
        : null;

    // Add message to UI immediately
    final tempMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'text': text,
      'isSentByMe': true,
      'timestamp': _getCurrentTime(),
      'isRead': false,
      'product': selectedProduct.value, // Ajouter le produit tagué
      'diaspo_offer': selectedDiaspoOffer.value, // Ajouter l'offre Diaspo taguée
    };

    messages.add(tempMessage);
    messageController.clear();

    // Réinitialiser les sélections après envoi
    selectedProduct.value = null;
    selectedDiaspoOffer.value = null;

    _scrollToBottom();

    // Send via API
    if (_conversationId != null) {
      try {
        print('📤 [CHAT] Sending message to API...');
        final response = await ConversationService.sendMessage(
          _conversationId!,
          text,
          productId: productId,
          diaspoOfferId: diaspoOfferId,
        );

        print('📥 [CHAT] API Response received:');
        print('   └─ Success: ${response.success}');
        print('   └─ Status Code: ${response.statusCode}');
        print('   └─ Message: ${response.message}');
        print('   └─ Data: ${response.data}');

        if (!response.success) {
          print('❌ [CHAT] Message sending failed!');
          Get.snackbar('Erreur', 'Message non envoyé',
            snackPosition: SnackPosition.BOTTOM,
          );
        } else {
          print('✅ [CHAT] Message sent successfully!');
        }
      } catch (e, stackTrace) {
        print('❌ [CHAT] Exception while sending message:');
        print('   └─ Error: $e');
        print('   └─ StackTrace: $stackTrace');
        Get.snackbar('Erreur', 'Impossible d\'envoyer le message',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  /// Sélectionner un produit à taguer dans le prochain message
  void selectProduct(Map<String, dynamic> product) {
    selectedProduct.value = product;
  }

  /// Annuler la sélection de produit
  void clearSelectedProduct() {
    selectedProduct.value = null;
  }

  /// Sélectionner une offre Diaspo à taguer dans le prochain message
  void selectDiaspoOffer(Map<String, dynamic> diaspoOffer) {
    selectedDiaspoOffer.value = diaspoOffer;
  }

  /// Annuler la sélection d'offre Diaspo
  void clearSelectedDiaspoOffer() {
    selectedDiaspoOffer.value = null;
  }

  void _scrollToBottom() {
    safeDelayed(const Duration(milliseconds: 100), () {
      if (scrollController.hasClients) {
        safeAnimateTo(
          scrollController,
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<void> refreshMessages() async {
    await _loadMessages(refresh: true);
  }
}
