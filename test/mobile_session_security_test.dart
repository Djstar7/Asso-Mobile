import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:asso/app/core/utils/session_reset.dart';
import 'package:asso/app/data/models/user_model.dart';
import 'package:asso/app/data/providers/storage_service.dart';
import 'package:asso/app/modules/notification/controllers/notification_controller.dart';

void main() {
  late Directory directory;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    directory = await Directory.systemTemp.createTemp('asso-security-probe-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    await GetStorage.init();
    Get.testMode = true;
  });

  UserModel account(int id) => UserModel(
    id: id,
    firstName: 'Test',
    lastName: '$id',
    name: 'Test $id',
    email: 'test$id@example.invalid',
    phone: '',
    role: 'client',
    createdAt: '2026-01-01T00:00:00Z',
  );

  test('old notifications cannot repopulate a new session', () async {
    final started = Completer<void>();
    final reply = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.headers['Authorization'] == 'Bearer synthetic-account-b') {
        return http.Response(
          jsonEncode({'success': true, 'notifications': [], 'unread_count': 0}),
          200,
        );
      }
      expect(request.headers['Authorization'], 'Bearer synthetic-account-a');
      started.complete();
      return reply.future;
    });
    await http.runWithClient(() async {
      StorageService.saveAuthSession('synthetic-account-a', account(101));
      // Only skip Firebase listeners; use the real controller and session reset.
      final controller = Get.put<NotificationController>(
        _AuditNotificationController(),
        permanent: true,
      );
      final pending = controller.fetchNotifications(refresh: true);
      await started.future;
      StorageService.clearAuth();
      SessionReset.clearControllers();
      StorageService.saveAuthSession('synthetic-account-b', account(202));
      SessionReset.onLogin();
      await Future<void>.delayed(Duration.zero);
      expect(controller.notifications, isEmpty);
      reply.complete(
        http.Response(
          jsonEncode({
            'success': true,
            'notifications': [
              {
                'id': 1,
                'user_id': 101,
                'title': 'Private A',
                'body': 'Synthetic A',
                'created_at': '2026-01-01T00:00:00Z',
                'updated_at': '2026-01-01T00:00:00Z',
              },
            ],
            'unread_count': 1,
          }),
          200,
        ),
      );
      await pending;
      expect(StorageService.getUser()?.id, 202);
      expect(controller.notifications, isEmpty);
      expect(controller.unreadCount.value, 0);
    }, () => client);
  });
}

class _AuditNotificationController extends NotificationController {
  @override
  // Deliberately bypass Firebase setup; this probe only exercises API responses.
  // ignore: must_call_super
  void onInit() {}
}
