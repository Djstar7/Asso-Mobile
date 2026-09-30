import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import 'app_ui.dart';

/// Livraison gratuite offerte par le vendeur (boutique entière ou produit).
///
/// L'acheteur voit toujours le prix de la course, barré : il sait ce qu'on lui
/// offre. Le vendeur finance ce prix sur sa vente.

/// Lit le drapeau `free_delivery` renvoyé par l'API (bool, 0/1, "true").
bool readFreeDelivery(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  if (value is String) return value == '1' || value.toLowerCase() == 'true';
  return false;
}

/// Étiquette « Livraison gratuite » des fiches produit.
class FreeDeliveryBadge extends StatelessWidget {
  const FreeDeliveryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: 'core.free_delivery.title'.tr,
      tone: AppBadgeTone.success,
      icon: Icons.local_shipping_rounded,
    );
  }
}

/// Bandeau d'une commande dont la course a été offerte par le vendeur.
class FreeDeliveryNotice extends StatelessWidget {
  const FreeDeliveryNotice({super.key, required this.price, this.message});

  final String price;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesign.space3),
      decoration: BoxDecoration(
        color: AppDesign.successSubtle,
        borderRadius: BorderRadius.circular(AppDesign.radiusSm),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            size: 18,
            color: AppDesign.success,
          ),
          const SizedBox(width: AppDesign.space2),
          Expanded(
            child: Text(
              message ?? 'core.free_delivery.offered_by_seller'.tr,
              style: context.textStyle(
                FontSizeType.body2,
                fontWeight: FontWeight.w600,
                color: AppDesign.successText,
              ),
            ),
          ),
          DeliveryPriceText(
            price: price,
            isFree: true,
            style: context.textStyle(
              FontSizeType.body2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Prix d'une course. Offerte, il reste affiché mais barré, suivi de
/// « Offerte ».
class DeliveryPriceText extends StatelessWidget {
  const DeliveryPriceText({
    super.key,
    required this.price,
    required this.isFree,
    this.style,
    this.alignEnd = true,
  });

  final String price;
  final bool isFree;
  final TextStyle? style;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final base =
        style ??
        context.textStyle(
          FontSizeType.body1,
          fontWeight: FontWeight.bold,
          color: AppThemeSystem.primaryColor,
        );
    if (!isFree) return Text(price, style: base);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          price,
          style: base.copyWith(
            color: context.ds.textTertiary,
            decoration: TextDecoration.lineThrough,
            decorationColor: context.ds.textTertiary,
            decorationThickness: 2,
          ),
        ),
        Text(
          'core.free_delivery.offered'.tr,
          style: context.textStyle(
            FontSizeType.overline,
            fontWeight: FontWeight.w700,
            color: AppDesign.success,
          ),
        ),
      ],
    );
  }
}

/// Interrupteur « Livraison gratuite » du vendeur : une carte entière qui se
/// touche, avec un curseur maison vert/gris et un rappel de ce que la
/// gratuité lui coûte.
class FreeDeliveryToggle extends StatelessWidget {
  const FreeDeliveryToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.busy = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? title;
  final String? subtitle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null && !busy;
    final active = AppDesign.success;
    final title = this.title ?? 'core.free_delivery.title'.tr;

    return Semantics(
      toggled: value,
      button: true,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesign.radiusMd),
          onTap: enabled ? () => onChanged!(!value) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(AppDesign.space3),
            decoration: BoxDecoration(
              color: value ? AppDesign.successSubtle : context.ds.surface,
              borderRadius: BorderRadius.circular(AppDesign.radiusMd),
              border: Border.all(
                color: value ? active : context.ds.border,
                width: value ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: value ? active : context.ds.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppDesign.radiusSm),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    size: 22,
                    color: value ? Colors.white : context.ds.textSecondary,
                  ),
                ),
                const SizedBox(width: AppDesign.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textStyle(
                          FontSizeType.body1,
                          fontWeight: FontWeight.w700,
                          color: value
                              ? AppDesign.successText
                              : context.ds.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: context.textStyle(
                            FontSizeType.caption,
                            color: context.ds.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppDesign.space3),
                busy
                    ? SizedBox(
                        width: 52,
                        height: 30,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: active,
                            ),
                          ),
                        ),
                      )
                    : _Knob(value: value, enabled: enabled, color: active),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Curseur du [FreeDeliveryToggle] : piste arrondie, pastille qui glisse et
/// porte une coche une fois activée.
class _Knob extends StatelessWidget {
  const _Knob({
    required this.value,
    required this.enabled,
    required this.color,
  });

  final bool value;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? color : context.ds.borderStrong,
          borderRadius: BorderRadius.circular(AppDesign.radiusPill),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: value ? 1 : 0,
              child: Icon(Icons.check_rounded, size: 16, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
