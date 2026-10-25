import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../data/providers/currency_service.dart';
import 'confirm_code_parts.dart';
import '../../../data/providers/diaspo_service.dart';

class SellerConfirmCodeDialog extends StatefulWidget {
  final int bookingId;
  final double amount;
  final String buyerName;

  const SellerConfirmCodeDialog({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.buyerName,
  });

  @override
  State<SellerConfirmCodeDialog> createState() =>
      _SellerConfirmCodeDialogState();
}

class _SellerConfirmCodeDialogState extends State<SellerConfirmCodeDialog> {
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
      await diaspoService.sellerConfirmDelivery(
        bookingId: widget.bookingId,
        confirmationCode: code,
      );

      if (!mounted) return;
      AppNavigation.closeRoute(context, true);

      // Show success message
      Get.dialog(
        ConfirmCodeSuccessDialog(
          amountLabel: _formatAmount(widget.amount),
          onClose: () {},
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
                        'wallet.confirm_code.confirm_delivery'.tr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppDesign.textPrimary(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDesign.space4),
                      _buildBuyerCard(context),
                      const SizedBox(height: AppDesign.space3),
                      ConfirmCodeNotice(
                        text: 'wallet.confirm_code.ask_client_code'.tr,
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

  /// Client concerné et montant bloqué pour sa réservation.
  Widget _buildBuyerCard(BuildContext context) {
    final tone = ToneColors.accent(context);
    final name = widget.buyerName.trim();
    return AppCard(
      elevated: false,
      padding: const EdgeInsets.all(AppDesign.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: tone.background,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: TextStyle(
                    color: tone.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppDesign.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'wallet.confirm_code.client'.tr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.space2),
          Text(
            _formatAmount(widget.amount),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
