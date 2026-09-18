import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_theme_system.dart';
import '../../../core/widgets/product_variant_selector.dart';
import '../controllers/variant_editor_state.dart';

/// Éditeur plein écran des variantes vendeur :
/// 1. options proposées (couleurs en pastilles, tailles, pointures…)
/// 2. quantité par combinaison, générée automatiquement.
class VariantEditorPage extends StatelessWidget {
  final VariantEditorState state;

  const VariantEditorPage({super.key, required this.state});

  static const _quickGroups = <(String, IconData)>[
    ('Couleur', Icons.palette_outlined),
    ('Taille', Icons.checkroom_outlined),
    ('Pointure', Icons.do_not_step_outlined),
    ('Stockage', Icons.sd_storage_outlined),
    ('Dimensions', Icons.straighten_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      appBar: AppBar(
        backgroundColor: context.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Couleurs, tailles & options',
          style: context.h6.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      body: Obx(() {
        state.revision.value; // abonnement aux changements
        final combos = state.combinations;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            _intro(context),
            const SizedBox(height: 20),
            _stepTitle(context, 1, 'Options proposées au client'),
            const SizedBox(height: 12),
            for (var i = 0; i < state.groups.length; i++)
              _GroupCard(
                key: ObjectKey(state.groups[i]),
                state: state,
                index: i,
              ),
            _addGroupChips(context),
            if (combos.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _stepTitle(context, 2, 'Quantité par combinaison'),
                  ),
                  _totalBadge(context),
                ],
              ),
              const SizedBox(height: 12),
              _BulkStockRow(state: state),
              const SizedBox(height: 12),
              for (final combo in combos)
                _ComboTile(
                  key: ValueKey(VariantEditorState.signature(combo)),
                  state: state,
                  combo: combo,
                ),
            ],
          ],
        );
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Obx(() {
            state.revision.value;
            final count = state.combinations.length;
            return FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppThemeSystem.primaryColor,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_rounded),
              label: Text(
                count == 0
                    ? 'Terminer'
                    : 'Valider · $count choix · ${state.totalStock} en stock',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppThemeSystem.primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lightbulb_outline_rounded,
          color: AppThemeSystem.primaryColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Ajoutez ce que le client doit choisir : la couleur d’un téléphone, '
            'la couleur et la pointure d’une chaussure… Toutes les combinaisons '
            'sont créées pour vous, il ne reste qu’à indiquer les quantités.',
            style: context.body2.copyWith(height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _stepTitle(BuildContext context, int step, String title) => Row(
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppThemeSystem.primaryColor,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$step',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          title,
          style: context.subtitle1.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );

  Widget _totalBadge(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.surfaceColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.borderColor),
    ),
    child: Text(
      'Total : ${state.totalStock}',
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppThemeSystem.primaryColor,
      ),
    ),
  );

  Widget _addGroupChips(BuildContext context) {
    final existing = state.groups.map((g) => g.name.toLowerCase()).toSet();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            state.groups.isEmpty ? 'Commencez par :' : 'Ajouter :',
            style: context.body2.copyWith(color: context.secondaryTextColor),
          ),
          for (final (name, icon) in _quickGroups)
            if (!existing.contains(name.toLowerCase()))
              ActionChip(
                avatar: Icon(icon, size: 18),
                label: Text(name),
                onPressed: () => state.addGroup(name),
              ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Autre option'),
            onPressed: () => _askCustomGroup(context),
          ),
        ],
      ),
    );
  }

  Future<void> _askCustomGroup(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nouvelle option'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex. Matière, Parfum, Capacité',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) state.addGroup(name);
  }
}

// ─────────────────────────── Groupe d'options ───────────────────────────

class _GroupCard extends StatefulWidget {
  final VariantEditorState state;
  final int index;

  const _GroupCard({super.key, required this.state, required this.index});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  late final TextEditingController _name;
  final _value = TextEditingController();
  final _valueFocus = FocusNode();

  VariantDraftGroup get _group => widget.state.groups[widget.index];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _group.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  void _addValue([String? raw]) {
    widget.state.addValues(widget.index, raw ?? _value.text);
    if (raw == null) {
      _value.clear();
      _valueFocus.requestFocus();
    }
  }

  Future<void> _pickColor(int valueIndex) async {
    final current = _group.values[valueIndex];
    final hex = await showColorPalette(
      context,
      title: current.value,
      selected: current.hex,
    );
    if (hex != null) widget.state.setValueHex(widget.index, valueIndex, hex);
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final presets = widget.state.presetsFor(group);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      (group.isColor
                              ? Colors.pink
                              : AppThemeSystem.primaryColor)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  group.isColor ? Icons.palette_outlined : Icons.sell_outlined,
                  color: group.isColor
                      ? Colors.pink
                      : AppThemeSystem.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Focus(
                  onFocusChange: (focused) {
                    if (!focused)
                      widget.state.renameGroup(widget.index, _name.text);
                  },
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Nom de l’option',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (v) =>
                        widget.state.renameGroup(widget.index, v),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: context.secondaryTextColor),
                onSelected: (action) {
                  if (action == 'color') {
                    widget.state.setColorMode(widget.index, !group.isColor);
                  } else if (action == 'delete') {
                    widget.state.removeGroup(widget.index);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'color',
                    child: Text(
                      group.isColor
                          ? 'Afficher en étiquettes'
                          : 'Afficher en pastilles de couleur',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Supprimer cette option',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (group.values.isEmpty)
            Text(
              group.isColor
                  ? 'Touchez une couleur ci-dessous ou saisissez-en une.'
                  : 'Ajoutez les valeurs proposées (ex. S, M, L).',
              style: context.caption.copyWith(
                color: context.secondaryTextColor,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < group.values.length; i++)
                  group.isColor
                      ? InputChip(
                          avatar: GestureDetector(
                            onTap: () => _pickColor(i),
                            child: _Swatch(hex: group.values[i].hex, size: 22),
                          ),
                          label: Text(group.values[i].value),
                          onPressed: () => _pickColor(i),
                          onDeleted: () =>
                              widget.state.removeValue(widget.index, i),
                          tooltip: 'Touchez pour changer la teinte',
                        )
                      : InputChip(
                          label: Text(
                            group.values[i].value,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          backgroundColor: AppThemeSystem.primaryColor
                              .withValues(alpha: 0.1),
                          onDeleted: () =>
                              widget.state.removeValue(widget.index, i),
                        ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _value,
                  focusNode: _valueFocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: group.isColor
                        ? 'Autre couleur (ex. Bleu nuit)'
                        : 'Ajouter une valeur (S, M, L…)',
                    isDense: true,
                    filled: true,
                    fillColor: context.inputFieldColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _addValue(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppThemeSystem.primaryColor,
                ),
                onPressed: _addValue,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ],
          ),
          if (presets.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: presets
                  .map(
                    (p) => ActionChip(
                      visualDensity: VisualDensity.compact,
                      avatar: group.isColor
                          ? _Swatch(
                              hex: VariantPalette.toHex(
                                VariantPalette.guess(p),
                              ),
                              size: 16,
                            )
                          : const Icon(Icons.add, size: 14),
                      label: Text(p, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _addValue(p),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────── Combinaisons ───────────────────────────

class _BulkStockRow extends StatefulWidget {
  final VariantEditorState state;
  const _BulkStockRow({required this.state});

  @override
  State<_BulkStockRow> createState() => _BulkStockRowState();
}

class _BulkStockRowState extends State<_BulkStockRow> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: 'Même quantité pour tout',
              prefixIcon: const Icon(Icons.format_paint_outlined),
              isDense: true,
              filled: true,
              fillColor: context.inputFieldColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () {
            final qty = int.tryParse(_controller.text);
            if (qty == null) return;
            widget.state.applyStockToAll(qty);
            FocusScope.of(context).unfocus();
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Appliquer'),
        ),
      ],
    );
  }
}

class _ComboTile extends StatefulWidget {
  final VariantEditorState state;
  final Map<String, String> combo;

  const _ComboTile({super.key, required this.state, required this.combo});

  @override
  State<_ComboTile> createState() => _ComboTileState();
}

class _ComboTileState extends State<_ComboTile> {
  late final TextEditingController _stock;
  late final TextEditingController _price;
  late final TextEditingController _sku;
  final _stockFocus = FocusNode();
  bool _expanded = false;

  VariantDraftRow get _row => widget.state.rowFor(widget.combo);

  @override
  void initState() {
    super.initState();
    _stock = TextEditingController(text: '${_row.stock}');
    final price = _row.priceAdjustment;
    _price = TextEditingController(
      text: price == 0
          ? ''
          : (price == price.roundToDouble()
                ? price.toInt().toString()
                : '$price'),
    );
    _sku = TextEditingController(text: _row.sku);
    _expanded = price != 0 || _row.sku.isNotEmpty || !_row.isActive;
  }

  @override
  void didUpdateWidget(covariant _ComboTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Synchronise après « Appliquer à toutes » sans écraser une saisie en cours.
    if (!_stockFocus.hasFocus && _stock.text != '${_row.stock}') {
      _stock.text = '${_row.stock}';
    }
  }

  @override
  void dispose() {
    _stock.dispose();
    _price.dispose();
    _sku.dispose();
    _stockFocus.dispose();
    super.dispose();
  }

  void _setStock(int value) {
    _row.stock = value < 0 ? 0 : value;
    if (_stock.text != '${_row.stock}') _stock.text = '${_row.stock}';
    widget.state.touch();
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    final outOfStock = row.stock == 0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: row.isActive ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: outOfStock && row.isActive
                ? AppThemeSystem.warningColor.withValues(alpha: 0.6)
                : context.borderColor,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.combo.entries.map((entry) {
                      final hex = widget.state.hexOf(entry.key, entry.value);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hex != null) ...[
                              _Swatch(hex: hex, size: 14),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              entry.value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                _stepButton(
                  Icons.remove_rounded,
                  () => _setStock(row.stock - 1),
                ),
                SizedBox(
                  width: 52,
                  child: TextField(
                    controller: _stock,
                    focusNode: _stockFocus,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onChanged: (v) {
                      row.stock = int.tryParse(v) ?? 0;
                      widget.state.touch();
                    },
                  ),
                ),
                _stepButton(Icons.add_rounded, () => _setStock(row.stock + 1)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Prix, référence, visibilité',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: context.secondaryTextColor,
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: _fieldDecoration(
                        context,
                        'Supplément de prix',
                        Icons.add_card_outlined,
                      ),
                      onChanged: (v) => row.priceAdjustment =
                          double.tryParse(v.replaceAll(',', '.')) ?? 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _sku,
                      decoration: _fieldDecoration(
                        context,
                        'Référence',
                        Icons.qr_code_2_outlined,
                      ),
                      onChanged: (v) => row.sku = v.trim(),
                    ),
                  ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: row.isActive,
                activeThumbColor: AppThemeSystem.primaryColor,
                title: const Text('Proposer ce choix aux clients'),
                onChanged: (v) {
                  row.isActive = v;
                  widget.state.touch();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepButton(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppThemeSystem.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 18, color: AppThemeSystem.primaryColor),
    ),
  );

  InputDecoration _fieldDecoration(
    BuildContext context,
    String label,
    IconData icon,
  ) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18),
    isDense: true,
    filled: true,
    fillColor: context.inputFieldColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

// ─────────────────────────── Couleurs ───────────────────────────

class _Swatch extends StatelessWidget {
  final String? hex;
  final double size;
  const _Swatch({required this.hex, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: VariantPalette.parseHex(hex) ?? Colors.grey,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black26),
    ),
  );
}

const _paletteHex = <String>[
  '#212121',
  '#FAFAFA',
  '#9E9E9E',
  '#616161',
  '#E53935',
  '#7B1F2B',
  '#EC407A',
  '#F8BBD0',
  '#8E24AA',
  '#5E35B1',
  '#1A237E',
  '#1E88E5',
  '#81D4FA',
  '#1DE9B6',
  '#43A047',
  '#6B6B3A',
  '#FDD835',
  '#FB8C00',
  '#795548',
  '#D7CCC8',
  '#FFF8E1',
  '#C9A227',
  '#BDBDBD',
  '#00838F',
];

/// Nuancier simple (pas de dépendance externe) ; renvoie la teinte choisie en hex.
Future<String?> showColorPalette(
  BuildContext context, {
  required String title,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Teinte affichée pour « $title »',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _paletteHex.map((hex) {
                final isSelected = hex.toUpperCase() == selected?.toUpperCase();
                final color = VariantPalette.parseHex(hex)!;
                return GestureDetector(
                  onTap: () => Navigator.pop(sheetContext, hex),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppThemeSystem.primaryColor
                            : Colors.black12,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: VariantPalette.onColor(color),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    ),
  );
}
