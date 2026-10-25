import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:asso/app/core/utils/session_scope.dart';
import 'package:asso/app/data/models/user_model.dart';
import 'package:asso/app/data/providers/api_provider.dart';
import 'package:asso/app/data/providers/auth_service.dart';
import 'package:asso/app/data/providers/authenticated_download.dart';
import 'package:asso/app/data/providers/offline_store.dart';
import 'package:asso/app/data/providers/offline_read_cache.dart';
import 'package:asso/app/data/services/connectivity_service.dart';
import 'package:asso/app/data/services/wallet_service.dart';
import 'package:asso/app/modules/wallet/controllers/wallet_controller.dart';
import 'package:asso/app/modules/productManagement/controllers/product_management_controller.dart';
import 'package:asso/app/modules/addProduct/controllers/product_draft_store.dart';
import 'package:asso/app/data/providers/private_exports.dart';
import 'package:asso/app/data/providers/secure_vault.dart';
import 'package:asso/app/data/providers/storage_service.dart';
import 'package:asso/app/core/values/constants.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory directory;
  late Future<http.Response> Function(http.Request) handle;
  final client = MockClient((request) => handle(request));
  UserModel account(int id) => UserModel.fromJson({
    'id': id,
    'name': 'PRIVATE_PROFILE_MARKER',
    'email': 'test@example.invalid',
  });

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.testMode = true;
    directory = await Directory.systemTemp.createTemp(
      'asso-security-regression-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => directory.path,
        );
    await GetStorage.init();
  });
  tearDownAll(() async {
    await StorageService.clearAuth();
    await Hive.close();
    Get.reset();
    await directory.delete(recursive: true);
  });

  test(
    'legacy session migrates to the vault and leaves no plaintext identity',
    () async {
      await GetStorage().write('token', 'PRIVATE_TOKEN_MARKER');
      await GetStorage().write('user', account(101).toJson());
      await StorageService.initSecureStorage();
      expect(StorageService.getToken(), 'PRIVATE_TOKEN_MARKER');
      expect(StorageService.getUser()?.id, 101);
      expect(GetStorage().read('token'), isNull);
      expect(GetStorage().read('user'), isNull);
      final encryptedValue = await SecureVault.storage.read(
        key: 'asso_session_v1',
      );
      expect(jsonDecode(encryptedValue!)['token'], 'PRIVATE_TOKEN_MARKER');
      // Wait for GetStorage's scheduled disk flush and recovery copy.
      await GetStorage().queue.add(() async {});
      await Future<void>.delayed(const Duration(milliseconds: 30));
      for (final name in ['GetStorage.gs', 'GetStorage.bak']) {
        final file = File('${directory.path}/$name');
        if (await file.exists()) {
          final content = await file.readAsString();
          expect(content, isNot(contains('PRIVATE_TOKEN_MARKER')));
          expect(content, isNot(contains('PRIVATE_PROFILE_MARKER')));
        }
      }
    },
  );

  test(
    'login/logout persistence is ordered and cannot resurrect an older session',
    () async {
      final writes = [
        StorageService.saveAuthSession('A', account(101)),
        StorageService.clearAuthSession(),
        StorageService.saveAuthSession('B', account(202)),
      ];
      await Future.wait(writes);
      final session = jsonDecode(
        (await SecureVault.storage.read(key: 'asso_session_v1'))!,
      );
      expect(session['token'], 'B');
      expect(session['user']['id'], 202);
      await StorageService.clearAuthSession();
      expect(await SecureVault.storage.read(key: 'asso_session_v1'), isNull);
    },
  );

  test(
    'plaintext Hive drafts and photos migrate without losing data',
    () async {
      await StorageService.saveAuthSession('A', account(101));
      await GetStorage().write('add_product_draft_v1', jsonEncode({
        'savedAt': DateTime.now().toIso8601String(),
        'step': 1, 'fields': {'name': 'PRIVATE_FORM_MARKER'},
        'imagePaths': [], 'primaryImageIndex': 0, 'variants': {},
      }));
      await Hive.initFlutter();
      final legacy = await Hive.openBox<String>('offline_products');
      await legacy.put(
        'draft-1',
        jsonEncode({'user_id': 101, 'name': 'PRIVATE_DRAFT_MARKER'}),
      );
      await legacy.close();
      final image = Uint8List.fromList(
        utf8.encode('PRIVATE_PHOTO_MARKER' * 20),
      );
      final photos = await Hive.openLazyBox<Uint8List>(
        'offline_product_images',
      );
      await photos.put('image-1', image);
      await photos.close();
      await OfflineStore.init();
      expect(ProductDraftStore.read()?.fields['name'], 'PRIVATE_FORM_MARKER');
      expect(GetStorage().read('add_product_draft_v1'), isNull);
      await StorageService.saveAuthSession('B', account(202));
      expect(ProductDraftStore.read(), isNull);
      await StorageService.saveAuthSession('A2', account(101));
      expect(
        OfflineStore.readPendingProducts().single['name'],
        'PRIVATE_DRAFT_MARKER',
      );
      expect(await OfflineStore.readPendingImage('image-1'), image);
      expect(await Hive.boxExists('offline_products'), isFalse);
      expect(await Hive.boxExists('offline_product_images'), isFalse);
      await Hive.box<String>('offline_products_secure_v1').flush();
      for (final entry in directory.listSync().whereType<File>()) {
        if (!entry.path.endsWith('.hive')) continue;
        final content = latin1.decode(await entry.readAsBytes());
        expect(content, isNot(contains('PRIVATE_DRAFT_MARKER')));
        expect(content, isNot(contains('PRIVATE_PHOTO_MARKER')));
        expect(content, isNot(contains('PRIVATE_FORM_MARKER')));
      }
    },
  );

  test(
    'logout removes snapshots and private exports while preserving encrypted drafts',
    () async {
      await StorageService.saveAuthSession('A', account(101));
      await OfflineStore.saveSnapshot('dashboard', {'amount': 1200});
      final file = await PrivateExports.write('facture_test.pdf', [
        1,
        2,
        3,
      ], SessionScope.current);
      expect(await file!.exists(), isTrue);
      await StorageService.clearAuth();
      expect(await file.exists(), isFalse);
      await StorageService.saveAuthSession('A2', account(101));
      expect(OfflineStore.readSnapshot('dashboard'), isNull);
      expect(OfflineStore.readPendingProducts(), hasLength(1));
    expect(ProductDraftStore.read()?.fields['name'], 'PRIVATE_FORM_MARKER');
    },
  );

  test(
    'Bearer is never sent to a foreign origin, userinfo URL or HTTP downgrade',
    () async {
      var requests = 0;
      handle = (request) async {
        requests++;
        return http.Response('', 200);
      };
      await StorageService.saveAuthSession('secret', account(101));
      await http.runWithClient(() async {
        for (final url in [
          'https://example.invalid/invoice.pdf',
          'https://${AppConstants.productionDomain}.example.invalid/invoice.pdf',
          'http://${AppConstants.productionDomain}/invoice.pdf',
          'https://user@${AppConstants.productionDomain}/invoice.pdf',
          'https://${AppConstants.productionDomain}:444/invoice.pdf',
        ]) {
          expect(
            await AuthenticatedDownload.get(
              Uri.parse(url),
              accept: 'application/pdf',
            ),
            isNull,
          );
        }
      }, () => client);
      expect(requests, 0);
    },
  );

  test(
    'authenticated downloads refuse a redirect without contacting its destination',
    () async {
      var requests = 0;
      handle = (request) async {
        requests++;
        expect(request.headers['Authorization'], 'Bearer secret');
        expect(request.followRedirects, isFalse);
        return http.Response(
          '',
          302,
          headers: {'location': 'https://example.invalid/steal'},
        );
      };
      await http.runWithClient(() async {
        expect(
          await AuthenticatedDownload.get(
            Uri.parse('${AppConstants.baseUrl}/v1/invoices/1'),
            accept: 'application/pdf',
          ),
          isNull,
        );
      }, () => client);
      expect(requests, 1);
    },
  );

  test(
    'a late API success or 401 cannot affect the replacement session',
    () async {
      await http.runWithClient(() async {
        for (final status in [200, 401]) {
          await StorageService.saveAuthSession('A', account(101));
          final started = Completer<void>();
          final response = Completer<http.Response>();
          handle = (_) {
            started.complete();
            return response.future;
          };
          final pending = ApiProvider.get('/v1/notifications');
          await started.future;
          await StorageService.clearAuthSession();
          await StorageService.saveAuthSession('B', account(202));
          response.complete(
            http.Response(
              jsonEncode({'success': true, 'private': 'A'}),
              status,
            ),
          );
          final result = await pending;
          expect(result.success, isFalse);
          expect(result.data, isNull);
          expect(StorageService.getToken(), 'B');
        }
      }, () => client);
    },
  );

  test('a late logout of A cannot clear B', () async {
    await StorageService.saveAuthSession('A', account(101));
    final started = Completer<void>();
    final response = Completer<http.Response>();
    handle = (_) {
      started.complete();
      return response.future;
    };
    await http.runWithClient(() async {
      final logout = AuthService.logout();
      await started.future;
      await StorageService.saveAuthSession('B', account(202));
      response.complete(http.Response('{"success":true}', 200));
      await logout;
      expect(StorageService.getToken(), 'B');
    }, () => client);
  });

  test(
    'offline products and wallet use encrypted account-scoped reads and reject writes',
    () async {
      await StorageService.saveAuthSession('A', account(101));
      var requests = 0;
      handle = (request) async {
        requests++;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'current_balance': 1200},
          }),
          200,
        );
      };
      final connectivity = Get.put(ConnectivityService());
      await http.runWithClient(() async {
        final live = await ApiProvider.get('/v1/wallet');
        expect(live.success, isTrue);
        expect(requests, 1);
        await OfflineReadCache.save(
          Uri.parse(
            '${AppConstants.baseUrl}/v1/vendor/products?page=1&per_page=20',
          ),
          {
            'success': true,
            'data': [
              {'id': 1, 'name': 'Chaise', 'status': 'active'},
              {'id': 2, 'name': 'Table', 'status': 'inactive'},
            ],
          },
        );
        connectivity.isOnline.value = false;
        final saved = await ApiProvider.get('/v1/wallet');
        expect(saved.success, isTrue);
        expect(saved.data?['_offline'], isTrue);
        expect(saved.data?['_saved_at'], isNotNull);
        expect(saved.data?['data']['current_balance'], 1200);

        Get.put(WalletService());
        final wallet = WalletController();
        await wallet.loadWallet();
        expect(wallet.wallet.value?.currentBalance, 1200);
        expect(wallet.isReadOnly, isTrue);
        expect(wallet.isShowingSnapshot.value, isTrue);

        final catalogue = ProductManagementController();
        await catalogue.loadProducts();
        expect(catalogue.products, hasLength(2));
        expect(catalogue.isShowingSnapshot.value, isTrue);
        catalogue.searchQuery.value = 'chai';
        await catalogue.loadProducts();
        expect(catalogue.products.single['name'], 'Chaise');
        expect(catalogue.hasMore.value, isFalse);

        final payment = await ApiProvider.post(
          '/v1/wallet/pay',
          body: {'amount': 100},
        );
        expect(payment.success, isFalse);
        expect(
          requests,
          1,
          reason: 'Offline browsing and payments must send no HTTP request.',
        );

        await StorageService.saveAuthSession('B', account(202));
        final otherWallet = await ApiProvider.get('/v1/wallet');
        expect(otherWallet.success, isFalse);
        expect(otherWallet.data, isNull);
        final otherCatalogue = ProductManagementController();
        await otherCatalogue.loadProducts();
        expect(otherCatalogue.products, isEmpty);
        expect(otherCatalogue.lastSyncedAt.value, isNull);

        connectivity.isOnline.value = true;
        await StorageService.saveAuthSession('A2', account(101));
        await wallet.loadWallet();
        expect(wallet.isShowingSnapshot.value, isFalse);
        expect(wallet.isReadOnly, isFalse);
        expect(requests, 2);
      }, () => client);
      Get.delete<ConnectivityService>(force: true);
      Get.delete<WalletService>(force: true);
    },
  );
}
