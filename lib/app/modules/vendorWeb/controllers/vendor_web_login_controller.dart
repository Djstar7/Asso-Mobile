import 'dart:async';

import 'package:get/get.dart';

import '../../../core/values/constants.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/storage_service.dart';
import '../../../data/providers/web_login_service.dart';
import '../../../routes/app_pages.dart';

enum VendorWebLoginStep { loading, showQr, scanned, expired, failed }

/// Côté site : affiche le QR, le renouvelle et attend le scan du téléphone.
class VendorWebLoginController extends GetxController {
  /// QR renouvelés sans action avant de demander un clic, soit environ 10 min :
  /// un onglet oublié ne crée pas de sessions sans fin.
  static const int _maxAutoRenewals = 5;

  final step = VendorWebLoginStep.loading.obs;
  final qr = ''.obs;

  String? _id;
  String? _secret;
  Timer? _poll;
  bool _polling = false;
  int _renewals = 0;

  @override
  void onInit() {
    super.onInit();
    start();
  }

  /// Nouveau QR demandé par le vendeur.
  Future<void> start() {
    _renewals = 0;
    return _createSession();
  }

  /// Nouvelle session de connexion, donc nouveau QR.
  Future<void> _createSession() async {
    _poll?.cancel();
    step.value = VendorWebLoginStep.loading;

    final response = await WebLoginService.createSession();
    final session = response.data?['session'];
    if (isClosed) return;
    if (!response.success || session is! Map) {
      step.value = VendorWebLoginStep.failed;
      return;
    }

    _id = session['id']?.toString();
    _secret = session['secret']?.toString();
    qr.value = session['qr']?.toString() ?? '';
    step.value = VendorWebLoginStep.showQr;

    final seconds = (session['poll_interval'] as num?)?.toInt() ?? 2;
    _poll = Timer.periodic(Duration(seconds: seconds), (_) => _check());
  }

  Future<void> _check() async {
    final id = _id;
    final secret = _secret;
    if (_polling || id == null || secret == null) return;

    _polling = true;
    try {
      final response = await WebLoginService.pollSession(id, secret);
      if (isClosed) return;
      // Coupure passagère : on continue d'interroger jusqu'à l'expiration.
      if (!response.success) {
        if (response.statusCode == 404 || response.statusCode == 403) {
          await _renewOrStop();
        }
        return;
      }

      switch (response.data?['status']) {
        case 'scanned':
          step.value = VendorWebLoginStep.scanned;
        case 'approved':
          await _signIn(response.data!);
        case 'expired':
          await _renewOrStop();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _signIn(Map<String, dynamic> body) async {
    _poll?.cancel();
    final token = body['token']?.toString();
    final user = body['user'];
    if (token == null || user is! Map) {
      step.value = VendorWebLoginStep.failed;
      return;
    }
    await StorageService.saveAuthSession(
      token,
      UserModel.fromJson(Map<String, dynamic>.from(user)),
    );
    _secret = null;
    Get.offAllNamed(Routes.VENDOR_DASHBOARD);
  }

  Future<void> _renewOrStop() async {
    _poll?.cancel();
    if (_renewals >= _maxAutoRenewals) {
      step.value = VendorWebLoginStep.expired;
      return;
    }
    _renewals++;
    await _createSession();
  }

  /// Contenu attendu du QR, vérifié par l'application qui le lit.
  bool get hasValidQr => qr.value.startsWith(AppConstants.webLoginQrPrefix);

  @override
  void onClose() {
    _poll?.cancel();
    super.onClose();
  }
}
