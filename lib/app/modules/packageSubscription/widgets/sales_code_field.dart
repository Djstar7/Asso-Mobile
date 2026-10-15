import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/sales_code_service.dart';

enum SalesCodeStatus { empty, unverified, checking, valid, invalid }

typedef SalesCodeCheck = Future<ApiResponse> Function(String code);
typedef OwnSalesCodeConfirm = Future<bool> Function(String warning);

/// État du champ « Code commercial / Code de parrainage » (P6), détenu par le
/// contrôleur de l'écran de souscription (forfaits de stockage, certification).
///
/// Le code est facultatif ; s'il est saisi, il doit être vérifié avant le paiement
/// pour que la vente soit bien attribuée au commercial.
class SalesCodeInput {
  SalesCodeInput({SalesCodeCheck? checkCode, OwnSalesCodeConfirm? confirmOwnCode})
      : _checkCode = checkCode ?? SalesCodeService.checkCode,
        _confirmOwnCode = confirmOwnCode ?? showOwnSalesCodeDialog;

  final SalesCodeCheck _checkCode;
  final OwnSalesCodeConfirm _confirmOwnCode;

  final textController = TextEditingController();
  final status = SalesCodeStatus.empty.obs;
  final agentName = ''.obs;
  final errorMessage = ''.obs;

  /// Le code ne vaut que pour le premier abonnement payant : le serveur
  /// l'indique par `can_use_sales_code`, et le champ disparaît sinon.
  final available = true.obs;

  /// Avertissement affiché pendant que le vendeur décide s'il garde son
  /// propre code (vide hors confirmation).
  final pendingOwnCodeWarning = ''.obs;

  /// Le vendeur garde son propre code : l'abonnement passe, sans commission.
  final ownCodeAccepted = false.obs;

  bool _ownCodeDeclined = false;

  String get _typed => textController.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// Code à envoyer au serveur : uniquement s'il a été vérifié.
  String? get code =>
      available.value && status.value == SalesCodeStatus.valid ? _typed : null;

  /// À envoyer avec le code (`accept_own_code`) quand le vendeur a confirmé
  /// utiliser le sien.
  bool get acceptOwnCode => code != null && ownCodeAccepted.value;

  /// Lit `can_use_sales_code` dans une réponse forfaits ; absent, le champ
  /// reste proposé (serveur antérieur). Un code déjà saisi est alors effacé.
  void applyEligibility(Map<String, dynamic>? body) {
    final allowed = body?['can_use_sales_code'];
    if (allowed is! bool) return;
    available.value = allowed;
    if (!allowed) clear();
  }

  void onChanged(String _) {
    agentName.value = '';
    errorMessage.value = '';
    ownCodeAccepted.value = false;
    status.value = _typed.isEmpty ? SalesCodeStatus.empty : SalesCodeStatus.unverified;
  }

  void clear() {
    textController.clear();
    onChanged('');
  }

  /// Vérifie le code saisi auprès du serveur. Renvoie true s'il est valide.
  Future<bool> verify() async {
    final typed = _typed;
    _ownCodeDeclined = false;
    if (typed.isEmpty) {
      status.value = SalesCodeStatus.empty;
      return true;
    }
    if (status.value == SalesCodeStatus.checking) return false;

    status.value = SalesCodeStatus.checking;
    errorMessage.value = '';
    ownCodeAccepted.value = false;
    try {
      final response = await _checkCode(typed);
      if (_typed != typed) return false; // le texte a changé pendant l'appel

      if (response.success) {
        final data = response.data?['data'];
        agentName.value = '${data is Map ? data['agent_display_name'] ?? '' : ''}';
        if (data is Map && data['is_own_code'] == true) {
          return _confirmOwn(typed, data['warning']?.toString());
        }
        status.value = SalesCodeStatus.valid;
        return true;
      }
      if (response.statusCode == 0 || response.statusCode >= 500 || response.statusCode == 429) {
        // Pas de réponse exploitable : on laisse l'utilisateur réessayer.
        errorMessage.value = response.statusCode == 429
            ? 'package_subscription.sales_code.too_many_attempts'.tr
            : 'package_subscription.sales_code.verify_unavailable'.tr;
        status.value = SalesCodeStatus.unverified;
        return false;
      }
      errorMessage.value = response.message.isNotEmpty && response.message != 'Erreur'
          ? response.message
          : 'package_subscription.sales_code.invalid'.tr;
      status.value = SalesCodeStatus.invalid;
      return false;
    } catch (_) {
      errorMessage.value = 'package_subscription.sales_code.verify_unavailable'.tr;
      status.value = SalesCodeStatus.unverified;
      return false;
    }
  }

  /// Son propre code n'est pas refusé : le vendeur choisit de continuer sans
  /// commission, ou de le modifier (le champ reste alors à vérifier).
  Future<bool> _confirmOwn(String typed, String? warning) async {
    final message = warning != null && warning.trim().isNotEmpty
        ? warning
        : 'package_subscription.sales_code.own_code.message'.tr;
    pendingOwnCodeWarning.value = message;
    bool accepted;
    try {
      accepted = await _confirmOwnCode(message);
    } finally {
      pendingOwnCodeWarning.value = '';
    }
    if (_typed != typed) return false;
    if (accepted) {
      ownCodeAccepted.value = true;
      status.value = SalesCodeStatus.valid;
      return true;
    }
    _ownCodeDeclined = true;
    ownCodeAccepted.value = false;
    status.value = SalesCodeStatus.unverified;
    return false;
  }

  /// À appeler avant d'ouvrir le paiement. Vérifie le code s'il ne l'est pas encore
  /// et bloque (avec message) tant qu'un code saisi n'est pas valide.
  Future<bool> ensureReady() async {
    if (!available.value) return true;
    switch (status.value) {
      case SalesCodeStatus.empty:
      case SalesCodeStatus.valid:
        return true;
      case SalesCodeStatus.checking:
        return false;
      case SalesCodeStatus.unverified:
      case SalesCodeStatus.invalid:
        if (await verify()) return true;
        // « Modifier le code » est un choix, pas une erreur à signaler.
        if (!_ownCodeDeclined) _warn();
        return false;
    }
  }

  /// Traite un refus du serveur (422 invalid_sales_code ou own_sales_code).
  /// Renvoie true si c'en était un. Un 422 ne crée rien : après confirmation
  /// de son propre code, le vendeur relance simplement le paiement.
  bool handleServerRejection(ApiResponse response) {
    final code = response.data?['code'];
    if (code == 'own_sales_code') {
      _confirmAfterRejection(response.message);
      return true;
    }
    if (code != 'invalid_sales_code') return false;
    agentName.value = '';
    errorMessage.value = response.message;
    status.value = SalesCodeStatus.invalid;
    _warn();
    return true;
  }

  Future<void> _confirmAfterRejection(String warning) async {
    final typed = _typed;
    if (typed.isEmpty) return;
    if (!await _confirmOwn(typed, warning)) return;
    Get.snackbar(
      'package_subscription.sales_code.own_code.title'.tr,
      'package_subscription.sales_code.own_code.retry'.tr,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void _warn() {
    Get.snackbar(
      'package_subscription.sales_code.title'.tr,
      errorMessage.value.isNotEmpty
          ? 'package_subscription.sales_code.warn_with_error'.trParams({'error': errorMessage.value})
          : 'package_subscription.sales_code.warn'.tr,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppDesign.danger,
      colorText: AppDesign.neutral0,
      duration: const Duration(seconds: 5),
    );
  }

  void dispose() => textController.dispose();
}

/// Demande au vendeur s'il garde son propre code (aucune commission) ou le
/// modifie. Renvoie true pour continuer.
Future<bool> showOwnSalesCodeDialog(String warning) async {
  final accepted = await Get.dialog<bool>(
    AlertDialog(
      title: Text('package_subscription.sales_code.own_code.title'.tr),
      content: Text(warning),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: Text('package_subscription.sales_code.own_code.edit'.tr),
        ),
        TextButton(
          onPressed: () => Get.back(result: true),
          style: TextButton.styleFrom(foregroundColor: AppDesign.accent),
          child: Text('package_subscription.sales_code.own_code.continue'.tr),
        ),
      ],
    ),
  );
  return accepted == true;
}

/// Champ facultatif « Code commercial / Code de parrainage » avec bouton Vérifier.
class SalesCodeField extends StatelessWidget {
  final SalesCodeInput input;

  const SalesCodeField({super.key, required this.input});

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    return Container(
      padding: EdgeInsets.all(AppDesign.space5),
      decoration: BoxDecoration(
        color: ds.surface,
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
        border: Border.all(color: ds.border),
      ),
      child: Obx(() {
        final status = input.status.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'package_subscription.sales_code.title'.tr,
              style: context.subtitle2.copyWith(
                fontWeight: FontWeight.w600,
                color: ds.textPrimary,
              ),
            ),
            SizedBox(height: AppDesign.space1),
            Text(
              'package_subscription.sales_code.subtitle'.tr,
              style: context.body2.copyWith(color: ds.textSecondary),
            ),
            SizedBox(height: AppDesign.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: input.textController,
                    onChanged: input.onChanged,
                    onSubmitted: (_) => input.verify(),
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    maxLength: 32,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                      _UpperCaseFormatter(),
                    ],
                    style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'package_subscription.sales_code.hint'.tr,
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: ds.surfaceMuted,
                      errorText: status == SalesCodeStatus.invalid ||
                              (status == SalesCodeStatus.unverified && input.errorMessage.isNotEmpty)
                          ? input.errorMessage.value
                          : null,
                      errorMaxLines: 3,
                      suffixIcon: status == SalesCodeStatus.empty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'package_subscription.sales_code.clear'.tr,
                              onPressed: input.clear,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 46,
                  width: 104,
                  child: ElevatedButton(
                    onPressed: status == SalesCodeStatus.unverified || status == SalesCodeStatus.invalid
                        ? input.verify
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppDesign.accent,
                      foregroundColor: AppDesign.neutral0,
                      disabledBackgroundColor: ds.surfaceMuted,
                      disabledForegroundColor: ds.textTertiary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
                      ),
                    ),
                    child: status == SalesCodeStatus.checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppDesign.neutral0),
                          )
                        : Text('package_subscription.sales_code.verify'.tr),
                  ),
                ),
              ],
            ),
            if (status == SalesCodeStatus.valid && input.ownCodeAccepted.value) ...[
              const SizedBox(height: 8),
              // Information, pas une erreur : l'abonnement passe sans commission.
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: ds.textSecondary),
                  SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Text(
                      'package_subscription.sales_code.own_code.helper'.tr,
                      style: context.body2.copyWith(color: ds.textSecondary),
                    ),
                  ),
                ],
              ),
            ] else if (status == SalesCodeStatus.valid) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 16, color: AppDesign.successText),
                  SizedBox(width: AppDesign.space2),
                  Expanded(
                    child: Text(
                      input.agentName.value.isNotEmpty
                          ? 'package_subscription.sales_code.valid_with_agent'.trParams({'name': input.agentName.value})
                          : 'package_subscription.sales_code.valid'.tr,
                      style: context.body2.copyWith(color: AppDesign.successText),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
