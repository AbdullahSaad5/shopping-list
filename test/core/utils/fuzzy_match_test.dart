import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/utils/fuzzy_match.dart';

void main() {
  group('boundedDamerau', () {
    test('classic distances', () {
      expect(boundedDamerau('milk', 'milk', 2), 0);
      expect(boundedDamerau('mlik', 'milk', 2), 1, reason: 'transposition');
      expect(boundedDamerau('tomatos', 'tomatoes', 2), 1);
      expect(boundedDamerau('chesse', 'cheese', 2), 1);
      expect(boundedDamerau('doodg', 'doodh', 2), 1);
    });

    test('gives up past the bound', () {
      expect(boundedDamerau('apple', 'zucchini', 2), greaterThan(2));
    });
  });

  group('fuzzyMatches', () {
    test('typos within budget match', () {
      expect(fuzzyMatches('mlik', 'milk'), isTrue);
      expect(fuzzyMatches('tomatos', 'tomatoes'), isTrue);
      expect(fuzzyMatches('sawayan', 'sawaiyan'), isTrue);
      expect(fuzzyMatches('cheni', 'cheeni'), isTrue);
      expect(fuzzyMatches('shampu', 'shampoo'), isTrue);
    });

    test('prefix typing with a typo still matches long names', () {
      // Typing "tamato" against "tomatoes" — compare against the prefix.
      expect(fuzzyMatches('tamato', 'tomatoes'), isTrue);
      expect(fuzzyMatches('vermicel', 'vermicelli'), isTrue);
    });

    test('multi-word candidates match on any word', () {
      expect(fuzzyMatches('bikrani', 'biryani masala'), isTrue);
      expect(fuzzyMatches('masalla', 'garam masala'), isTrue);
    });

    test('short queries never fuzz (too noisy)', () {
      expect(fuzzyMatches('ml', 'milk'), isFalse);
      expect(
        fuzzyMatches('mik', 'milk'),
        isFalse,
        reason: '3 chars: exact only',
      );
    });

    test('unrelated words stay unmatched', () {
      expect(fuzzyMatches('quinoa', 'milk'), isFalse);
      expect(fuzzyMatches('candles', 'noodles'), isFalse);
      expect(fuzzyMatches('mehndi', 'mineral water'), isFalse);
    });
  });
}
