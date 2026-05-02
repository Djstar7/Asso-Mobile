import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_theme_system.dart';
import '../controllers/otp_controller.dart';

class OtpView extends GetView<OtpController> {
  const OtpView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: context.primaryTextColor,
            size: AppThemeSystem.getFontSize(context, FontSizeType.h5),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.horizontalPadding,
            vertical: context.verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              _buildHeader(context),

              SizedBox(height: context.sectionSpacing),

              // Champs OTP
              _buildOtpFields(context),

              SizedBox(height: context.sectionSpacing),

              // Timer et Renvoyer le code
              _buildTimerSection(context),

              SizedBox(height: context.elementSpacing),

              // Bouton Renvoyer le code (toujours visible)
              _buildResendButton(context),

              SizedBox(height: context.sectionSpacing * 1.5),

              // Bouton de vérification
              _buildVerifyButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// En-tête avec titre et description
  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre
        Text(
          'Vérification OTP',
          style: context.h1.copyWith(
            color: AppThemeSystem.primaryColor,
          ),
        ),

        SizedBox(height: context.elementSpacing),

        // Description avec numéro et bouton modifier
        Obx(() {
          final phoneNumber = controller.phoneNumber.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: context.body1.copyWith(
                    color: context.secondaryTextColor,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Nous avons envoyé un code de vérification sur votre e-mail\n',
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.elementSpacing * 0.75),
              // Bouton pour modifier le numéro
              InkWell(
                onTap: controller.changePhoneNumber,
                borderRadius: context.borderRadius(BorderRadiusType.small),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: AppThemeSystem.getFontSize(
                          context,
                          FontSizeType.caption,
                        ),
                        color: AppThemeSystem.primaryColor,
                      ),
                      SizedBox(width: context.elementSpacing * 0.25),
                      Text(
                        'Modifier mon adresse e-mail',
                        style: context.caption.copyWith(
                          color: AppThemeSystem.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  /// Champs de saisie OTP (6 champs)
  Widget _buildOtpFields(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return _buildOtpField(context, index);
      }),
    );
  }

  /// Un champ OTP individuel
  Widget _buildOtpField(BuildContext context, int index) {
    final deviceType = context.deviceType;

    // Taille adaptative du champ
    double fieldSize;
    double fontSize;
    switch (deviceType) {
      case DeviceType.mobile:
        fieldSize = 50;
        fontSize = 28;
        break;
      case DeviceType.tablet:
        fieldSize = 60;
        fontSize = 32;
        break;
      case DeviceType.largeTablet:
        fieldSize = 68;
        fontSize = 36;
        break;
      case DeviceType.iPadPro13:
        fieldSize = 76;
        fontSize = 40;
        break;
      case DeviceType.desktop:
        fieldSize = 68;
        fontSize = 36;
        break;
    }

    return Container(
      width: fieldSize,
      height: fieldSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: context.borderRadius(BorderRadiusType.medium),
        border: Border.all(
          color: context.borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller.otpControllers[index],
        focusNode: controller.focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: context.primaryTextColor,
          fontFamily: 'SF-Pro',
        ),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: (value) => controller.onOtpChanged(value, index),
      ),
    );
  }

  /// Section Timer
  Widget _buildTimerSection(BuildContext context) {
    return Obx(() {
      final secondsRemaining = controller.secondsRemaining.value;

      if (secondsRemaining == 0) {
        return const SizedBox.shrink();
      }

      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.horizontalPadding * 0.75,
          vertical: context.elementSpacing * 0.75,
        ),
        decoration: BoxDecoration(
          color: AppThemeSystem.primaryColor.withValues(alpha: 0.1),
          borderRadius: context.borderRadius(BorderRadiusType.medium),
          border: Border.all(
            color: AppThemeSystem.primaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              color: AppThemeSystem.primaryColor,
              size: AppThemeSystem.getFontSize(context, FontSizeType.body2),
            ),
            SizedBox(width: context.elementSpacing * 0.5),
            Text(
              'Code valide pendant ${_formatTime(secondsRemaining)}',
              style: context.body2.copyWith(
                color: AppThemeSystem.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Bouton Renvoyer le code (toujours visible)
  Widget _buildResendButton(BuildContext context) {
    return Obx(() {
      final secondsRemaining = controller.secondsRemaining.value;
      final canResend = secondsRemaining == 0;

      return Center(
        child: Column(
          children: [
            if (!canResend)
              Text(
                'Vous n\'avez pas reçu le code ?',
                style: context.body2.copyWith(
                  color: context.secondaryTextColor,
                ),
              ),
            SizedBox(height: context.elementSpacing * 0.5),
            TextButton.icon(
              onPressed: canResend ? controller.resendOtp : null,
              icon: Icon(
                Icons.refresh,
                color: canResend
                    ? AppThemeSystem.primaryColor
                    : context.secondaryTextColor,
                size: AppThemeSystem.getFontSize(context, FontSizeType.h6),
              ),
              label: Text(
                canResend
                    ? 'Renvoyer le code'
                    : 'Renvoyer dans ${_formatTime(secondsRemaining)}',
                style: context.subtitle2.copyWith(
                  color: canResend
                      ? AppThemeSystem.primaryColor
                      : context.secondaryTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: context.horizontalPadding,
                  vertical: context.elementSpacing * 0.75,
                ),
                backgroundColor: canResend
                    ? AppThemeSystem.primaryColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: context.borderRadius(BorderRadiusType.medium),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// Bouton de vérification
  Widget _buildVerifyButton(BuildContext context) {
    return Obx(() {
      final isLoading = controller.isLoading.value;
      final isComplete = controller.isOtpComplete.value;

      return SizedBox(
        width: double.infinity,
        height: context.buttonHeight,
        child: ElevatedButton(
          onPressed: (isComplete && !isLoading) ? controller.verifyOtp : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppThemeSystem.primaryColor,
            foregroundColor: AppThemeSystem.whiteColor,
            disabledBackgroundColor: context.borderColor,
            disabledForegroundColor: context.secondaryTextColor,
            shape: RoundedRectangleBorder(
              borderRadius: context.borderRadius(BorderRadiusType.medium),
            ),
            elevation: context.elevation(ElevationType.low),
          ),
          child: isLoading
              ? SizedBox(
                  height: AppThemeSystem.getFontSize(context, FontSizeType.h5),
                  width: AppThemeSystem.getFontSize(context, FontSizeType.h5),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppThemeSystem.whiteColor,
                    ),
                  ),
                )
              : Text(
                  'Vérifier le code',
                  style: context.button.copyWith(
                    color: AppThemeSystem.whiteColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    });
  }

  /// Formatte le temps en MM:SS
  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
