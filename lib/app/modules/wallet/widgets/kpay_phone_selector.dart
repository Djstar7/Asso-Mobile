import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_design.dart';
import '../../../core/values/kpay_catalog.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../data/providers/payment_service.dart';

/// Sélecteur KPay : pays (drapeau + indicatif) → opérateur → numéro.
///
/// Restreint aux pays et opérateurs du prestataire Mobile Money actif côté
/// backend (KPay : tout son catalogue ; ElgioPay : Cameroun seul). Renvoie via [onChanged] le code
/// opérateur KPay (ex. MTN_MOMO_CMR) et le numéro au format international
/// sans '+' (ex. 237670000001), ainsi que la validité du formulaire.
class KpayPhoneSelector extends StatefulWidget {
  final void Function({
    required String? providerCode,
    required String? phoneNumber,
    required String currency,
    required bool isValid,
  })
  onChanged;

  /// Valeurs initiales (ex. coordonnées de retrait enregistrées) : code opérateur
  /// KPay et numéro international sans « + ».
  final String? initialProviderCode;
  final String? initialPhone;

  const KpayPhoneSelector({
    super.key,
    required this.onChanged,
    this.initialProviderCode,
    this.initialPhone,
  });

  @override
  State<KpayPhoneSelector> createState() => _KpayPhoneSelectorState();
}

class _KpayPhoneSelectorState extends State<KpayPhoneSelector> {
  late KPayCountry _country;
  late KPayOperator _operator;
  List<KPayCountry> _countries = KPayCatalog.countries;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _country = KPayCatalog.defaultCountry;
    _operator = _country.operators.first;

    final initial = KPayCatalog.byProviderCode(widget.initialProviderCode);
    if (initial != null) {
      _country = initial.$1;
      _operator = initial.$2;
      final phone = widget.initialPhone ?? '';
      _phoneController.text = phone.startsWith(_country.dialCode)
          ? phone.substring(_country.dialCode.length)
          : phone;
    }

    _phoneController.addListener(_onPhoneChanged);
    // Valeurs pré-remplies : le parent reçoit l'état initial sans attendre une saisie.
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notify();
      });
    }
    _loadAllowedProviders();
  }

  /// Ne garde que les pays/opérateurs du prestataire actif. Le choix courant
  /// bascule sur le premier opérateur accepté s'il n'en fait pas partie.
  Future<void> _loadAllowedProviders() async {
    final providers = await PaymentService.fetchMobileMoneyProviders();
    if (!mounted) return;
    final allowed = KPayCatalog.restrictedTo(providers);
    if (allowed.isEmpty) return;

    final country =
        allowed.firstWhereOrNull((c) => c.iso3 == _country.iso3) ??
        allowed.first;
    final operator =
        country.operators.firstWhereOrNull(
          (o) => o.providerCode == _operator.providerCode,
        ) ??
        country.operators.first;
    final countryChanged = country.iso3 != _country.iso3;
    final operatorChanged = operator.providerCode != _operator.providerCode;

    setState(() {
      _countries = allowed;
      _country = country;
      _operator = operator;
      // Numéro saisi pour un autre indicatif : il ne vaut plus rien.
      if (countryChanged) _phoneController.clear();
    });
    if (countryChanged || operatorChanged) _notify();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _localDigits =>
      _phoneController.text.replaceAll(RegExp(r'\D'), '');

  bool get _isValid {
    final len = _localDigits.length;
    // Au Cameroun, un numéro mobile local contient exactement 9 chiffres.
    if (_country.iso3 == 'CMR') return len == 9;
    // Les autres pays KPay conservent leur plage autorisée par le fournisseur.
    return len >= 6 && len <= 12;
  }

  String get _fullPhone => '${_country.dialCode}$_localDigits';

  /// Opérateur reconnu au préfixe du numéro, s'il fait partie des choix.
  KPayOperator? get _detectedOperator {
    final code = KPayCatalog.detectProviderCode(_country.iso3, _localDigits);
    return _country.operators.firstWhereOrNull((o) => o.providerCode == code);
  }

  /// Le numéro désigne son opérateur : un numéro Orange envoyé chez MTN est
  /// refusé sans qu'aucune demande USSD n'arrive sur le téléphone.
  void _onPhoneChanged() {
    final detected = _detectedOperator;
    if (detected != null && detected.providerCode != _operator.providerCode) {
      setState(() => _operator = detected);
    }
    _notify();
  }

  void _notify() {
    widget.onChanged(
      providerCode: _operator.providerCode,
      phoneNumber: _isValid ? _fullPhone : null,
      currency: _country.currency,
      isValid: _isValid,
    );
  }

  Future<void> _pickCountry() async {
    // Feuille standard : elle s'arrête sous la barre d'état et porte une
    // croix. Ouverte par-dessus la feuille de paiement, elle montait jusqu'en
    // haut de l'écran sans autre sortie que le bouton système.
    final selected = await AppSheet.show<KPayCountry>(
      AppSheet(
        title: 'wallet.kpay.select_country'.tr,
        scrollable: false,
        bodyPadding: EdgeInsets.zero,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _countries.length,
          itemBuilder: (itemContext, i) {
            final c = _countries[i];
            return ListTile(
              leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
              title: Text(c.name),
              trailing: Text(
                '+${c.dialCode}',
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(itemContext, c),
            );
          },
        ),
      ),
    );

    if (selected != null) {
      setState(() {
        _country = selected;
        _operator = selected.operators.first;
      });
      _notify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Un seul pays servi (ElgioPay : Cameroun) : rien à choisir.
    final canPickCountry = _countries.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Pays ---
        Text('wallet.kpay.country'.tr, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: canPickCountry ? _pickCountry : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(_country.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _country.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                Text(
                  '+${_country.dialCode}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (canPickCountry)
                  const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Opérateur ---
        Text('wallet.kpay.operator'.tr, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _country.operators.map((op) {
            final selected = op.providerCode == _operator.providerCode;
            return ChoiceChip(
              label: Text(op.name),
              selected: selected,
              onSelected: (_) {
                setState(() => _operator = op);
                _notify();
              },
              selectedColor: theme.colorScheme.primary.withOpacity(0.15),
              labelStyle: TextStyle(
                color: selected ? theme.colorScheme.primary : null,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // --- Numéro ---
        Text(
          'wallet.kpay.phone_label'.tr,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text(
                '${_country.flag} +${_country.dialCode}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            hintText: 'wallet.kpay.phone_hint'.tr,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        if (_detectedOperator case final detected?
            when detected.providerCode != _operator.providerCode)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'wallet.kpay.operator_mismatch'.trParams({
                'operator': detected.name,
              }),
              style: const TextStyle(color: AppDesign.warningText, fontSize: 12),
            ),
          ),
        if (_phoneController.text.isNotEmpty && !_isValid)
          Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              _country.iso3 == 'CMR'
                  ? 'wallet.kpay.phone_9_digits'.tr
                  : 'wallet.kpay.phone_invalid'.tr,
              style: const TextStyle(color: AppDesign.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
