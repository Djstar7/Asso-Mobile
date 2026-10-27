import 'dart:async';

import 'package:asso/app/core/values/constants.dart';
import 'package:asso/app/data/services/connectivity_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'la sonde utilise une route publique accessible sur chaque plateforme',
    () async {
      await http.runWithClient(
        () async {
          final service = ConnectivityService();
          try {
            expect(await service.check(), isTrue);
            expect(service.isOnline.value, isTrue);
          } finally {
            service.onClose();
          }
        },
        () => MockClient((request) async {
          final api = Uri.parse(AppConstants.baseUrl);
          expect(request.method, 'GET');
          expect(request.url.origin, api.origin);
          expect(
            request.url.path,
            kIsWeb ? '${api.path}${AppConstants.versionUrl}' : '/up',
          );
          expect(request.followRedirects, isFalse);
          return http.Response('{"success":true}', 200);
        }),
      );
    },
  );

  for (final status in [302, 401, 404, 405, 429, 500, 503]) {
    test('une réponse $status ne déclenche pas la synchronisation', () async {
      await http.runWithClient(() async {
        final service = ConnectivityService();
        try {
          expect(await service.check(), isFalse);
          expect(service.isOnline.value, isFalse);
        } finally {
          service.onClose();
        }
      }, () => MockClient((_) async => http.Response('', status)));
    });
  }

  test('la sonde détecte le retour du serveur après un échec réseau', () async {
    var reachable = false;
    await http.runWithClient(
      () async {
        final service = ConnectivityService();
        try {
          expect(await service.check(), isFalse);
          reachable = true;
          expect(await service.check(), isTrue);
          expect(service.isOnline.value, isTrue);
        } finally {
          service.onClose();
        }
      },
      () => MockClient((_) async {
        if (!reachable) throw http.ClientException('offline');
        return http.Response('{"success":true}', 200);
      }),
    );
  });

  test('les vérifications simultanées partagent une requête', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    await http.runWithClient(
      () async {
        final service = ConnectivityService();
        try {
          final first = service.check();
          final second = service.check();
          response.complete(http.Response('{"success":true}', 200));
          expect(await Future.wait([first, second]), [true, true]);
          expect(requests, 1);
        } finally {
          service.onClose();
        }
      },
      () => MockClient((_) {
        requests++;
        return response.future;
      }),
    );
  });
}
