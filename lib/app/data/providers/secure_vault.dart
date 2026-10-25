import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Values never fall back to plaintext if the platform vault is unavailable.
class SecureVault {
  SecureVault._();
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  static Future<void> _tail = Future.value();
  static Future<void> write(String key, String? value) {
    final operation = _tail.then(
      (_) => value == null
          ? storage.delete(key: key)
          : storage.write(key: key, value: value),
    );
    // The caller can await the error; a later logout must still be able to run.
    _tail = operation.catchError((Object _) {});
    return operation;
  }
}
