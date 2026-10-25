import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/utils/semantic_tone.dart';
export '../../../core/utils/semantic_tone.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/widgets/app_ui.dart';
import '../../../core/utils/app_theme_system.dart';

/// Pastille ronde d'en-tête de dialogue.
class ConfirmCodeHeaderIcon extends StatelessWidget {
  final IconData icon;
  final ToneColors tone;

  const ConfirmCodeHeaderIcon({
    super.key,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: tone.background, shape: BoxShape.circle),
      child: Icon(icon, color: tone.foreground, size: 30),
    );
  }
}

/// Encadré d'explication sous le titre.
class ConfirmCodeNotice extends StatelessWidget {
  final String text;

  const ConfirmCodeNotice({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final tone = ToneColors.info(context);
    return Container(
      padding: const EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
        border: Border.all(color: tone.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: tone.foreground, size: 18),
          const SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: tone.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Champ de saisie du code de confirmation (6 caractères A-Z / 0-9).
class ConfirmCodeField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onSubmitted;

  const ConfirmCodeField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });

  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDesign.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );

    return TextField(
      enabled: enabled,
      onChanged: onChanged,
      controller: controller,
      focusNode: focusNode,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: MediaQuery.textScalerOf(context).scale(26) > 32 ? 1 : 4,
        color: AppDesign.textPrimary(context),
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      keyboardType: TextInputType.text,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      maxLength: 6,
      inputFormatters: [
        TextInputFormatter.withFunction(
          (oldValue, newValue) =>
              newValue.copyWith(text: newValue.text.toUpperCase()),
        ),
        FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
      ],
      decoration: InputDecoration(
        hintText: '······',
        hintStyle: TextStyle(
          fontSize: 26,
          letterSpacing: MediaQuery.textScalerOf(context).scale(26) > 32
              ? 1
              : 4,
          color: AppDesign.textTertiary(context),
        ),
        filled: true,
        fillColor: AppDesign.surfaceMuted(context),
        counterText: '',
        errorText: errorText,
        errorMaxLines: 4,
        errorStyle: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppDesign.danger),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
        border: outline(AppDesign.borderStrong(context), 1),
        enabledBorder: outline(AppDesign.borderStrong(context), 1),
        focusedBorder: outline(AppThemeSystem.primaryColor, 2),
      ),
    );
  }
}

/// Boutons Annuler / Confirmer au pied du dialogue.
class ConfirmCodeActions extends StatelessWidget {
  final RxBool isSubmitting;
  final VoidCallback onConfirm;

  const ConfirmCodeActions({
    super.key,
    required this.isSubmitting,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDesign.space6),
      child: Obx(() {
        final submitting = isSubmitting.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            final cancel = AppButton(
              label: 'wallet.confirm_code.cancel'.tr,
              variant: AppButtonVariant.secondary,
              onPressed: submitting
                  ? null
                  : () => AppNavigation.closeRoute(context),
            );
            final confirm = AppButton(
              label: 'wallet.confirm_code.confirm'.tr,
              onPressed: onConfirm,
              isLoading: submitting,
            );
            if (constraints.maxWidth < 320 ||
                MediaQuery.textScalerOf(context).scale(15) > 20) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  confirm,
                  const SizedBox(height: AppDesign.space2),
                  cancel,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: cancel),
                const SizedBox(width: AppDesign.space3),
                Expanded(flex: 2, child: confirm),
              ],
            );
          },
        );
      }),
    );
  }
}

/// Dialogue de succès : fonds débloqués, montant crédité.
class ConfirmCodeSuccessDialog extends StatelessWidget {
  final String amountLabel;
  final VoidCallback onClose;

  const ConfirmCodeSuccessDialog({
    super.key,
    required this.amountLabel,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final tone = ToneColors.success(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesign.radiusLg),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDesign.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConfirmCodeHeaderIcon(icon: Icons.check_rounded, tone: tone),
            const SizedBox(height: AppDesign.space4),
            Text(
              'wallet.confirm_code.delivery_confirmed'.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppDesign.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesign.space2),
            Text(
              'wallet.confirm_code.funds_available'.tr,
              style: TextStyle(
                fontSize: 14,
                color: AppDesign.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDesign.space5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppDesign.space4),
              decoration: BoxDecoration(
                color: tone.background,
                borderRadius: BorderRadius.circular(AppDesign.radiusMd),
              ),
              child: Text(
                '+$amountLabel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: tone.foreground,
                ),
              ),
            ),
            const SizedBox(height: AppDesign.space5),
            ElevatedButton(
              onPressed: () {
                AppNavigation.closeRoute(context);
                onClose();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                foregroundColor: AppThemeSystem.whiteColor,
                elevation: 0,
                minimumSize: const Size(
                  double.infinity,
                  AppDesign.minTapTarget,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                ),
              ),
              child: Text('wallet.confirm_code.close'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
