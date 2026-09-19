import 'package:flutter/material.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';

/// Composants d'interface partagés.
///
/// Ces widgets encapsulent les décisions visuelles (rayon, ombre, bordure,
/// hauteur de cible tactile) pour qu'une vue n'ait plus à les réécrire.
/// Chacun est responsive par construction et s'appuie sur [AppDesign].

// ================================
// SURFACES
// ================================

/// Carte standard : fond, bordure discrète, rayon et ombre homogènes.
///
/// Remplace les `Container(decoration: BoxDecoration(...))` répétés dans les
/// vues, qui dérivaient chacun avec leurs propres valeurs.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.borderRadius,
    this.showBorder = true,
    this.elevated = true,
    this.clipContent = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? borderRadius;
  final bool showBorder;
  final bool elevated;

  /// Rogne le contenu au rayon de la carte (utile quand une image occupe
  /// le haut de la carte, sinon ses angles dépassent).
  final bool clipContent;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius ?? AppDesign.radiusMd);

    final content = Padding(
      padding: padding ?? EdgeInsets.all(AppDesign.space4),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? context.ds.surface,
        borderRadius: radius,
        border: showBorder ? Border.all(color: context.ds.border) : null,
        boxShadow: elevated ? context.ds.shadowSm : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: clipContent ? Clip.antiAlias : Clip.none,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: content,
              ),
      ),
    );
  }
}

/// Contraint le contenu à une largeur de lecture confortable et le centre.
///
/// Sans cela, une page étirée sur tablette ou desktop donne des lignes de
/// texte interminables et des formulaires démesurés.
class AppContentWidth extends StatelessWidget {
  const AppContentWidth({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? context.ds.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}

// ================================
// BOUTONS
// ================================

enum AppButtonVariant {
  /// Action principale de l'écran. Une seule par vue.
  primary,

  /// Action secondaire : contour, sans remplissage.
  secondary,

  /// Action tertiaire, discrète : texte seul.
  ghost,

  /// Action destructive (supprimer, annuler une commande).
  danger,
}

enum AppButtonSize { small, medium, large }

/// Bouton unique de l'application.
///
/// Gère l'état de chargement sans changer de taille — un bouton qui rétrécit
/// pendant l'envoi fait « sauter » la mise en page.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;

  /// Occupe toute la largeur disponible.
  final bool expand;

  double get _height {
    switch (size) {
      case AppButtonSize.small:
        return 40;
      case AppButtonSize.medium:
        return AppDesign.minTapTarget;
      case AppButtonSize.large:
        return 56;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;
    final radius = BorderRadius.circular(AppDesign.radiusSm);

    late final Color background;
    late final Color foreground;
    late final Color? borderColor;

    switch (variant) {
      case AppButtonVariant.primary:
        background = AppDesign.accent;
        foreground = Colors.white;
        borderColor = null;
      case AppButtonVariant.secondary:
        background = Colors.transparent;
        foreground = context.ds.textPrimary;
        borderColor = context.ds.borderStrong;
      case AppButtonVariant.ghost:
        background = Colors.transparent;
        foreground = AppDesign.accent;
        borderColor = null;
      case AppButtonVariant.danger:
        background = AppDesign.danger;
        foreground = Colors.white;
        borderColor = null;
    }

    final textStyle = context.textStyle(
      size == AppButtonSize.small ? FontSizeType.caption : FontSizeType.button,
      fontWeight: FontWeight.w600,
      color: foreground,
    );

    final child = isLoading
        // Le spinner reprend la couleur du texte et garde la hauteur du
        // libellé pour que le bouton ne change pas de dimension.
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: size == AppButtonSize.small ? 16 : 18, color: foreground),
                SizedBox(width: AppDesign.space2),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );

    return Opacity(
      opacity: disabled && !isLoading ? 0.45 : 1,
      child: SizedBox(
        height: _height,
        width: expand ? double.infinity : null,
        child: Material(
          color: background,
          borderRadius: radius,
          child: InkWell(
            onTap: disabled ? null : onPressed,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: borderColor != null ? Border.all(color: borderColor) : null,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: size == AppButtonSize.small
                      ? AppDesign.space3
                      : AppDesign.space5,
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================
// BADGES / ÉTIQUETTES
// ================================

enum AppBadgeTone { neutral, accent, success, warning, danger, info }

/// Étiquette de statut compacte.
///
/// Le ton porte l'information (une commande livrée en vert, annulée en rouge),
/// ce qui évite d'avoir à colorer la carte entière.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;

    switch (tone) {
      case AppBadgeTone.neutral:
        background = context.ds.surfaceMuted;
        foreground = context.ds.textSecondary;
      case AppBadgeTone.accent:
        background = AppDesign.accentSubtle;
        foreground = AppDesign.accentText;
      case AppBadgeTone.success:
        background = AppDesign.successSubtle;
        foreground = AppDesign.successText;
      case AppBadgeTone.warning:
        background = AppDesign.warningSubtle;
        foreground = AppDesign.warningText;
      case AppBadgeTone.danger:
        background = AppDesign.dangerSubtle;
        foreground = AppDesign.dangerText;
      case AppBadgeTone.info:
        background = AppDesign.infoSubtle;
        foreground = AppDesign.infoText;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppDesign.space2,
        vertical: AppDesign.space1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDesign.radiusXs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: context.textStyle(
              FontSizeType.overline,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ================================
// EN-TÊTE DE SECTION
// ================================

/// Titre de section avec action facultative « Voir tout ».
///
/// Uniformise l'espacement et le poids typographique entre les rubriques
/// d'une page, ce qui structure le scroll.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          EdgeInsets.fromLTRB(
            context.ds.gutter,
            AppDesign.space6,
            context.ds.gutter,
            AppDesign.space3,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textStyle(
                    FontSizeType.h5,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: context.textStyle(
                      FontSizeType.caption,
                      color: context.ds.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppDesign.accent,
                padding: EdgeInsets.symmetric(horizontal: AppDesign.space2),
                minimumSize: const Size(0, AppDesign.minTapTarget),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    actionLabel!,
                    style: context.textStyle(
                      FontSizeType.caption,
                      fontWeight: FontWeight.w600,
                      color: AppDesign.accent,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ================================
// ÉTATS VIDES
// ================================

/// État vide cohérent : icône discrète, message clair, action facultative.
///
/// L'icône reste neutre et de taille mesurée — un pictogramme géant et coloré
/// attire l'œil sur l'absence de contenu plutôt que sur la sortie proposée.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.ds.gutter,
          vertical: AppDesign.space10,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.ds.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDesign.radiusMd),
                ),
                child: Icon(icon, size: 26, color: context.ds.textTertiary),
              ),
              SizedBox(height: AppDesign.space4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.textStyle(
                  FontSizeType.subtitle1,
                  fontWeight: FontWeight.w600,
                  color: context.ds.textPrimary,
                ),
              ),
              if (message != null) ...[
                SizedBox(height: AppDesign.space2),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: context.textStyle(
                    FontSizeType.body2,
                    color: context.ds.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: AppDesign.space5),
                AppButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  expand: false,
                  size: AppButtonSize.medium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ================================
// CHAMPS DE SAISIE
// ================================

/// Champ de saisie avec libellé au-dessus.
///
/// Le libellé reste visible une fois le champ rempli, contrairement à un
/// simple placeholder qui disparaît et laisse l'utilisateur deviner ce qu'il
/// a saisi.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.prefixIcon,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.enabled = true,
    this.helperText,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final int maxLines;
  final bool enabled;
  final String? helperText;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDesign.radiusSm);
    final hasError = errorText != null && errorText!.isNotEmpty;

    OutlineInputBorder outline(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: context.textStyle(
              FontSizeType.caption,
              fontWeight: FontWeight.w600,
              color: context.ds.textSecondary,
            ),
          ),
          SizedBox(height: AppDesign.space2),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          validator: validator,
          maxLines: obscureText ? 1 : maxLines,
          enabled: enabled,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          autofillHints: autofillHints,
          style: context.textStyle(
            FontSizeType.body2,
            color: context.ds.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.textStyle(
              FontSizeType.body2,
              color: context.ds.textTertiary,
            ),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: enabled ? context.ds.surface : context.ds.surfaceMuted,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppDesign.space4,
              vertical: AppDesign.space3 + 2,
            ),
            border: outline(context.ds.borderStrong),
            enabledBorder: outline(hasError ? AppDesign.danger : context.ds.borderStrong),
            focusedBorder: outline(hasError ? AppDesign.danger : AppDesign.accent, width: 1.5),
            errorBorder: outline(AppDesign.danger),
            focusedErrorBorder: outline(AppDesign.danger, width: 1.5),
            disabledBorder: outline(context.ds.border),
            // L'erreur est rendue sous le champ par nos soins pour garder
            // une typographie homogène avec le reste du formulaire.
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: AppDesign.space1 + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 14, color: AppDesign.danger),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: context.textStyle(
                    FontSizeType.overline,
                    color: AppDesign.dangerText,
                  ),
                ),
              ),
            ],
          ),
        ] else if (helperText != null) ...[
          SizedBox(height: AppDesign.space1 + 2),
          Text(
            helperText!,
            style: context.textStyle(
              FontSizeType.overline,
              color: context.ds.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

// ================================
// DIVERS
// ================================

/// Séparateur fin, aligné sur la palette de bordures.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: indent,
      color: context.ds.border,
    );
  }
}

/// Bouton d'icône avec cible tactile garantie.
///
/// Les icônes d'AppBar faisaient souvent 20 px de zone cliquable ; on force
/// ici une cible de 48 px sans changer la taille visuelle de l'icône.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badgeCount,
    this.color,
    this.size = 22,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final int? badgeCount;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: AppDesign.minTapTarget,
      height: AppDesign.minTapTarget,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: size, color: color ?? context.ds.textPrimary),
              if (badgeCount != null && badgeCount! > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppDesign.danger,
                      borderRadius: BorderRadius.circular(AppDesign.radiusPill),
                      border: Border.all(color: context.ds.surface, width: 1.5),
                    ),
                    child: Text(
                      badgeCount! > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
