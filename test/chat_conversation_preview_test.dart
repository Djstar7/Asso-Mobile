import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:asso/app/modules/chat/controllers/chat_controller.dart';
import 'package:asso/app/modules/chat/views/chat_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/themed_app.dart';

void main() {
  late Directory storage;
  dynamic lastMessage;
  var unreadCount = 0;
  Future<http.Response> Function(http.Request)? handler;
  final client = MockClient((request) async {
    if (handler != null) return handler!(request);
    return http.Response(
      jsonEncode({
        'success': true,
        'conversations': [
          {
            'id': 1,
            'other_user': {'id': 2, 'name': 'Boutique Baleng'},
            'product': {'id': 12, 'image': 'https://example.test/product.jpg'},
            'last_message': lastMessage,
            'unread_count': unreadCount,
          },
        ],
      }),
      200,
    );
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    storage = await Directory.systemTemp.createTemp('asso-chat-preview-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => storage.path,
        );
    await GetStorage.init();
  });
  setUp(() {
    handler = null;
    unreadCount = 0;
  });
  tearDown(Get.reset);
  tearDownAll(() => storage.delete(recursive: true));

  test('une réponse ancienne ne remplace pas la liste rafraîchie', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    handler = (_) async {
      if (++calls == 1) {
        started.complete();
        return pending.future;
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'conversations': [
            {'id': 2, 'last_message': 'Réponse récente'},
          ],
        }),
        200,
      );
    };
    await http.runWithClient(() async {
      final controller = Get.put(ChatController());
      final oldLoad = controller.refreshConversations();
      await started.future;
      await controller.loadConversations(refresh: true);
      pending.complete(
        http.Response(jsonEncode({'success': true, 'conversations': []}), 200),
      );
      await oldLoad;
      expect(controller.conversations.single['lastMessage'], 'Réponse récente');
      expect(controller.isLoading.value, isFalse);
    }, () => client);
  });

  test('un échec réseau conserve la liste déjà affichée', () async {
    final controller = Get.put(ChatController());
    lastMessage = 'Message conservé';
    await http.runWithClient(controller.refreshConversations, () => client);
    handler = (_) async => http.Response('{}', 503);
    await http.runWithClient(controller.refreshConversations, () => client);
    expect(controller.conversations.single['lastMessage'], 'Message conservé');
    expect(controller.isLoading.value, isFalse);
  });

  testWidgets('le retour actualise le dernier message et les non lus', (
    tester,
  ) async {
    await http.runWithClient(() async {
      lastMessage = 'Ancien message';
      unreadCount = 1;
      final controller = Get.put(ChatController());
      await controller.refreshConversations();
      await tester.pumpWidget(
        GetMaterialApp(
          home: const ChatView(),
          getPages: [
            GetPage(
              name: '/chatdetail',
              page: () => const Scaffold(body: Text('Discussion ouverte')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.totalUnreadCount, 1);
      await tester.tap(find.text('Boutique Baleng'));
      await tester.pumpAndSettle();
      expect(find.text('Discussion ouverte'), findsOneWidget);
      lastMessage = 'Nouveau message envoyé';
      unreadCount = 0;
      Get.back();
      await tester.pumpAndSettle();
      expect(find.text('Nouveau message envoyé'), findsOneWidget);
      expect(controller.totalUnreadCount, 0);
      expect(controller.isLoading.value, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  final cases = [
    (
      label: 'un texte associé à un produit reste un texte',
      last: <String, dynamic>{
        'message': 'Commande CMD088493 :',
        'image_path': null,
      },
      text: 'Commande CMD088493 :',
      image: null,
    ),
    (
      label: 'une photo réelle sans légende indique une photo',
      last: <String, dynamic>{
        'message': '',
        'image_path': 'https://example.test/photo.jpg',
      },
      text: 'chat.image_message',
      image: 'https://example.test/photo.jpg',
    ),
    (
      label: 'la légende et la photo du dernier message sont conservées',
      last: <String, dynamic>{
        'message': 'Voici votre commande',
        'image_path': 'https://example.test/commande.jpg',
      },
      text: 'Voici votre commande',
      image: 'https://example.test/commande.jpg',
    ),
    (
      label: 'un chemin vide n’est pas une photo',
      last: <String, dynamic>{'message': 'Bonjour', 'image_path': '   '},
      text: 'Bonjour',
      image: null,
    ),
    (
      label: 'un ancien aperçu texte ne devient pas une photo',
      last: 'Bonjour',
      text: 'Bonjour',
      image: null,
    ),
    (
      label: 'une conversation sans message ne simule pas de photo',
      last: null,
      text: '',
      image: null,
    ),
  ];

  for (final sample in cases) {
    testWidgets(sample.label, (tester) async {
      lastMessage = sample.last;
      final controller = Get.put(ChatController());
      await http.runWithClient(
        () => controller.refreshConversations(),
        () => client,
      );
      expect(controller.conversations.single['lastMessage'], sample.text.tr);
      expect(controller.conversations.single['lastMessageImage'], sample.image);
      // La photo du produit reste une donnée de contexte, distincte du message.
      expect(
        controller.conversations.single['productImage'],
        'https://example.test/product.jpg',
      );
      await tester.pumpWidget(themedApp(const ChatView()));
      final images = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        images.map((image) => image.imageUrl).toList(),
        sample.image == null ? isEmpty : [sample.image],
      );
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('un nouveau texte retire l’aperçu de la photo précédente', (
    tester,
  ) async {
    final controller = Get.put(ChatController());
    lastMessage = {
      'message': '',
      'image_path': 'https://example.test/photo.jpg',
    };
    await http.runWithClient(
      () => controller.refreshConversations(),
      () => client,
    );
    expect(controller.conversations.single['lastMessageImage'], isNotNull);
    lastMessage = {'message': 'Merci, bien reçu', 'image_path': null};
    await http.runWithClient(
      () => controller.refreshConversations(),
      () => client,
    );
    await tester.pumpWidget(themedApp(const ChatView()));
    expect(find.text('Merci, bien reçu'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(controller.conversations.single['lastMessageImage'], isNull);
    expect(tester.takeException(), isNull);
  });
}
