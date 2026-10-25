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
  final client = MockClient(
    (_) async => http.Response(
      jsonEncode({
        'success': true,
        'conversations': [
          {
            'id': 1,
            'other_user': {'id': 2, 'name': 'Boutique Baleng'},
            'product': {'id': 12, 'image': 'https://example.test/product.jpg'},
            'last_message': lastMessage,
            'unread_count': 0,
          },
        ],
      }),
      200,
    ),
  );

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
  tearDown(Get.reset);
  tearDownAll(() => storage.delete(recursive: true));

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
