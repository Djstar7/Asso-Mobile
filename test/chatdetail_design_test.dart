import 'package:asso/app/core/utils/app_design.dart';
import 'package:asso/app/modules/chatdetail/controllers/chatdetail_controller.dart';
import 'package:asso/app/modules/chatdetail/views/chatdetail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'helpers/themed_app.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'SF-Pro',
    )..addFont(rootBundle.load('assets/fonts/SF-Pro/SF-Pro.ttf'))).load();
  });
  tearDown(Get.reset);

  ChatdetailController conversation({bool single = false}) {
    final value = ChatdetailController();
    value.conversation = {
      'name': 'Boutique Baleng',
      'avatar': 'BB',
      'isOnline': false,
    };
    value.messages.assignAll(
      single
          ? [
              {
                'id': 'last',
                'text': 'Commande CMD088493 :',
                'timestamp': '18:42',
                'isSentByMe': true,
                'isRead': true,
              },
            ]
          : [
              {
                'id': 'first',
                'text': 'Bonjour, ce téléphone est-il toujours disponible ?',
                'timestamp': '18:40',
                'isSentByMe': true,
                'isRead': true,
              },
              {
                'id': 'received',
                'text':
                    'Bonjour ! Oui, il est disponible. Nous pouvons vous le livrer à Douala.',
                'timestamp': '18:41',
                'isSentByMe': false,
                'isRead': true,
              },
              {
                'id': 'another',
                'text': 'La livraison est prévue sous 2 jours ouvrables.',
                'timestamp': '18:41',
                'isSentByMe': false,
                'isRead': true,
              },
              {
                'id': 'last',
                'text':
                    'Parfait, merci ! Je viens de passer la commande CMD088493.',
                'timestamp': '18:42',
                'isSentByMe': true,
                'isRead': true,
              },
            ],
    );
    addTearDown(value.onClose);
    return value;
  }

  Future<void> render(
    WidgetTester tester,
    ChatdetailController value, {
    double width = 390,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      themedApp(ChatdetailView(pageController: value), textScale: scale),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  }

  testWidgets('un message court repose en bas et reste aligné à droite', (
    tester,
  ) async {
    await render(tester, conversation(single: true));
    final bubble = tester.getRect(
      find.byKey(const ValueKey('chat-bubble-last')),
    );
    final input = tester.getRect(find.byType(TextField));
    expect(bubble.right, closeTo(378, 1));
    expect(bubble.bottom, lessThan(input.top));
    expect(input.top - bubble.bottom, lessThan(60));
    expect(
      tester.widget<Text>(find.text('Commande CMD088493 :')).style!.color,
      Colors.white,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.done_all_rounded)).color,
      Colors.white,
    );
    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('goldens/chat_single_390.png'),
    );
  });

  testWidgets('les messages reçus et envoyés gardent leurs côtés', (
    tester,
  ) async {
    await render(tester, conversation());
    expect(
      tester.getRect(find.byKey(const ValueKey('chat-bubble-received'))).left,
      closeTo(12, 1),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('chat-bubble-last'))).right,
      closeTo(378, 1),
    );
    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('goldens/chat_390.png'),
    );
  });

  testWidgets('les longs messages restent lisibles à 320 et texte 200 %', (
    tester,
  ) async {
    final value = conversation();
    await render(tester, value, width: 320, scale: 2);
    final scroll = value.scrollController;
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const ValueKey('chat-bubble-last'))).width,
      lessThanOrEqualTo(249),
    );
    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('goldens/chat_320_large_text.png'),
    );
  });

  testWidgets('le fil est borné sur une grande largeur', (tester) async {
    await render(tester, conversation(), width: 1024);
    final bubble = tester.getRect(
      find.byKey(const ValueKey('chat-bubble-last')),
    );
    expect(bubble.width, lessThanOrEqualTo(480));
    await expectLater(
      find.byType(GetMaterialApp),
      matchesGoldenFile('goldens/chat_1024.png'),
    );
  });

  testWidgets('le clavier laisse le dernier message et la saisie visibles', (
    tester,
  ) async {
    final value = conversation(single: true);
    await render(tester, value);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    final field = tester.getRect(find.byType(TextField));
    expect(field.bottom, lessThanOrEqualTo(844 - 300));
    expect(
      tester.getRect(find.byKey(const ValueKey('chat-bubble-last'))).bottom,
      lessThan(field.top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('la barre de saisie conserve les restrictions du support', (
    tester,
  ) async {
    final value = conversation(single: true)..isSupport = true;
    value.canSend.value = true;
    await render(tester, value);
    expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLines, 5);
    final icon = tester.widget<Icon>(find.byIcon(Icons.arrow_upward_rounded));
    expect(icon.color, AppDesign.onAccent);
  });
  testWidgets(
    'les citations produit restent accessibles dans une bulle étroite',
    (tester) async {
      final value = conversation(single: true);
      value.messages.first['product'] = {
        'id': 12,
        'name': 'Samsung Galaxy avec accessoires',
        'price': 100000,
        'images': <String>[],
      };
      await render(tester, value, width: 320, scale: 2);
      expect(find.text('Samsung Galaxy avec accessoires'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
