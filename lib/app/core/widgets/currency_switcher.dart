import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import '../../data/models/currency_model.dart';
import '../../data/providers/currency_service.dart';

/// Sélecteur de devise de l'espace vendeur.
///
/// Les montants sont stockés en XOF et convertis à l'affichage : changer de
/// devise ne réécrit donc rien en base, seul le rendu suit. C'est aussi ce qui
/// évite qu'un aller-retour entre deux devises fasse dériver les montants par
/// arrondis successifs.
///
/// Le choix vaut pour tout le tableau de bord (ventes, statistiques, prix) et
/// sert de valeur par défaut à la création d'un produit.
class CurrencySwitcher extends StatelessWidget {
  const CurrencySwitcher({super.key, this.compact = false});

  /// Version resserrée pour une barre d'application déjà chargée.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<CurrencyService>()) return const SizedBox.shrink();

    final ds = context.ds;
    final service = CurrencyService.to;

    return Obx(() {
      final code = service.currencyCode;

      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(AppDesign.radiusPill),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppDesign.space2 : AppDesign.space3,
              vertical: AppDesign.space1 + 2,
            ),
            decoration: BoxDecoration(
              color: ds.surface,
              borderRadius: BorderRadius.circular(AppDesign.radiusPill),
              border: Border.all(color: ds.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!compact) ...[
                  Icon(Icons.payments_outlined, size: 14, color: ds.textTertiary),
                  SizedBox(width: AppDesign.space1),
                ],
                Text(
                  code,
                  style: context.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ds.textPrimary,
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 16, color: ds.textTertiary),
              ],
            ),
          ),
        ),
      );
    });
  }

  Future<void> _openPicker(BuildContext context) async {
    final service = CurrencyService.to;
    final ds = context.ds;

    // La liste est chargée à l'ouverture : elle change rarement et n'a pas à
    // peser sur le démarrage du tableau de bord.
    final currencies = await service.getAllCurrencies();
    final active = currencies.where((c) => c.isActive).toList();
    if (active.isEmpty || !context.mounted) return;

    await Get.bottomSheet<void>(
      _CurrencySheet(currencies: active, current: service.currencyCode),
      backgroundColor: ds.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesign.radiusXl)),
      ),
      isScrollControlled: true,
    );
  }
}

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({required this.currencies, required this.current});

  final List<CurrencyModel> currencies;
  final String current;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  /// Devises les plus utilisées sur la place de marché, remontées en tête :
  /// la liste complète dépasse 150 entrées et faire défiler jusqu'à l'euro
  /// était décourageant.
  static const _common = ['XAF', 'XOF', 'EUR', 'USD', 'GBP', 'CAD', 'NGN', 'MAD'];

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CurrencyModel> get _visible {
    final query = _query.trim().toLowerCase();
    final list = query.isEmpty
        ? [...widget.currencies]
        : widget.currencies
            .where((c) =>
                c.code.toLowerCase().contains(query) ||
                c.name.toLowerCase().contains(query))
            .toList();

    // Tri stable : courantes d'abord (dans l'ordre déclaré), puis alphabétique.
    list.sort((a, b) {
      final rankA = _common.indexOf(a.code.toUpperCase());
      final rankB = _common.indexOf(b.code.toUpperCase());
      if (rankA != -1 || rankB != -1) {
        if (rankA == -1) return 1;
        if (rankB == -1) return -1;
        return rankA.compareTo(rankB);
      }
      return a.code.compareTo(b.code);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ds = context.ds;
    final currencies = _visible;
    final current = widget.current;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppDesign.space3),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ds.borderStrong,
                borderRadius: BorderRadius.circular(AppDesign.radiusPill),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppDesign.space5,
                AppDesign.space5,
                AppDesign.space5,
                AppDesign.space2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'core.currency.title'.tr,
                    style: context.h6.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ds.textPrimary,
                    ),
                  ),
                  SizedBox(height: AppDesign.space1),
                  Text(
                    'core.currency.description'.tr,
                    style: context.body2.copyWith(color: ds.textSecondary),
                  ),
                  SizedBox(height: AppDesign.space4),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'core.currency.search_hint'.tr,
                      isDense: true,
                      filled: true,
                      fillColor: ds.surfaceMuted,
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20, color: ds.textTertiary),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDesign.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (currencies.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppDesign.space8),
                child: Text(
                  'core.currency.no_match'.tr,
                  style: context.body2.copyWith(color: ds.textTertiary),
                ),
              )
            else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.only(bottom: AppDesign.space4),
                itemCount: currencies.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: ds.border, indent: AppDesign.space5),
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  final isSelected =
                      currency.code.toUpperCase() == current.toUpperCase();

                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppDesign.space5,
                        vertical: AppDesign.space1,
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppDesign.accentSubtle
                              : ds.surfaceMuted,
                          borderRadius:
                              BorderRadius.circular(AppDesign.radiusSm),
                        ),
                        child: Text(
                          currency.symbol.isNotEmpty
                              ? currency.symbol
                              : currency.code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.body2.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppDesign.accentText
                                : ds.textSecondary,
                          ),
                        ),
                      ),
                      title: Text(
                        currency.code,
                        style: context.body1.copyWith(
                          fontWeight: FontWeight.w600,
                          color: ds.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        currency.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption.copyWith(color: ds.textTertiary),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppDesign.accent, size: 22)
                          : null,
                      onTap: () async {
                        Get.back();
                        if (isSelected) return;
                        await CurrencyService.to
                            .setCurrencyByCode(currency.code);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
