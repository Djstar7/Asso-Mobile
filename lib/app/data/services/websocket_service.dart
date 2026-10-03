import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';
import '../providers/storage_service.dart';
import '../../core/values/constants.dart';
import '../../core/services/locale_service.dart';

class WebSocketService extends GetxService with WidgetsBindingObserver {
  static WebSocketService get to => Get.find<WebSocketService>();

  WebSocketChannel? _channel;
  final _isConnected = false.obs;
  bool get isConnected => _isConnected.value;
  String? _socketId;

  /// Incrémenté à chaque connexion établie. Un écran qui écoute le temps réel
  /// s'y abonne pour recharger ce qu'il a pu manquer pendant la coupure
  /// (application en arrière-plan, réseau perdu).
  final connectionEpoch = 0.obs;

  /// Numéro de la connexion courante : les événements d'un ancien canal,
  /// arrivés après une reconnexion, sont ignorés.
  int _generation = 0;

  /// Vrai quand l'application est au premier plan. En arrière-plan, le
  /// système coupe le réseau de l'application : inutile de s'y acharner.
  bool _inForeground = true;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  /// Le serveur a refusé la connexion pour de bon (codes Pusher 4000-4099 :
  /// clé d'application inconnue, protocole refusé…). Réessayer avec les
  /// mêmes paramètres échouerait à l'identique : on attend le prochain
  /// retour au premier plan ou la prochaine connexion au compte.
  bool _refusedByServer = false;

  /// Silence au-delà duquel on sonde le serveur (`activity_timeout` annoncé
  /// à la connexion, 30 s chez Reverb).
  Duration _activityTimeout = const Duration(seconds: 30);

  /// Délai de réponse au sondage avant de tenir la connexion pour morte.
  static const Duration _pongTimeout = Duration(seconds: 30);

  Timer? _activityTimer;
  Timer? _pongTimer;

  // Streams pour broadcaster les événements
  final _messageStream = StreamController<MessageModel>.broadcast();
  final _typingStream = StreamController<Map<String, dynamic>>.broadcast();
  final _onlineStatusStream =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<MessageModel> get messageStream => _messageStream.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingStream.stream;
  Stream<Map<String, dynamic>> get onlineStatusStream =>
      _onlineStatusStream.stream;

  // ==========================================================================
  // Configuration Reverb (Laravel)
  // --------------------------------------------------------------------------
  // Le défaut vise la production : un APK distribué ne doit jamais pointer vers
  // une IP de réseau local, injoignable pour le testeur.
  //
  // Les trois paramètres sont surchargeables au build, comme l'API :
  //   flutter build apk --dart-define=WS_HOST=asso-dashboard.sbs \
  //                     --dart-define=WS_PORT=443 \
  //                     --dart-define=WS_TLS=true \
  //                     --dart-define=REVERB_APP_KEY=<clé du serveur>
  //
  // WS_TLS indique si le port Reverb est servi en TLS (wss) ou en clair (ws).
  // En production, Reverb est servi derrière le domaine, en TLS sur le 443 :
  // wss://asso-dashboard.sbs/app/<clé>. L'ancien port 8080 répondait
  // « Application does not exist » (4001) et le 8085 n'est pas exposé : le
  // temps réel ne se connectait jamais.
  // ==========================================================================

  /// Clé applicative Reverb, elle doit correspondre à REVERB_APP_KEY du serveur.
  static const String appKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: '9r0idxmfd6d9lc9e055h',
  );

  static const String host = String.fromEnvironment(
    'WS_HOST',
    defaultValue: AppConstants.productionDomain,
  );
  static const int wsPort = int.fromEnvironment('WS_PORT', defaultValue: 443);

  /// true -> wss://, false -> ws://
  static const bool useTls = bool.fromEnvironment('WS_TLS', defaultValue: true);

  static String get wsScheme => useTls ? 'wss' : 'ws';

  /// Canaux voulus par les écrans ouverts. Ils survivent aux coupures : à
  /// chaque connexion établie, on s'y réabonne.
  final Set<String> _wantedChannels = {};

  /// Canaux effectivement demandés sur la connexion courante.
  final Set<String> _subscribedChannels = {};
  StreamSubscription? _subscription;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initializeWebSocket();
  }

  /// Suit le cycle de vie de l'application.
  ///
  /// En arrière-plan, iOS et Android suspendent l'application et la
  /// connexion meurt sans prévenir : le chat restait ensuite muet jusqu'au
  /// redémarrage. On ferme donc proprement à la mise en pause, et on
  /// rouvre au retour au premier plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _inForeground = true;
        _reconnectAttempts = 0;
        _refusedByServer = false;
        ensureConnected();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _inForeground = false;
        _closeChannel();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Ouvre la connexion si elle ne l'est pas déjà (retour au premier plan,
  /// réseau retrouvé). Sans effet sans session.
  void ensureConnected() {
    if (_channel != null || StorageService.getToken() == null) return;
    _reconnectTimer?.cancel();
    _initializeWebSocket();
  }

  Future<void> _initializeWebSocket() async {
    try {
      final authToken = StorageService.getToken();
      if (authToken == null) {
        print('⚠️  No auth token, skipping WebSocket initialization');
        return;
      }
      if (_channel != null) return;
      final generation = ++_generation;

      // Connexion WebSocket Pusher/Reverb. Le schéma suit WS_TLS : le port
      // Reverb n'est pas forcément servi derrière le certificat du domaine.
      final uri = Uri.parse(
        '$wsScheme://$host:$wsPort/app/$appKey'
        '?protocol=7&client=dart&version=1.0.0',
      );

      print('🔌 [WebSocket] Attempting to connect to: $uri');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      // L'échec de connexion arrive aussi par `onError` ci-dessous ; sans
      // cela, `ready` le remonterait en erreur non interceptée.
      channel.ready.catchError((_) {});

      // Écouter les messages entrants
      _subscription = channel.stream.listen(
        (message) {
          if (generation != _generation) return;
          _onActivity(generation);
          _handleIncomingMessage(message);
        },
        onError: (error) {
          print('❌ [WebSocket] Error: $error');
          _onConnectionLost(generation);
        },
        onDone: () {
          print('🔌 [WebSocket] Connection closed');
          _onConnectionLost(generation);
        },
        cancelOnError: true,
      );

      print(
        '🔌 [WebSocket] Stream listener attached, waiting for connection_established...',
      );
    } catch (e) {
      print('❌ [WebSocket] Error initializing: $e');
      _channel = null;
      _scheduleReconnect();
    }
  }

  /// Le serveur vient de parler : la connexion est vivante.
  ///
  /// Après [_activityTimeout] de silence, on envoie `pusher:ping` ; sans
  /// réponse sous [_pongTimeout], la connexion est morte sans que le système
  /// l'ait signalé (passage du Wi-Fi à la 4G, réseau perdu dans un
  /// ascenseur…) : on la relance plutôt que de laisser le chat muet.
  void _onActivity(int generation) {
    _pongTimer?.cancel();
    _pongTimer = null;
    _activityTimer?.cancel();
    _activityTimer = Timer(_activityTimeout, () {
      if (generation != _generation) return;
      _send({'event': 'pusher:ping', 'data': {}});
      _pongTimer = Timer(_pongTimeout, () {
        if (generation != _generation) return;
        print('⚠️  [WebSocket] Pas de réponse au ping : reconnexion');
        _closeChannel();
        _scheduleReconnect();
      });
    });
  }

  void _stopActivityTimers() {
    _activityTimer?.cancel();
    _activityTimer = null;
    _pongTimer?.cancel();
    _pongTimer = null;
  }

  /// La connexion [generation] s'est fermée ou a échoué.
  void _onConnectionLost(int generation) {
    // Fermeture volontaire, ou connexion déjà remplacée.
    if (generation != _generation) return;
    _stopActivityTimers();
    _subscription?.cancel();
    _subscription = null;
    _channel = null;
    _socketId = null;
    _isConnected.value = false;
    _subscribedChannels.clear();
    _scheduleReconnect();
  }

  /// Reprogramme une connexion, avec un délai croissant (2 s, 4 s… 1 min)
  /// pour ne pas marteler un serveur injoignable.
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (!_inForeground ||
        _refusedByServer ||
        StorageService.getToken() == null) {
      return;
    }

    final seconds = math.min(60, 2 << math.min(_reconnectAttempts, 5));
    _reconnectAttempts++;
    print('🔁 [WebSocket] Reconnexion dans ${seconds}s');
    _reconnectTimer = Timer(Duration(seconds: seconds), ensureConnected);
  }

  /// Ferme la connexion courante sans oublier les canaux voulus.
  void _closeChannel() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopActivityTimers();
    // Invalide les rappels de l'ancien canal (onDone arrive après close).
    _generation++;
    final channel = _channel;
    _channel = null;
    _subscription?.cancel();
    _subscription = null;
    _socketId = null;
    _isConnected.value = false;
    _subscribedChannels.clear();
    if (channel != null) {
      channel.sink.close().catchError((_) {});
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
        case 'pusher:pong':
          // Réponse à notre sondage : `_onActivity` a déjà tout réarmé.
          break;
        case 'pusher:ping':
          // Sans réponse, le serveur ferme la connexion au bout de quelques
          // minutes d'inactivité : le chat cessait alors de se mettre à jour.
          _send({'event': 'pusher:pong', 'data': {}});
          break;
        case 'pusher:error':
          _handleServerError(data);
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

  /// Erreur signalée par le serveur Pusher/Reverb.
  void _handleServerError(Map<String, dynamic> data) {
    print('⚠️  [WebSocket] Erreur serveur : ${data['data']}');
    try {
      final payload = data['data'] is String
          ? jsonDecode(data['data'])
          : data['data'];
      final code = payload is Map ? int.tryParse('${payload['code']}') : null;
      if (code != null && code >= 4000 && code < 4100) {
        _refusedByServer = true;
      }
    } catch (_) {}
  }

  /// Connexion établie
  void _handleConnectionEstablished(Map<String, dynamic> data) {
    try {
      final dataContent = data['data'] is String
          ? jsonDecode(data['data'])
          : data['data'] as Map<String, dynamic>? ?? {};

      _socketId = dataContent['socket_id'] as String?;
      final timeout = int.tryParse('${dataContent['activity_timeout'] ?? ''}');
      if (timeout != null && timeout > 0) {
        _activityTimeout = Duration(seconds: timeout.clamp(10, 120));
      }
      print('✅ Pusher connection established - Socket ID: $_socketId');
    } catch (e) {
      print('❌ Error parsing connection data: $e');
    }
    _isConnected.value = true;
    _reconnectAttempts = 0;
    connectionEpoch.value++;
    _resubscribeAll();
  }

  /// Rétablit, sur la nouvelle connexion, les abonnements des écrans ouverts.
  void _resubscribeAll() {
    for (final channelName in _wantedChannels.toList()) {
      _subscribe(channelName);
    }
  }

  /// Envoie un message sur la connexion courante, sans lever si elle vient
  /// de se fermer.
  void _send(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(payload));
    } catch (e) {
      print('❌ [WebSocket] Envoi impossible : $e');
    }
  }

  /// Attend la connexion (5 s au plus). Faux si elle n'est pas établie.
  Future<bool> _waitForConnection() async {
    ensureConnected();
    int attempts = 0;
    while (!_isConnected.value && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    return _channel != null && _isConnected.value;
  }

  /// Demande l'abonnement à [channelName] sur la connexion courante.
  Future<void> _subscribe(String channelName) async {
    if (_subscribedChannels.contains(channelName)) return;
    final generation = _generation;

    try {
      final authToken = StorageService.getToken();
      final auth = await _getChannelAuth(channelName, authToken);

      // Connexion remplacée ou canal abandonné pendant l'authentification.
      if (generation != _generation ||
          !_wantedChannels.contains(channelName) ||
          _subscribedChannels.contains(channelName)) {
        return;
      }

      _send({
        'event': 'pusher:subscribe',
        'data': {'channel': channelName, 'auth': auth},
      });
      _subscribedChannels.add(channelName);
      print('📡 Subscribing to $channelName');
    } catch (e) {
      print('❌ Error subscribing to $channelName: $e');
    }
  }

  /// Abonnement réussi
  void _handleSubscriptionSucceeded(Map<String, dynamic> data) {
    final channel = data['channel'] as String?;
    if (channel != null) {
      print('✅ Subscribed to channel: $channel');
    }
  }

  /// S'abonner à une conversation.
  ///
  /// L'abonnement est retenu : il est rétabli de lui-même après une coupure,
  /// jusqu'à [unsubscribeFromConversation].
  Future<void> subscribeToConversation(int conversationId) =>
      _want('private-conversation.$conversationId');

  /// Se désabonner d'une conversation
  Future<void> unsubscribeFromConversation(int conversationId) async {
    final channelName = 'private-conversation.$conversationId';
    _wantedChannels.remove(channelName);
    if (!_subscribedChannels.remove(channelName)) return;

    _send({
      'event': 'pusher:unsubscribe',
      'data': {'channel': channelName},
    });
    print('🔕 Unsubscribed from $channelName');
  }

  /// S'abonner au statut en ligne d'un utilisateur
  Future<void> subscribeToUserStatus(int userId) =>
      _want('private-user.status.$userId');

  /// Retient [channelName] et s'y abonne dès que la connexion est prête.
  Future<void> _want(String channelName) async {
    _wantedChannels.add(channelName);
    if (!await _waitForConnection()) {
      // La connexion établie plus tard rejouera l'abonnement.
      print('⚠️  WebSocket not connected yet, $channelName en attente');
      return;
    }
    await _subscribe(channelName);
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
          'Accept-Language': LocaleService.currentLanguage,
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

  /// Reconnecter avec le token courant.
  ///
  /// Le service est `permanent: true` (main.dart) : son `onInit` ne rejoue
  /// jamais. Démarrée en mode invité, l'application n'avait aucun token et la
  /// connexion avait été abandonnée ; après un login il faut donc relancer
  /// explicitement l'initialisation, sinon le temps réel (chat, suivi de
  /// commande) reste muet jusqu'au prochain démarrage.
  Future<void> reconnect() async {
    await disconnect();
    _reconnectAttempts = 0;
    _refusedByServer = false;
    await _initializeWebSocket();
  }

  /// Se déconnecter (déconnexion du compte) : les abonnements sont oubliés.
  Future<void> disconnect() async {
    _wantedChannels.clear();
    _closeChannel();
    print('🔌 Disconnected from WebSocket');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    disconnect();
    _messageStream.close();
    _typingStream.close();
    _onlineStatusStream.close();
    super.onClose();
  }
}
