import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/values/kpay_catalog.dart';

/// Sélecteur KPay : pays (drapeau + indicatif) → opérateur → numéro.
///
/// Restreint aux pays couverts par KPay. Renvoie via [onChanged] le code
/// opérateur KPay (ex. MTN_MOMO_CMR) et le numéro au format international
/// sans '+' (ex. 237670000001), ainsi que la validité du formulaire.
class KpayPhoneSelector extends StatefulWidget {
  final void Function({
    required String? providerCode,
    required String? phoneNumber,
    required String currency,
    required bool isValid,
  }) onChanged;

  const KpayPhoneSelector({super.key, required this.onChanged});

  @override
  State<KpayPhoneSelector> createState() => _KpayPhoneSelectorState();
}

class _KpayPhoneSelectorState extends State<KpayPhoneSelector> {
  late KPayCountry _country;
  late KPayOperator _operator;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _country = KPayCatalog.defaultCountry;
    _operator = _country.operators.first;
    _phoneController.addListener(_notify);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String get _localDigits => _phoneController.text.replaceAll(RegExp(r'\D'), '');

  bool get _isValid {
    // Numéro local raisonnable (6 à 12 chiffres selon le pays).
    final len = _localDigits.length;
    return len >= 6 && len <= 12;
  }

  String get _fullPhone => '${_country.dialCode}$_localDigits';

  void _notify() {
    widget.onChanged(
      providerCode: _operator.providerCode,
      phoneNumber: _isValid ? _fullPhone : null,
      currency: _country.currency,
      isValid: _isValid,
    );
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<KPayCountry>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Sélectionnez votre pays',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: KPayCatalog.countries.length,
                itemBuilder: (_, i) {
                  final c = KPayCatalog.countries[i];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                    title: Text(c.name),
                    trailing: Text('+${c.dialCode}',
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Pays ---
        const Text('Pays', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickCountry,
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
                Expanded(child: Text(_country.name, style: const TextStyle(fontSize: 16))),
                Text('+${_country.dialCode}',
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Opérateur ---
        const Text('Opérateur', style: TextStyle(fontWeight: FontWeight.w600)),
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
        const Text('Numéro Mobile Money', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Text('${_country.flag} +${_country.dialCode}',
                  style: const TextStyle(fontSize: 16)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            hintText: 'Ex. 670000001',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        if (_phoneController.text.isNotEmpty && !_isValid)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Numéro invalide', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}
