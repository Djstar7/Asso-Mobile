import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import 'package:asso/app/data/models/pending_product.dart';
import 'package:asso/app/data/models/user_model.dart';
import 'package:asso/app/data/providers/offline_store.dart';
import 'package:asso/app/data/providers/storage_service.dart';
import 'package:asso/app/data/services/offline_product_sync_service.dart';

/// File des produits créés hors ligne : photos gardées en octets dans Hive,
/// sans fichier, pour que le web et le téléphone suivent le même chemin.
void main() {
  late Directory dir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dir = await Directory.systemTemp.createTemp('offline_queue_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => dir.path,
        );
    await GetStorage.init();
    StorageService.saveUser(UserModel.fromJson({'id': 7, 'name': 'Vendeur'}));
    await OfflineStore.init();
  });

  tearDownAll(() async {
    Get.reset();
    await dir.delete(recursive: true);
  });

  test('la référence se tire sans erreur, même bornée pour le web', () {
    final refs = List.generate(50, (_) => OfflineProductSyncService.newReference());
    expect(refs.toSet(), hasLength(50));
    expect(refs.every((r) => RegExp(r'^\d+_\d+$').hasMatch(r)), isTrue);
  });

  test('une fiche mise en file garde ses photos et se relit', () async {
    final sync = Get.put(OfflineProductSyncService());
    final photo = Uint8List.fromList(List.generate(2048, (i) => i % 256));

    final item = await sync.enqueue(
      fields: {'name': 'tEST DJSTA', 'price': '1', 'currency': 'EUR'},
      images: [XFile.fromData(photo, name: 'photo.png')],
      labels: {'category_name': 'Smartphones & Tablettes'},
      reference: 'ref_1',
    );

    expect(item.id, 'ref_1');
    expect(item.imagePaths.single, startsWith('hive:'));
    expect(await sync.imageBytes(item.imagePaths.single), photo);

    // Relue depuis Hive, comme après un redémarrage de l'application.
    sync.reload();
    final reloaded = sync.pending.single;
    expect(reloaded.fields['name'], 'tEST DJSTA');
    expect(reloaded.status, PendingProductStatus.pending);
    expect(await sync.imageBytes(reloaded.imagePaths.single), photo);

    // Retirée : la fiche et ses photos disparaissent.
    await sync.remove('ref_1');
    expect(sync.pending, isEmpty);
    expect(await sync.imageBytes(item.imagePaths.single), isNull);
  });
}
