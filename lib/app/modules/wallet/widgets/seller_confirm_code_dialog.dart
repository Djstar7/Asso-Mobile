import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
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
  State<SellerConfirmCodeDialog> createState() => _SellerConfirmCodeDialogState();
}

class _SellerConfirmCodeDialogState extends State<SellerConfirmCodeDialog> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final RxBool isSubmitting = false.obs;
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
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      Get.snackbar(
        'wallet.confirm_code.error'.tr,
        'wallet.confirm_code.code_required'.tr,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return;
    }

    if (code.length != 6) {
      Get.snackbar(
        'wallet.confirm_code.error'.tr,
        'wallet.confirm_code.code_length'.tr,
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
      );
      return;
    }

    isSubmitting.value = true;

    try {
      await diaspoService.sellerConfirmDelivery(
        bookingId: widget.bookingId,
        confirmationCode: code,
      );

      isSubmitting.value = false;

      // Close dialog
      Get.back(result: true);

      // Show success message
      Get.dialog(
        ConfirmCodeSuccessDialog(
          amountLabel: _formatAmount(widget.amount),
          onClose: () => Get.back(),
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      isSubmitting.value = false;
      Get.snackbar(
        'wallet.confirm_code.error'.tr,
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: AppDesign.danger,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Montant pivot (XAF) dans la devise choisie par l'utilisateur.
  String _formatAmount(double amount) => CurrencyService.formatFromPivot(amount);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDesign.radiusLg)),
      // Seul le contenu défile : les boutons restent au pied du dialogue,
      // au-dessus du clavier, au lieu de disparaître en bas du défilement.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppDesign.space6, AppDesign.space6, AppDesign.space6, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConfirmCodeHeaderIcon(icon: Icons.lock_open_rounded, tone: ToneColors.accent(context)),
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
                  ConfirmCodeNotice(text: 'wallet.confirm_code.ask_client_code'.tr),
                  const SizedBox(height: AppDesign.space5),
                  ConfirmCodeField(
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    onSubmitted: _submitCode,
                  ),
                ],
              ),
            ),
          ),
          ConfirmCodeActions(isSubmitting: isSubmitting, onConfirm: _submitCode),
        ],
      ),
    );
  }

  /// Client concerné et montant bloqué pour sa réservation.
  Widget _buildBuyerCard(BuildContext context) {
    final tone = ToneColors.accent(context);
    final name = widget.buyerName.trim();
    return Container(
      padding: const EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(
        color: AppDesign.surface(context),
        borderRadius: BorderRadius.circular(AppDesign.radiusMd),
        border: Border.all(color: AppDesign.border(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: tone.background,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(color: tone.foreground, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppDesign.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'wallet.confirm_code.client'.tr,
                  style: TextStyle(fontSize: 12, color: AppDesign.textSecondary(context)),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppDesign.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDesign.space2),
          Text(
            _formatAmount(widget.amount),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppDesign.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}
