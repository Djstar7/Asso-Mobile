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
///
/// Dès qu'un opérateur est choisi (ou détecté via le numéro), on interroge
/// l'API de disponibilité KPay (via le backend). Si l'opérateur est instable,
/// l'utilisateur est averti, un autre opérateur lui est suggéré et le
/// formulaire est marqué invalide (bouton « Payer » désactivé).
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

  // --- Disponibilité de l'opérateur ---
  /// true quand l'API KPay signale l'opérateur courant comme instable.
  bool _operatorUnstable = false;

  /// Opérateurs alternatifs disponibles dans le même pays.
  List<KPayOperator> _suggested = [];

  /// Vérification en cours (petit loader à côté du libellé « Opérateur »).
  bool _checkingAvailability = false;

  /// Identifiant de la dernière vérification lancée : une réponse tardive
  /// d'un ancien choix d'opérateur est ignorée.
  int _availabilityRequestId = 0;

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
    // Vérifie l'opérateur proposé par défaut dès l'ouverture.
    _checkAvailability();
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
      if (countryChanged || operatorChanged) {
        _operatorUnstable = false;
        _suggested = [];
      }
      // Numéro saisi pour un autre indicatif : il ne vaut plus rien.
      if (countryChanged) _phoneController.clear();
    });
    if (countryChanged || operatorChanged) {
      _notify();
      _checkAvailability();
    }
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

  /// Change d'opérateur : réinitialise l'avertissement précédent, prévient le
  /// parent, puis vérifie la disponibilité du nouvel opérateur.
  void _selectOperator(KPayOperator op) {
    setState(() {
      _operator = op;
      _operatorUnstable = false;
      _suggested = [];
    });
    _notify();
    _checkAvailability();
  }

  /// Interroge le backend (qui interroge KPay, cache 60 s) sur l'opérateur
  /// courant. En cas d'erreur réseau, l'opérateur est considéré disponible :
  /// le serveur bloquera de toute façon un opérateur instable à l'init.
  Future<void> _checkAvailability() async {
    final requestId = ++_availabilityRequestId;
    final code = _operator.providerCode;

    if (mounted) setState(() => _checkingAvailability = true);

    final res = await PaymentService.checkOperatorAvailability(code);

    // Réponse périmée : l'utilisateur a changé d'opérateur entre-temps.
    if (!mounted ||
        requestId != _availabilityRequestId ||
        code != _operator.providerCode) {
      return;
    }

    setState(() {
      _checkingAvailability = false;
      _operatorUnstable = !res.available;
      _suggested = res.available
          ? []
          : _country.operators
                .where(
                  (o) =>
                      o.providerCode != code &&
                      res.suggestions.contains(o.providerCode),
                )
                .toList();
    });
    _notify();
  }

  /// Le numéro désigne son opérateur : un numéro Orange envoyé chez MTN est
  /// refusé sans qu'aucune demande USSD n'arrive sur le téléphone.
  void _onPhoneChanged() {
    final detected = _detectedOperator;
    if (detected != null && detected.providerCode != _operator.providerCode) {
      // _selectOperator notifie le parent et lance la vérification.
      _selectOperator(detected);
      return;
    }
    _notify();
  }

  void _notify() {
    // Un opérateur instable rend le formulaire invalide : le bouton « Payer »
    // du parent (canPay = _valid && ...) se désactive automatiquement.
    final valid = _isValid && !_operatorUnstable;
    widget.onChanged(
      providerCode: _operator.providerCode,
      phoneNumber: valid ? _fullPhone : null,
      currency: _country.currency,
      isValid: valid,
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
        _operatorUnstable = false;
        _suggested = [];
      });
      _notify();
      _checkAvailability();
    }
  }

  /// Bannière d'avertissement + opérateurs alternatifs cliquables.
  Widget _buildUnstableBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesign.warningText.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppDesign.warningText.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppDesign.warningText,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'wallet.kpay.operator_unstable'.trParams({
                    'operator': _operator.name,
                  }),
                  style: const TextStyle(
                    color: AppDesign.warningText,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (_suggested.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _suggested
                  .map(
                    (o) => ActionChip(
                      label: Text(
                        'wallet.kpay.try_operator'.trParams({
                          'operator': o.name,
                        }),
                      ),
                      onPressed: () => _selectOperator(o),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Un seul pays servi (ElgioPay : Cameroun) : rien à choisir.
    final canPickCountry = _countries.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Pays ---
        Text(
          'wallet.kpay.country'.tr,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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
        Row(
          children: [
            Text(
              'wallet.kpay.operator'.tr,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_checkingAvailability) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _country.operators.map((op) {
            final selected = op.providerCode == _operator.providerCode;
            return ChoiceChip(
              label: Text(op.name),
              selected: selected,
              onSelected: (_) => _selectOperator(op),
              selectedColor: AppDesign.accent,
              checkmarkColor: AppDesign.onAccent,
              labelStyle: TextStyle(
                color: selected ? AppDesign.onAccent : null,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),

        // --- Avertissement : opérateur instable ---
        if (_operatorUnstable) _buildUnstableBanner(),
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
              style: const TextStyle(
                color: AppDesign.warningText,
                fontSize: 12,
              ),
            ),
          ),
        if (_phoneController.text.isNotEmpty && !_isValid)
          Padding(
            padding: const EdgeInsets.only(top: 6),
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