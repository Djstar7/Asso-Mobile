import 'dart:convert';
import 'dart:io';
import 'package:asso/app/core/i18n/app_translations.dart';
import 'package:asso/app/data/models/push_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'master disable suppresses all categories while preserving category choices',
    () {
      final initial = PushPreferences(categories: {'marketing': false});
      final off = initial.copyWith(enabled: false);
      for (final category in PushPreferences.categoryKeys) {
        expect(off.allows(category), isFalse);
      }
      final on = off.copyWith(enabled: true);
      expect(on.allows('orders'), isTrue);
      expect(on.allows('marketing'), isFalse);
      expect(PushPreferences.fromMap(on.toMap()).categories, on.categories);
    },
  );

  test(
    'older payloads default to enabled and unknown categories cannot enable a push',
    () {
      final value = PushPreferences.fromMap({});
      expect(value.enabled, isTrue);
      expect(value.categories.length, 7);
      expect(value.allows('unknown_category'), isFalse);
      final selected = value.copyWith(category: 'orders', allowed: false);
      expect(selected.allows('orders'), isFalse);
      expect(selected.allows('payments'), isTrue);
    },
  );

  test(
    'personal events and promotional summaries use the server category contract',
    () {
      const expected = {
        'order_control_window': 'orders',
        'new_order_vendor': 'orders',
        'wholesale_order_created': 'orders',
        'wallet_credit': 'payments',
        'new_message': 'messages',
        'dispute_resolution_reminder': 'disputes',
        'real_estate_dispute_opened': 'disputes',
        'real_estate_reservation_paid': 'real_estate',
        'real_estate_alert': 'real_estate',
        'new_product': 'marketing',
        'marketing_digest': 'marketing',
        'test': 'system',
      };
      for (final entry in expected.entries) {
        expect(PushPreferences.categoryFor(entry.key), entry.value);
      }
    },
  );

  test(
    'new notification texts exist in French and English with matching parameters',
    () {
      final fr =
          jsonDecode(File('assets/i18n/fr.json').readAsStringSync())
              as Map<String, dynamic>;
      final en =
          jsonDecode(File('assets/i18n/en.json').readAsStringSync())
              as Map<String, dynamic>;
      final french = AppTranslations.flatten(fr);
      final english = AppTranslations.flatten(en);
      final keys = french.keys
          .where(
            (key) =>
                key.startsWith('notification.channels.') ||
                key.startsWith('notification.digest.') ||
                key.startsWith('settings.notifications.diagnostics.') ||
                key.startsWith('settings.notifications.categories.') ||
                [
                  'settings.notifications.saved',
                  'settings.notifications.save_failed',
                  'settings.notifications.daily_summary',
                ].contains(key),
          )
          .toSet();
      final englishKeys = english.keys
          .where(
            (key) =>
                key.startsWith('notification.channels.') ||
                key.startsWith('notification.digest.') ||
                key.startsWith('settings.notifications.diagnostics.') ||
                key.startsWith('settings.notifications.categories.') ||
                [
                  'settings.notifications.saved',
                  'settings.notifications.save_failed',
                  'settings.notifications.daily_summary',
                ].contains(key),
          )
          .toSet();
      expect(keys, englishKeys);
      for (final key in keys) {
        expect(french[key]!.trim(), isNotEmpty, reason: key);
        expect(english[key]!.trim(), isNotEmpty, reason: key);
        Set<String> placeholders(String text) =>
            RegExp(r'@([A-Za-z_]+)').allMatches(text).map((m) => m[1]!).toSet();
        expect(
          placeholders(french[key]!),
          placeholders(english[key]!),
          reason: key,
        );
      }
    },
  );

  test(
    'native configuration enables iOS relay and uses a dedicated transparent Android small icon',
    () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        RegExp(
          r'<key>FirebaseAppDelegateProxyEnabled</key>\s*<true/>',
        ).hasMatch(plist),
        isTrue,
      );
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:resource="@drawable/ic_stat_asso"'));
      final vector = File(
        'android/app/src/main/res/drawable/ic_stat_asso.xml',
      ).readAsStringSync();
      expect(vector, contains('@android:color/transparent'));
      expect(vector, contains('#FFFFFFFF'));
      expect(
        File(
          'android/app/src/main/res/drawable/asso_notification_logo.png',
        ).existsSync(),
        isTrue,
      );
    },
  );
}
