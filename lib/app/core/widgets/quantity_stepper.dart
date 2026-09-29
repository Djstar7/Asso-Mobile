import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';

/// Quantité réglable aux boutons − / + ou tapée au clavier.
///
/// Les boutons seuls rendaient pénible toute grosse commande : atteindre
/// 1 000 unités à coups de « + » n'est pas envisageable. Le nombre est donc
/// un vrai champ de saisie, les boutons servant aux petits ajustements.
///
/// Pendant la frappe, la valeur est transmise telle quelle (plafonnée à
/// [max]) pour que les totaux suivent chaque chiffre. En quittant le champ,
/// une saisie vide ou sous [min] reprend [min] : un « 0 » ou un champ vide
/// laissé à l'écran ferait croire à une commande vide.
class QuantityStepper extends StatefulWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
    this.enabled = true,
    this.compact = false,
    this.hasError = false,
    this.onMaxReached,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;

  /// Plafond (stock disponible). null : pas de limite.
  final int? max;

  final bool enabled;

  /// Version resserrée, pour une ligne de liste.
  final bool compact;

  /// Bordure d'erreur (quantité sous le minimum imposé par l'appelant).
  final bool hasError;

  /// Appelé quand on bute sur [max], pour expliquer pourquoi ça bloque.
  final VoidCallback? onMaxReached;

  @override
  State<QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<QuantityStepper> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(QuantityStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Valeur changée de l'extérieur (bouton, palier, remise à zéro) : on
    // réaligne le champ, sauf pendant la frappe où l'on réécrirait sous le
    // doigt.
    if (!_focus.hasFocus && _controller.text != '${widget.value}') {
      _write(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _write(int value) {
    final text = '$value';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onFocusChange() {
    // Le contour passe à la couleur d'accent pendant la saisie.
    if (mounted) setState(() {});
    if (_focus.hasFocus) return;
    final typed = int.tryParse(_controller.text.trim());
    if (typed == null || typed < widget.min) {
      _write(widget.min);
      if (widget.value != widget.min) widget.onChanged(widget.min);
    }
  }

  void _onTyped(String text) {
    final typed = int.tryParse(text);
    if (typed == null) {
      // Champ vidé le temps de retaper : la quantité vaut 0 sans que le
      // champ soit réécrit.
      widget.onChanged(0);
      return;
    }
    final max = widget.max;
    if (max != null && typed > max) {
      _write(max);
      widget.onMaxReached?.call();
      widget.onChanged(max);
      return;
    }
    widget.onChanged(typed);
  }

  void _step(int delta) {
    final max = widget.max;
    final next = widget.value + delta;
    if (max != null && next > max) {
      widget.onMaxReached?.call();
      return;
    }
    if (next < widget.min) return;
    _write(next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.max;
    final canDecrease = widget.enabled && widget.value > widget.min;
    final canIncrease = widget.enabled && (max == null || widget.value < max);
    // Un seul bloc bordé [ − | nombre | + ] : boutons et champ partagent la
    // même hauteur et le même contour, au lieu de trois pièces détachées.
    final height = widget.compact ? 34.0 : 40.0;
    final fieldWidth = widget.compact ? 52.0 : 72.0;
    final borderColor = widget.hasError
        ? AppDesign.danger
        : (_focus.hasFocus ? AppDesign.accent : context.ds.borderStrong);
    final divider = SizedBox(
      height: height,
      child: VerticalDivider(width: 1, thickness: 1, color: context.ds.border),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.enabled
                ? context.ds.surface
                : context.ds.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDesign.radiusSm),
            border: Border.all(
              color: borderColor,
              width: _focus.hasFocus || widget.hasError ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StepButton(
                icon: Icons.remove_rounded,
                tooltip: 'Diminuer',
                size: height,
                onTap: canDecrease ? () => _step(-1) : null,
              ),
              divider,
              SizedBox(
                width: fieldWidth,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  onChanged: _onTyped,
                  onSubmitted: (_) => _focus.unfocus(),
                  style: context.textStyle(
                    widget.compact ? FontSizeType.body2 : FontSizeType.body1,
                    fontWeight: FontWeight.w700,
                    color: context.ds.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDesign.space1,
                    ),
                    hintText: '${widget.min}',
                  ),
                ),
              ),
              divider,
              _StepButton(
                icon: Icons.add_rounded,
                tooltip: 'Augmenter',
                size: height,
                onTap: canIncrease
                    ? () => _step(1)
                    : (widget.enabled && max != null
                          ? widget.onMaxReached
                          : null),
                dimmed: !canIncrease,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.onTap,
    this.dimmed = false,
  });

  final IconData icon;
  final String tooltip;
  final double size;
  final VoidCallback? onTap;

  /// Aspect inactif même si le bouton reste touchable (pour expliquer une
  /// limite de stock).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null && !dimmed;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: 18,
            color: active ? AppDesign.accent : context.ds.textTertiary,
          ),
        ),
      ),
    );
  }
}
