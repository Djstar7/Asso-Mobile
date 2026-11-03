import 'package:get/get.dart';

import '../../../core/utils/app_feedback.dart';
import '../../../core/values/constants.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/web_login_service.dart';

/// Une connexion en attente de confirmation sur le téléphone.
class WebLoginRequest {
  const WebLoginRequest({
    required this.code,
    required this.browser,
    required this.platform,
    required this.ip,
  });

  final String code;
  final String browser;
  final String platform;
  final String ip;
}

/// Une session web active du vendeur.
class WebDevice {
  const WebDevice({
    required this.id,
    required this.browser,
    required this.platform,
    required this.ip,
    required this.expiresAt,
  });

  factory WebDevice.fromJson(Map<String, dynamic> json) => WebDevice(
    id: (json['id'] as num).toInt(),
    browser: json['browser']?.toString() ?? '',
    platform: json['platform']?.toString() ?? '',
    ip: json['ip']?.toString() ?? '',
    expiresAt: DateTime.tryParse(
      json['expires_at']?.toString() ?? '',
    )?.toLocal(),
  );

  final int id;
  final String browser;
  final String platform;
  final String ip;
  final DateTime? expiresAt;
}

class WebLoginController extends GetxController {
  final isLoading = true.obs;
  final isBusy = false.obs;
  final devices = <WebDevice>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadDevices();
  }

  /// Le code d'un QR ASSO, ou null pour tout autre contenu.
  static String? codeFromQr(String raw) {
    final value = raw.trim();
    if (!value.startsWith(AppConstants.webLoginQrPrefix)) return null;
    final code = value.substring(AppConstants.webLoginQrPrefix.length);
    return RegExp(r'^[A-Za-z0-9]{32,128}$').hasMatch(code) ? code : null;
  }

  Future<void> loadDevices() async {
    isLoading.value = true;
    try {
      final response = await WebLoginService.devices();
      final list = response.data?['sessions'];
      if (response.success && list is List) {
        devices.assignAll(
          list.whereType<Map>().map(
            (d) => WebDevice.fromJson(Map<String, dynamic>.from(d)),
          ),
        );
      } else if (!response.success) {
        _showFailure(response);
      }
    } finally {
      isLoading.value = false;
    }
  }

  /// Signale le QR au serveur ; renvoie la demande à faire confirmer.
  Future<WebLoginRequest?> scan(String raw) async {
    final code = codeFromQr(raw);
    if (code == null) {
      AppFeedback.show(
        'web_login.invalid_qr_title'.tr,
        'web_login.invalid_qr_message'.tr,
      );
      return null;
    }

    isBusy.value = true;
    try {
      final response = await WebLoginService.scan(code);
      final session = response.data?['session'];
      if (!response.success || session is! Map) {
        _showFailure(response);
        return null;
      }
      return WebLoginRequest(
        code: code,
        browser: session['browser']?.toString() ?? '',
        platform: session['platform']?.toString() ?? '',
        ip: session['ip']?.toString() ?? '',
      );
    } finally {
      isBusy.value = false;
    }
  }

  Future<bool> approve(WebLoginRequest request) async {
    isBusy.value = true;
    try {
      final response = await WebLoginService.approve(request.code);
      if (!response.success) {
        _showFailure(response);
        return false;
      }
      AppFeedback.show(
        'web_login.approved_title'.tr,
        'web_login.approved_message'.tr,
      );
      await loadDevices();
      return true;
    } finally {
      isBusy.value = false;
    }
  }

  Future<void> reject(WebLoginRequest request) async {
    final response = await WebLoginService.reject(request.code);
    if (!response.success) _showFailure(response);
  }

  Future<void> revoke(WebDevice device) async {
    isBusy.value = true;
    try {
      final response = await WebLoginService.revokeDevice(device.id);
      if (!response.success) {
        _showFailure(response);
        return;
      }
      devices.removeWhere((d) => d.id == device.id);
      AppFeedback.show(
        'web_login.revoked_title'.tr,
        'web_login.revoked_message'.tr,
      );
    } finally {
      isBusy.value = false;
    }
  }

  void _showFailure(ApiResponse response) {
    AppFeedback.show(
      'web_login.failed_title'.tr,
      response.message.isEmpty
          ? 'web_login.failed_message'.tr
          : response.message,
    );
  }
}
