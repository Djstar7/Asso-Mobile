import '../models/push_preferences.dart';
import 'api_provider.dart';
import 'storage_service.dart';

class NotificationPreferenceProvider {
  static PushPreferences cached() => StorageService.pushPreferences != null
      ? PushPreferences.fromMap(StorageService.pushPreferences!)
      : PushPreferences(
          enabled: StorageService.getPreferences()?['notifications'] != false,
        );

  static Future<PushPreferences?> fetch() async {
    if (!ApiProvider.isAuthenticated) return cached();
    final account = StorageService.getUser()?.id;
    // Honour a disable choice made in an older app when migrating this device.
    if (StorageService.pushPreferences == null &&
        StorageService.getPreferences()?['notifications'] == false) {
      final migrated = await save(PushPreferences(enabled: false));
      if (!migrated) return null;
    }
    final response = await ApiProvider.get('/v1/notifications/preferences');
    if (!response.success || response.data?['preferences'] is! Map) return null;
    if (StorageService.getUser()?.id != account) return null;
    final value = PushPreferences.fromMap(
      Map<String, dynamic>.from(response.data!['preferences']),
    );
    StorageService.savePushPreferences(value.toMap());
    return value;
  }

  static Future<bool> save(PushPreferences value) async {
    final account = StorageService.getUser()?.id;
    if (ApiProvider.isAuthenticated) {
      final response = await ApiProvider.put(
        '/v1/notifications/preferences',
        body: value.toMap(),
      );
      if (!response.success) return false;
    }
    if (StorageService.getUser()?.id != account) return false;
    StorageService.savePushPreferences(value.toMap());
    return true;
  }
}
