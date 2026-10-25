import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/utils/session_scope.dart';

/// Temporary copies for the OS share sheet, kept outside the legacy cache.
class PrivateExports {
  PrivateExports._();
  static const lifetime = Duration(hours: 1);
  static Future<Directory> _root() async =>
      Directory('${(await getTemporaryDirectory()).path}/asso_private_exports');

  static Future<File?> write(String name, List<int> bytes, int session) async {
    if (!SessionScope.isCurrent(session)) return null;
    await cleanup();
    final root = await _root();
    await root.create(recursive: true);
    final directory = await root.createTemp('$session-');
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final file = File('${directory.path}/$safeName');
    await file.writeAsBytes(bytes, flush: true);
    if (!SessionScope.isCurrent(session)) {
      await directory.delete(recursive: true);
      return null;
    }
    return file;
  }

  static Future<void> cleanup({bool all = false, int? retiredSession}) async {
    final root = await _root();
    if (!await root.exists()) return;
    final now = DateTime.now();
    await for (final entry in root.list()) {
      final stat = await entry.stat();
      final name = entry.path.split(Platform.pathSeparator).last;
      if (all ||
          (retiredSession != null && name.startsWith('$retiredSession-')) ||
          now.difference(stat.modified) > lifetime) {
        if (await entry.exists()) await entry.delete(recursive: true);
      }
    }
  }

  /// Delete only known legacy export names, preserving unrelated cache files.
  static Future<void> cleanLegacy() async {
    final directory = await getTemporaryDirectory();
    await for (final entry in directory.list()) {
      final name = entry.path.split(Platform.pathSeparator).last;
      if (entry is File &&
          (RegExp(r'^facture_[A-Za-z0-9_-]+\.pdf$').hasMatch(name) ||
              RegExp(
                r'^statistiques-\d{4}-\d{2}-\d{2}\.(pdf|csv)$',
              ).hasMatch(name))) {
        await entry.delete();
      }
    }
  }
}
