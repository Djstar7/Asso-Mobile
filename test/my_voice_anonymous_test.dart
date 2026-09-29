import 'package:asso/app/data/models/post.dart';
import 'package:asso/app/modules/myVoice/controllers/my_voice_controller.dart';
import 'package:asso/app/modules/myVoice/views/my_voice_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Contrôleur figé : la vue est testée seule, sans appel réseau.
class _FrozenController extends MyVoiceController {
  _FrozenController(this._seed);

  final List<Post> _seed;

  @override
  void onInit() {
    // Court-circuite le fetch initial de MyVoiceController.
    posts.assignAll(_seed);
    hasMore.value = false;
  }

  /// Le pied de liste appelle loadMore() dès qu'il est construit ; sans cette
  /// neutralisation, la requête laisserait un timer en suspens.
  @override
  Future<void> fetchPosts({bool refresh = false}) async {}

  @override
  String get currentUserInitials => 'Jean Baptiste';
}

Post buildPost({
  required bool isAnonymous,
  required bool isMyPost,
}) {
  return Post.fromJson({
    'id': 1,
    'user_id': isAnonymous && !isMyPost ? null : 8,
    'content': 'Le service client a été très réactif.',
    'is_anonymous': isAnonymous,
    'likes_count': 0,
    'dislikes_count': 0,
    'comments_count': 0,
    'is_my_post': isMyPost,
    'created_at': '2026-09-18T10:00:00+00:00',
    'updated_at': '2026-09-18T10:00:00+00:00',
    // Le serveur renvoie son propre profil à l'auteur, même anonyme.
    'user': isAnonymous && !isMyPost
        ? null
        : {
            'id': 8,
            'first_name': 'Jean',
            'last_name': 'Baptiste',
            'avatar': null,
          },
  });
}

Future<void> pumpFeed(WidgetTester tester, Post post) async {
  Get.testMode = true;
  Get.put<MyVoiceController>(_FrozenController([post]));
  timeago.setLocaleMessages('fr', timeago.FrMessages());

  await tester.pumpWidget(
    GetMaterialApp(home: const MyVoiceView()),
  );
  await tester.pump();
}

void main() {
  // Le composeur affiche la pastille de l'utilisateur en cache.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '.',
        );
    await GetStorage.init();
  });

  tearDown(Get.reset);

  testWidgets(
    'un message anonyme ne montre jamais le nom de son auteur, même à lui',
    (tester) async {
      await pumpFeed(tester, buildPost(isAnonymous: true, isMyPost: true));

      expect(find.text('Membre anonyme'), findsOneWidget);
      // Le cœur de la régression : le vrai nom ne doit apparaître nulle part
      // sur la carte, sans quoi l'auteur croit son identité publiée.
      expect(find.text('Jean Baptiste'), findsNothing);
      expect(find.text('ANONYME'), findsOneWidget);
      // Il doit malgré tout pouvoir reconnaître son propre message.
      expect(find.text('VOUS'), findsOneWidget);
    },
  );

  testWidgets('un message anonyme d\'un tiers reste anonyme', (tester) async {
    await pumpFeed(tester, buildPost(isAnonymous: true, isMyPost: false));

    expect(find.text('Membre anonyme'), findsOneWidget);
    expect(find.text('Jean Baptiste'), findsNothing);
    expect(find.text('VOUS'), findsNothing);
  });

  testWidgets('un message signé affiche bien son auteur', (tester) async {
    await pumpFeed(tester, buildPost(isAnonymous: false, isMyPost: true));

    expect(find.text('Jean Baptiste'), findsWidgets);
    expect(find.text('Membre anonyme'), findsNothing);
    expect(find.text('ANONYME'), findsNothing);
  });
}
