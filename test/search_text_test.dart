import 'package:asso/app/core/utils/search_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchText', () {
    test('ignore les accents et la casse, des deux côtés', () {
      expect(SearchText.matches(['Yaoundé'], 'yaounde'), isTrue);
      expect(SearchText.matches(['Yaounde'], 'YAOUNDÉ'), isTrue);
    });

    test('chaque mot peut être dans un champ différent, dans n\'importe quel ordre', () {
      expect(SearchText.matches(['Paris', 'Yaoundé'], 'yaounde paris'), isTrue);
      expect(SearchText.matches(['Paris', 'Douala'], 'yaounde paris'), isFalse);
    });

    test('une saisie vide ne filtre rien et un champ absent ne casse pas', () {
      expect(SearchText.matches(['Paris'], '   '), isTrue);
      expect(SearchText.matches([null, 'Paris'], 'paris'), isTrue);
    });
  });
}
