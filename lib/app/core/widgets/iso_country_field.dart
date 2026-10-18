import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl_phone_field/countries.dart';

import '../services/locale_service.dart';
import '../utils/app_design.dart';
import '../utils/app_theme_system.dart';
import 'app_sheet.dart';

/// Nom d'un pays (code ISO à 2 lettres) dans la langue de l'app.
String isoCountryName(String? code) {
  if (code == null || code.isEmpty) return '';
  final country = countries.firstWhereOrNull((c) => c.code == code.toUpperCase());
  return country?.localizedName(LocaleService.currentLanguage) ?? code;
}

/// Champ de choix d'un pays (liste ISO complète, avec recherche). La valeur
/// est le code ISO à 2 lettres attendu par le serveur.
class IsoCountryField extends StatelessWidget {
  const IsoCountryField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.fillColor,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final code = await _pick();
        if (code != null) onChanged(code);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: fillColor,
          suffixIcon: const Icon(Icons.expand_more),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        child: Text(
          value == null ? '' : isoCountryName(value),
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Future<String?> _pick() {
    final query = ''.obs;
    final lang = LocaleService.currentLanguage;
    final sorted = [...countries]
      ..sort((a, b) => a.localizedName(lang).compareTo(b.localizedName(lang)));

    return AppSheet.show<String>(
      AppSheet(
        title: label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => query.value = v.trim().toLowerCase(),
              decoration: InputDecoration(
                hintText: 'iso_country.search'.tr,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 360,
              child: Obx(() {
                final items = sorted
                    .where((c) =>
                        query.value.isEmpty ||
                        c.localizedName(lang).toLowerCase().contains(query.value) ||
                        c.code.toLowerCase() == query.value)
                    .toList();
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final c = items[i];
                    final selected = c.code == value;
                    return ListTile(
                      dense: true,
                      title: Text(c.localizedName(lang)),
                      trailing: selected
                          ? Icon(Icons.check, color: AppThemeSystem.primaryColor)
                          : Text(c.code, style: const TextStyle(color: AppDesign.neutral500)),
                      onTap: () => Get.back(result: c.code),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
