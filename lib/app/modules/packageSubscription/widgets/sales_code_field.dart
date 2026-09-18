import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../data/providers/api_provider.dart';
import '../../../data/providers/sales_code_service.dart';

enum SalesCodeStatus { empty, unverified, checking, valid, invalid }

/// État du champ « Code commercial / Code de parrainage » (P6), détenu par le
/// contrôleur de l'écran de souscription (forfaits de stockage, certification).
///
/// Le code est facultatif ; s'il est saisi, il doit être vérifié avant le paiement
/// pour que la vente soit bien attribuée au commercial.
class SalesCodeInput {
  final textController = TextEditingController();
  final status = SalesCodeStatus.empty.obs;
  final agentName = ''.obs;
  final errorMessage = ''.obs;

  String get _typed => textController.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// Code à envoyer au serveur : uniquement s'il a été vérifié.
  String? get code => status.value == SalesCodeStatus.valid ? _typed : null;

  void onChanged(String _) {
    agentName.value = '';
    errorMessage.value = '';
    status.value = _typed.isEmpty ? SalesCodeStatus.empty : SalesCodeStatus.unverified;
  }

  void clear() {
    textController.clear();
    onChanged('');
  }

  /// Vérifie le code saisi auprès du serveur. Renvoie true s'il est valide.
  Future<bool> verify() async {
    final typed = _typed;
    if (typed.isEmpty) {
      status.value = SalesCodeStatus.empty;
      return true;
    }
    if (status.value == SalesCodeStatus.checking) return false;

    status.value = SalesCodeStatus.checking;
    errorMessage.value = '';
    try {
      final response = await SalesCodeService.checkCode(typed);
      if (_typed != typed) return false; // le texte a changé pendant l'appel

      if (response.success) {
        agentName.value = '${response.data?['data']?['agent_display_name'] ?? ''}';
        status.value = SalesCodeStatus.valid;
        return true;
      }
      if (response.statusCode == 0 || response.statusCode >= 500 || response.statusCode == 429) {
        // Pas de réponse exploitable : on laisse l'utilisateur réessayer.
        errorMessage.value = response.statusCode == 429
            ? 'Trop de tentatives. Réessayez dans une minute.'
            : 'Vérification impossible pour le moment. Réessayez.';
        status.value = SalesCodeStatus.unverified;
        return false;
      }
      errorMessage.value = response.message.isNotEmpty && response.message != 'Erreur'
          ? response.message
          : "Ce code commercial n'existe pas ou n'est plus actif.";
      status.value = SalesCodeStatus.invalid;
      return false;
    } catch (_) {
      errorMessage.value = 'Vérification impossible pour le moment. Réessayez.';
      status.value = SalesCodeStatus.unverified;
      return false;
    }
  }

  /// À appeler avant d'ouvrir le paiement. Vérifie le code s'il ne l'est pas encore
  /// et bloque (avec message) tant qu'un code saisi n'est pas valide.
  Future<bool> ensureReady() async {
    switch (status.value) {
      case SalesCodeStatus.empty:
      case SalesCodeStatus.valid:
        return true;
      case SalesCodeStatus.checking:
        return false;
      case SalesCodeStatus.unverified:
      case SalesCodeStatus.invalid:
        if (await verify()) return true;
        _warn();
        return false;
    }
  }

  /// Traite un refus du serveur (422 invalid_sales_code). Renvoie true si c'en était un.
  bool handleServerRejection(ApiResponse response) {
    if (response.data?['code'] != 'invalid_sales_code') return false;
    agentName.value = '';
    errorMessage.value = response.message;
    status.value = SalesCodeStatus.invalid;
    _warn();
    return true;
  }

  void _warn() {
    Get.snackbar(
      'Code commercial',
      errorMessage.value.isNotEmpty
          ? '${errorMessage.value} Corrigez-le ou videz le champ pour continuer.'
          : 'Vérifiez le code commercial ou videz le champ pour continuer.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppThemeSystem.errorColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 5),
    );
  }

  void dispose() => textController.dispose();
}

/// Champ facultatif « Code commercial / Code de parrainage » avec bouton Vérifier.
class SalesCodeField extends StatelessWidget {
  final SalesCodeInput input;

  const SalesCodeField({super.key, required this.input});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Obx(() {
        final status = input.status.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, size: 20, color: AppThemeSystem.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Code commercial / Code de parrainage',
                    style: context.subtitle2.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "Facultatif. Si un commercial ASSO vous a accompagné, saisissez son code.",
              style: context.caption.copyWith(color: context.secondaryTextColor),
            ),
            const SizedBox(height: 12),
            Row(
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
                      hintText: 'Ex. ASSO-7K3Q9',
                      counterText: '',
                      isDense: true,
                      filled: true,
                      fillColor: context.inputFieldColor,
                      errorText: status == SalesCodeStatus.invalid ||
                              (status == SalesCodeStatus.unverified && input.errorMessage.isNotEmpty)
                          ? input.errorMessage.value
                          : null,
                      errorMaxLines: 3,
                      suffixIcon: status == SalesCodeStatus.empty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Effacer',
                              onPressed: input.clear,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: status == SalesCodeStatus.unverified || status == SalesCodeStatus.invalid
                        ? input.verify
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppThemeSystem.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: status == SalesCodeStatus.checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Vérifier'),
                  ),
                ),
              ],
            ),
            if (status == SalesCodeStatus.valid) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: AppThemeSystem.successColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      input.agentName.value.isNotEmpty
                          ? 'Code valide — commercial : ${input.agentName.value}'
                          : 'Code valide',
                      style: context.body2.copyWith(color: AppThemeSystem.successColor),
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
