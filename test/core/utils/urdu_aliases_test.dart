import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/seed_catalog.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/core/utils/urdu_aliases.dart';

void main() {
  test('every alias target exists in the seed catalog', () {
    final seeded =
        kSeedCatalog.map((e) => normalizeItemName(e.name)).toSet();
    for (final entry in kUrduAliases.entries) {
      for (final target in entry.value) {
        expect(
          seeded,
          contains(target),
          reason: "alias '${entry.key}' points at missing '$target'",
        );
      }
    }
  });

  test('alias keys are already normalized (lowercase, trimmed)', () {
    for (final key in kUrduAliases.keys) {
      expect(key, normalizeItemName(key), reason: key);
    }
  });

  group('canonicalsFor', () {
    test('maps everyday Roman-Urdu words with spelling variants', () {
      expect(canonicalsFor('doodh'), ['milk']);
      expect(canonicalsFor('dudh'), ['milk']);
      expect(canonicalsFor('dahi'), ['yogurt']);
      expect(canonicalsFor('anday'), ['eggs']);
      expect(canonicalsFor('ande'), ['eggs']);
      expect(canonicalsFor('chawal'), ['basmati rice']);
      expect(canonicalsFor('cheeni'), ['sugar']);
      expect(canonicalsFor('chini'), ['sugar']);
      expect(canonicalsFor('aloo'), ['potatoes']);
      expect(canonicalsFor('pyaz'), ['onions']);
      expect(canonicalsFor('tamatar'), ['tomatoes']);
      expect(canonicalsFor('haldi'), ['turmeric powder']);
      expect(canonicalsFor('zeera'), ['cumin']);
      expect(canonicalsFor('machli'), ['fish']);
      expect(canonicalsFor('murghi'), ['chicken']);
    });

    test('edge cases: sawaiyan spellings hit vermicelli', () {
      for (final variant in ['sawaiyan', 'sewaiyan', 'seviyan', 'sawayyan']) {
        expect(canonicalsFor(variant), ['vermicelli'], reason: variant);
      }
    });

    test('ambiguous words fan out: gosht, daal, tel', () {
      expect(canonicalsFor('gosht'), containsAll(['beef', 'mutton']));
      expect(
        canonicalsFor('dal'),
        containsAll(['daal chana', 'daal masoor', 'daal moong', 'daal mash']),
      );
      expect(canonicalsFor('tel'), contains('cooking oil'));
    });

    test('unknown words return empty', () {
      expect(canonicalsFor('quinoa'), isEmpty);
      expect(canonicalsFor(''), isEmpty);
    });
  });

  group('aliasCanonicalsForPrefix', () {
    test('partial typing surfaces the alias targets', () {
      expect(aliasCanonicalsForPrefix('sawai'), contains('vermicelli'));
      expect(aliasCanonicalsForPrefix('chee'), contains('sugar'));
      expect(aliasCanonicalsForPrefix('doo'), contains('milk'));
    });

    test('needs at least two characters to fire', () {
      expect(aliasCanonicalsForPrefix('d'), isEmpty);
      expect(aliasCanonicalsForPrefix(''), isEmpty);
    });
  });
}
