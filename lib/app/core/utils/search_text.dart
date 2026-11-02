/// Comparaison de texte pour les filtres appliqués dans l'app : ni la casse ni
/// les accents ne comptent, et chaque mot saisi peut se trouver dans n'importe
/// quel champ, dans n'importe quel ordre (« yaounde paris » retrouve
/// Paris → Yaoundé).
class SearchText {
  const SearchText._();

  static const _accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ì': 'i',
    'ñ': 'n',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'œ': 'oe',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };

  static String normalize(String text) =>
      text.toLowerCase().split('').map((char) => _accents[char] ?? char).join();

  static bool matches(Iterable<String?> fields, String query) {
    final haystack = normalize(fields.whereType<String>().join(' '));
    return normalize(query)
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .every(haystack.contains);
  }
}
