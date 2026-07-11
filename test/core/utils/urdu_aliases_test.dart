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

    test('reversed daal word order works — people type "chana daal"', () {
      expect(canonicalsFor('chana daal'), ['daal chana']);
      expect(canonicalsFor('masoor daal'), ['daal masoor']);
      expect(canonicalsFor('moong daal'), ['daal moong']);
      expect(canonicalsFor('mash daal'), ['daal mash']);
      expect(canonicalsFor('mash ki daal'), ['daal mash']);
      expect(canonicalsFor('urad daal'), ['daal mash']);
    });

    test('dry fruits map to their seeded rows', () {
      expect(canonicalsFor('badam'), ['almonds']);
      expect(canonicalsFor('kaju'), ['cashews']);
      expect(canonicalsFor('kishmish'), ['raisins']);
      expect(canonicalsFor('moongphali'), ['peanuts']);
      expect(canonicalsFor('mumphali'), ['peanuts']);
      expect(canonicalsFor('akhrot'), ['walnuts']);
      expect(canonicalsFor('pista'), ['pistachios']);
    });

    test('English words reach the Urdu-primary produce rows', () {
      expect(canonicalsFor('guava'), ['amrood']);
      expect(canonicalsFor('watermelon'), ['tarbooz']);
      expect(canonicalsFor('melon'), ['kharbooza']);
      expect(canonicalsFor('pear'), ['nashpati']);
      expect(canonicalsFor('papaya'), ['papita']);
      expect(canonicalsFor('bottle gourd'), ['lauki']);
      expect(canonicalsFor('ridge gourd'), ['tori']);
      expect(canonicalsFor('taro'), ['arvi']);
      expect(canonicalsFor('sweet potato'), ['shakarkandi']);
      expect(canonicalsFor('fenugreek'), ['methi']);
      expect(canonicalsFor('corn'), ['makai']);
      expect(canonicalsFor('bhutta'), ['makai']);
      expect(canonicalsFor('broom'), ['jharoo']);
    });

    test('household brand-generics and spelling extras', () {
      expect(canonicalsFor('dettol'), ['antiseptic liquid']);
      expect(canonicalsFor('baisan'), ['besan']);
      expect(canonicalsFor('chai ki patti'), ['tea']);
    });

    test('PK brand-generics people actually say', () {
      expect(canonicalsFor('pampers'), ['diapers']);
      expect(canonicalsFor('panadol'), ['paracetamol']);
      expect(canonicalsFor('colgate'), ['toothpaste']);
      expect(canonicalsFor('dalda'), ['banaspati ghee']);
      expect(canonicalsFor('surf'), ['laundry detergent']);
      expect(canonicalsFor('harpic'), ['toilet cleaner']);
      expect(canonicalsFor('vim'), ['dishwashing liquid']);
      expect(canonicalsFor('phenyl'), ['floor cleaner']);
      expect(canonicalsFor('mortein'), ['mosquito repellent']);
    });

    test('everyday phrases and more variants', () {
      expect(canonicalsFor('kali daal'), ['daal mash']);
      expect(canonicalsFor('adrak lehsun'), containsAll(['ginger', 'garlic']));
      expect(canonicalsFor('thoom'), ['garlic']);
      expect(canonicalsFor('gaye ka gosht'), ['beef']);
      expect(canonicalsFor('chuhara'), ['dates']);
      expect(canonicalsFor('kaleji'), isEmpty,
          reason: 'kaleji is a seed row itself, direct match handles it');
      expect(canonicalsFor('liver'), ['kaleji']);
      expect(canonicalsFor('washing powder'), ['laundry detergent']);
      expect(canonicalsFor('pocha'), ['mop']);
      expect(canonicalsFor('kanghi'), ['comb']);
      expect(canonicalsFor('cold drink'), ['soft drink']);
      expect(canonicalsFor('papad'), ['papar']);
      expect(canonicalsFor('nan'), ['naan']);
      expect(canonicalsFor('zaitoon ka tel'), ['olive oil']);
    });

    test('medicines and pharmacy words people actually use', () {
      expect(canonicalsFor('brufen'), ['ibuprofen']);
      expect(canonicalsFor('disprin'), ['aspirin']);
      expect(canonicalsFor('eno'), ['antacid']);
      expect(canonicalsFor('strepsils'), ['lozenges']);
      expect(canonicalsFor('vicks'), ['balm']);
      expect(canonicalsFor('glucose d'), ['glucose powder']);
      expect(canonicalsFor('khansi ka syrup'), ['cough syrup']);
      expect(canonicalsFor('bukhar ki dawa'), ['paracetamol']);
      expect(canonicalsFor('cerelac'), ['baby cereal']);
      expect(canonicalsFor('chusni'), ['soother']);
      expect(canonicalsFor('vaseline'), ['petroleum jelly']);
    });

    test('household odds and ends', () {
      expect(canonicalsFor('mombatti'), ['candles']);
      expect(canonicalsFor('balti'), ['bucket']);
      expect(canonicalsFor('joona'), ['scrubber']);
      expect(canonicalsFor('chimtiyan'), ['clothes pegs']);
      expect(canonicalsFor('hara pyaz'), ['spring onion']);
      expect(canonicalsFor('tinda'), ['tinday']);
      expect(canonicalsFor('nariyal'), isEmpty,
          reason: 'nariyal is its own seed row');
      expect(canonicalsFor('coconut'), ['nariyal']);
      expect(canonicalsFor('knorr'), ['chicken cubes']);
      expect(canonicalsFor('blue band'), ['margarine']);
      expect(canonicalsFor('sting'), ['energy drink']);
      expect(canonicalsFor('tang'), ['powdered drink mix']);
      expect(canonicalsFor('mithai'), ['candy']);
    });

    test('the table is genuinely big now', () {
      expect(kUrduAliases.length, greaterThanOrEqualTo(380));
    });

    test('every Urdu display label targets a real seed row', () {
      final seeded =
          kSeedCatalog.map((e) => normalizeItemName(e.name)).toSet();
      for (final key in kUrduDisplayNames.keys) {
        expect(seeded, contains(key), reason: key);
      }
    });

    test('urduLabelFor: common pairs, null when same-enough', () {
      expect(urduLabelFor('milk'), 'Doodh');
      expect(urduLabelFor('eggs'), 'Anday');
      expect(urduLabelFor('vermicelli'), 'Sawaiyan');
      expect(urduLabelFor('paracetamol'), 'Panadol');
      expect(urduLabelFor('diapers'), 'Pampers');
      expect(urduLabelFor('lauki'), isNull, reason: 'already Urdu');
      expect(urduLabelFor('pizza base'), isNull);
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
