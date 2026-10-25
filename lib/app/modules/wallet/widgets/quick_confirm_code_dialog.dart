import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../data/providers/currency_service.dart';
import 'confirm_code_parts.dart';
import '../../../data/providers/diaspo_service.dart';

class QuickConfirmCodeDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const QuickConfirmCodeDialog({super.key, required this.onSuccess});

  @override
  State<QuickConfirmCodeDialog> createState() => _QuickConfirmCodeDialogState();
}

class _QuickConfirmCodeDialogState extends State<QuickConfirmCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final RxBool isSubmitting = false.obs;
  final RxString errorText = ''.obs;
  final diaspoService = Get.find<DiaspoService>();

  @override
  void initState() {
    super.initState();
    // Auto-focus on code input when dialog opens
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _codeFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    if (!mounted || isSubmitting.value) return;
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      errorText.value = 'wallet.confirm_code.code_required'.tr;
      return;
    }
    if (code.length != 6) {
      errorText.value = 'wallet.confirm_code.code_length'.tr;
      return;
    }
    errorText.value = '';

    isSubmitting.value = true;

    try {
      // Call the new endpoint that finds booking by code
      final result = await diaspoService.confirmDeliveryByCode(
        confirmationCode: code,
      );

      if (!mounted) return;
      final onSuccess = widget.onSuccess;
      AppNavigation.closeRoute(context, true);

      // Show success message
      Get.dialog(
        ConfirmCodeSuccessDialog(
          amountLabel: _formatAmount(result.subtotal),
          onClose: () async {
            // Attendre 1 seconde pour laisser le backend traiter la transaction
            await Future.delayed(const Duration(seconds: 1));
            // Call success callback after closing success dialog
            onSuccess();
          },
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      if (!mounted) return;
      isSubmitting.value = false;
      errorText.value = e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Montant pivot (XAF) dans la devise choisie par l'utilisateur.
  String _formatAmount(double amount) =>
      CurrencyService.formatFromPivot(amount);

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: !isSubmitting.value,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDesign.radiusLg),
          ),
          // Seul le contenu défile : les boutons restent au pied du dialogue,
          // au-dessus du clavier, au lieu de disparaître en bas du défilement.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDesign.space6,
                    AppDesign.space6,
                    AppDesign.space6,
                    0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConfirmCodeHeaderIcon(
                        icon: Icons.lock_open_rounded,
                        tone: ToneColors.accent(context),
                      ),
                      const SizedBox(height: AppDesign.space4),
                      Text(
                        'wallet.confirm_code.unlock_funds'.tr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppDesign.textPrimary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDesign.space4),
                      ConfirmCodeNotice(
                        text: 'wallet.confirm_code.enter_client_code'.tr,
                      ),
                      const SizedBox(height: AppDesign.space5),
                      ConfirmCodeField(
                        controller: _codeController,
                        enabled: !isSubmitting.value,
                        errorText: errorText.value.isEmpty
                            ? null
                            : errorText.value,
                        onChanged: (_) => errorText.value = '',
                        focusNode: _codeFocusNode,
                        onSubmitted: _submitCode,
                      ),
                    ],
                  ),
                ),
              ),
              ConfirmCodeActions(
                isSubmitting: isSubmitting,
                onConfirm: _submitCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
