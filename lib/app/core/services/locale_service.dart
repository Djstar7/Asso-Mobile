import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart' show Locale;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../values/country_catalog.dart';

/// Langue de l'interface : choix au premier lancement, selon le pays, et
/// changement depuis les réglages.
///
/// La langue est rangée sous ses propres clés, hors de la map
/// `preferences` : celle-ci est réécrite en entier à l'enregistrement des
/// centres d'intérêt, ce qui effaçait la langue choisie.
class LocaleService extends GetxService {
  static LocaleService get to => Get.find();

  static const String keyLocale = 'app_locale';
  static const String keyLocaleManual = 'app_locale_manual';

  static const List<String> supportedLanguages = ['fr', 'en'];

  static const Locale french = Locale('fr', 'FR');
  static const Locale english = Locale('en', 'US');

  /// Pays où le français est la langue professionnelle.
  static const Set<String> frenchCountries = {
    'FR', 'BE', 'CH', 'LU', 'MC', // Europe
    'BJ', 'BF', 'CI', 'SN', 'ML', 'NE', 'TG', 'GN', // Afrique de l'Ouest
    'GA', 'CG', 'CD', 'CF', 'TD', 'GQ', // Afrique centrale
    'DJ', 'KM', 'MG', 'BI', 'SC', // Afrique de l'Est, océan Indien
    'HT', 'MA', 'DZ', 'TN', 'MR', // Caraïbes, Maghreb
  };

  /// Pays bilingues : la langue du téléphone départage.
  static const Set<String> bilingualCountries = {'CM', 'CA'};

  final GetStorage _storage;

  LocaleService({GetStorage? storage}) : _storage = storage ?? GetStorage();

  /// Code de la langue courante (`fr` ou `en`).
  final language = 'fr'.obs;

  Locale get currentLocale => localeFor(language.value);

  /// Langue à annoncer au serveur (`Accept-Language`), `fr` tant que le
  /// service n'est pas enregistré (tests, démarrage).
  static String get currentLanguage =>
      Get.isRegistered<LocaleService>() ? to.language.value : 'fr';

  /// Vrai si l'utilisateur a choisi sa langue dans les réglages : le choix
  /// d'un pays ne la remplace plus.
  bool get isManual => _storage.read(keyLocaleManual) == true;

  /// Relit la langue enregistrée, ou prend celle du téléphone au premier
  /// lancement, pour que l'écran de choix du pays soit déjà lisible.
  Future<LocaleService> init() async {
    final saved = _storage.read(keyLocale);
    final code = saved is String && supportedLanguages.contains(saved)
        ? saved
        : _legacyLanguage() ?? deviceLanguage();
    await _apply(code);
    return this;
  }

  /// Change la langue de toute l'application.
  Future<void> setLanguage(String code, {bool manual = false}) async {
    if (!supportedLanguages.contains(code)) return;
    await _storage.write(keyLocale, code);
    if (manual) await _storage.write(keyLocaleManual, true);
    await _apply(code);
    Get.updateLocale(localeFor(code));
  }

  /// Applique la langue du pays choisi, sauf si l'utilisateur a déjà fixé
  /// la sienne dans les réglages.
  Future<void> applyCountry({String isoCode = '', String country = ''}) async {
    if (isManual) return;
    final iso = isoCode.isNotEmpty
        ? isoCode
        : (CountryCatalog.isoCodeFor(country) ?? '');
    await setLanguage(languageForCountry(iso, deviceLanguage: deviceLanguage()));
  }

  /// Langue professionnelle d'un pays, parmi celles de l'application.
  static String languageForCountry(
    String isoCode, {
    required String deviceLanguage,
  }) {
    final iso = isoCode.toUpperCase();
    if (frenchCountries.contains(iso)) return 'fr';
    if (bilingualCountries.contains(iso)) {
      return deviceLanguage == 'fr' ? 'fr' : 'en';
    }
    return 'en';
  }

  /// `fr` si le téléphone est en français, sinon `en`.
  static String deviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return code == 'fr' ? 'fr' : 'en';
  }

  static Locale localeFor(String code) => code == 'en' ? english : french;

  /// Ancien réglage « Français » / « English » rangé dans `preferences`.
  String? _legacyLanguage() {
    final prefs = _storage.read('preferences');
    if (prefs is! Map) return null;
    final value = prefs['language'];
    if (value == 'English') return 'en';
    if (value == 'Français') return 'fr';
    return null;
  }

  Future<void> _apply(String code) async {
    language.value = code;
    final locale = localeFor(code);
    final tag = locale.toString();
    Intl.defaultLocale = tag;
    await initializeDateFormatting(tag, null);
    timeago.setDefaultLocale(code);
  }
}
