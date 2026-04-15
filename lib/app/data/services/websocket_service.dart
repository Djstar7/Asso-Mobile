import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import '../providers/storage_service.dart';
import '../../core/values/constants.dart';

class WebSocketService extends GetxService {
  static WebSocketService get to => Get.find<WebSocketService>();

  WebSocketChannel? _channel;
  final _isConnected = false.obs;
  bool get isConnected => _isConnected.value;
  String? _socketId;

  // Streams pour broadcaster les événements
  final _messageStream = StreamController<MessageModel>.broadcast();
  final _typingStream = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineStatusStream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<MessageModel> get messageStream => _messageStream.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingStream.stream;
  Stream<Map<String, dynamic>> get onlineStatusStream =>
      _onlineStatusStream.stream;

  // Configuration Reverb (Laravel)
  static const String appKey = '9r0idxmfd6d9lc9e055h';
  static const String host = '10.30.89.109';
  static const int wsPort = 8080;

  // Channels actifs
  final Set<String> _subscribedChannels = {};
  StreamSubscription? _subscription;

  @override
  void onInit() {
    super.onInit();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    try {
      final authToken = StorageService.getToken();
      if (authToken == null) {
        print('⚠️  No auth token, skipping WebSocket initialization');
        return;
      }

      // Connexion WebSocket Pusher/Reverb
      final uri = Uri.parse(
        'ws://$host:$wsPort/app/$appKey?protocol=7&client=dart&version=1.0.0',
      );

      print('🔌 [WebSocket] Attempting to connect to: $uri');
      _channel = WebSocketChannel.connect(uri);

      // Écouter les messages entrants
      _subscription = _channel!.stream.listen(
        _handleIncomingMessage,
        onError: (error) {
          print('❌ [WebSocket] Error: $error');
          _isConnected.value = false;
        },
        onDone: () {
          print('🔌 [WebSocket] Connection closed');
          _isConnected.value = false;
        },
      );

      print(
        '🔌 [WebSocket] Stream listener attached, waiting for connection_established...',
      );
    } catch (e) {
      print('❌ [WebSocket] Error initializing: $e');
    }
  }

  /// Gérer les messages entrants
  void _handleIncomingMessage(dynamic message) {
    try {
      print('📨 [WebSocket] Raw message received: $message');
      final data = jsonDecode(message);
      final event = data['event'] as String?;

      if (event == null) {
        print('⚠️  [WebSocket] No event field in message');
        return;
      }

      print('📩 [WebSocket] Event: $event');

      switch (event) {
        case 'pusher:connection_established':
          _handleConnectionEstablished(data);
          break;
        case 'pusher_internal:subscription_succeeded':
          _handleSubscriptionSucceeded(data);
          break;
        case 'message.sent':
          _handleMessageSent(data);
          break;
        case 'user.typing':
          _handleUserTyping(data);
          break;
        case 'user.online.status':
          _handleOnlineStatus(data);
          break;
        default:
          print('📩 [WebSocket] Unhandled event: $event');
      }
    } catch (e) {
      print('❌ [WebSocket] Error handling incoming message: $e');
      print('   └─ Message was: $message');
    }
  }

  /// Connexion établie
  void _handleConnectionEstablished(Map<String, dynamic> data) {
    try {
      final dataContent = data['data'] is String
          ? jsonDecode(data['data'])
          : data['data'] as Map<String, dynamic>? ?? {};

      _socketId = dataContent['socket_id'] as String?;
      print('✅ Pusher connection established - Socket ID: $_socketId');
      _isConnected.value = true;
    } catch (e) {
      print('❌ Error parsing connection data: $e');
      _isConnected.value = true;
    }
  }

  /// Abonnement réussi
  void _handleSubscriptionSucceeded(Map<String, dynamic> data) {
    final channel = data['channel'] as String?;
    if (channel != null) {
      print('✅ Subscribed to channel: $channel');
    }
  }

  /// S'abonner à une conversation
  Future<void> subscribeToConversation(int conversationId) async {
    // Attendre que la connexion soit établie (max 5 secondes)
    int attempts = 0;
    while (!_isConnected.value && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (_channel == null || !_isConnected.value) {
      print('⚠️  WebSocket not connected after waiting');
      return;
    }

    final channelName = 'private-conversation.$conversationId';

    if (_subscribedChannels.contains(channelName)) {
      print('⚠️  Already subscribed to $channelName');
      return;
    }

    try {
      final authToken = StorageService.getToken();

      // Générer la signature d'authentification (simplifié pour Reverb)
      // En production, tu devrais appeler ton endpoint /broadcasting/auth
      final auth = await _getChannelAuth(channelName, authToken);

      // Envoyer la demande d'abonnement
      final subscribeMessage = jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName, 'auth': auth},
      });

      _channel!.sink.add(subscribeMessage);
      _subscribedChannels.add(channelName);

      print('📡 Subscribing to $channelName');
    } catch (e) {
      print('❌ Error subscribing to conversation: $e');
    }
  }

  /// Se désabonner d'une conversation
  Future<void> unsubscribeFromConversation(int conversationId) async {
    if (_channel == null) return;

    final channelName = 'private-conversation.$conversationId';

    if (!_subscribedChannels.contains(channelName)) {
      return;
    }

    try {
      final unsubscribeMessage = jsonEncode({
        'event': 'pusher:unsubscribe',
        'data': {'channel': channelName},
      });

      _channel!.sink.add(unsubscribeMessage);
      _subscribedChannels.remove(channelName);

      print('🔕 Unsubscribed from $channelName');
    } catch (e) {
      print('❌ Error unsubscribing: $e');
    }
  }

  /// S'abonner au statut en ligne d'un utilisateur
  Future<void> subscribeToUserStatus(int userId) async {
    // Attendre que la connexion soit établie (max 5 secondes)
    int attempts = 0;
    while (!_isConnected.value && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (_channel == null || !_isConnected.value) {
      print('⚠️  WebSocket not connected after waiting');
      return;
    }

    final channelName = 'private-user.status.$userId';

    if (_subscribedChannels.contains(channelName)) {
      return;
    }

    try {
      final authToken = StorageService.getToken();
      final auth = await _getChannelAuth(channelName, authToken);

      final subscribeMessage = jsonEncode({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName, 'auth': auth},
      });

      _channel!.sink.add(subscribeMessage);
      _subscribedChannels.add(channelName);

      print('🟢 Subscribed to user status: $userId');
    } catch (e) {
      print('❌ Error subscribing to user status: $e');
    }
  }

  /// Obtenir l'authentification du channel (appel à l'API Laravel)
  Future<String> _getChannelAuth(String channelName, String? token) async {
    if (_socketId == null) {
      print('⚠️  Socket ID not available yet');
      return '$appKey:no-socket-id';
    }

    if (token == null) {
      print('⚠️  No auth token available');
      return '$appKey:no-token';
    }

    try {
      // Extraire l'URL de base depuis AppConstants
      final baseUrl = AppConstants.baseUrl.replaceAll('/api', '');
      final authUrl = '$baseUrl/broadcasting/auth';

      print('🔑 Authenticating channel: $channelName');

      final response = await http.post(
        Uri.parse(authUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {'socket_id': _socketId!, 'channel_name': channelName},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final auth = data['auth'] as String;
        print('✅ Channel authenticated successfully');
        return auth;
      } else {
        print(
          '❌ Authentication failed: ${response.statusCode} - ${response.body}',
        );
        return '$appKey:auth-failed';
      }
    } catch (e) {
      print('❌ Error getting channel auth: $e');
      return '$appKey:error';
    }
  }

  /// Gérer l'événement message.sent
  void _handleMessageSent(Map<String, dynamic> data) {
    try {
      final messageData = data['data'] is String
          ? jsonDecode(data['data'])
          : data['data'] as Map<String, dynamic>? ?? {};

      if (messageData.isEmpty) {
        print('⚠️  Empty message data received');
        return;
      }

      // Extraire les données du message
      final msg = MessageModel(
        id: messageData['id'] ?? 0,
        conversationId: messageData['conversation_id'] ?? 0,
        senderId: messageData['sender_id'] ?? 0,
        message: messageData['message'] ?? '',
        productId: messageData['product_id'],
        isRead: messageData['is_read'] ?? false,
        createdAt: messageData['created_at'] != null
            ? DateTime.parse(messageData['created_at'])
            : DateTime.now(),
      );

      // Broadcaster le message
      _messageStream.add(msg);

      print('✅ Message broadcasted to stream');
    } catch (e) {
      print('❌ Error handling message.sent: $e');
    }
  }

  /// Gérer l'événement user.typing
  void _handleUserTyping(Map<String, dynamic> data) {
    try {
      final typingData = data['data'] is String
          ? jsonDecode(data['data'])
          : data['data'] as Map<String, dynamic>? ?? {};
      _typingStream.add(Map<String, dynamic>.from(typingData));
    } catch (e) {
      print('❌ Error handling user.typing: $e');
    }
  }

  /// Gérer l'événement user.online.status
  void _handleOnlineStatus(Map<String, dynamic> data) {
    try {
      final statusData = data['data'] is String
          ? jsonDecode(data['data'])
          : data['data'] as Map<String, dynamic>? ?? {};
      _onlineStatusStream.add(Map<String, dynamic>.from(statusData));
    } catch (e) {
      print('❌ Error handling user.online.status: $e');
    }
  }

  /// Se déconnecter
  Future<void> disconnect() async {
    try {
      _subscription?.cancel();
      await _channel?.sink.close();
      _isConnected.value = false;
      _subscribedChannels.clear();
      print('🔌 Disconnected from WebSocket');
    } catch (e) {
      print('❌ Error disconnecting: $e');
    }
  }

  @override
  void onClose() {
    disconnect();
    _messageStream.close();
    _typingStream.close();
    _onlineStatusStream.close();
    super.onClose();
  }
}
