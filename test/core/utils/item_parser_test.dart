import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/utils/item_parser.dart';

void main() {
  group('parseItems — single entries', () {
    test('bare name defaults to 1 pcs', () {
      final items = parseItems('milk');
      expect(items, hasLength(1));
      expect(items.single.name, 'milk');
      expect(items.single.quantity, 1);
      expect(items.single.unit, 'pcs');
    });

    test('trims and collapses whitespace', () {
      expect(parseItems('  brown   bread ').single.name, 'brown bread');
    });

    test('2x eggs', () {
      final item = parseItems('2x eggs').single;
      expect(item.name, 'eggs');
      expect(item.quantity, 2);
      expect(item.unit, 'pcs');
    });

    test('2 x eggs with spaces', () {
      final item = parseItems('2 x eggs').single;
      expect(item.name, 'eggs');
      expect(item.quantity, 2);
    });

    test('leading count without x', () {
      final item = parseItems('3 lemons').single;
      expect(item.name, 'lemons');
      expect(item.quantity, 3);
      expect(item.unit, 'pcs');
    });

    test('500g flour becomes grams', () {
      final item = parseItems('500g flour').single;
      expect(item.name, 'flour');
      expect(item.quantity, 500);
      expect(item.unit, 'g');
    });

    test('unit with space: 2 kg atta', () {
      final item = parseItems('2 kg atta').single;
      expect(item.name, 'atta');
      expect(item.quantity, 2);
      expect(item.unit, 'kg');
    });

    test('decimal quantities, dot and comma', () {
      expect(parseItems('1.5 kg chicken').single.quantity, 1.5);
      expect(parseItems('2,5 kg sugar').single.quantity, 2.5);
    });

    test('litres canonicalize to L', () {
      expect(parseItems('2l milk').single.unit, 'L');
      expect(parseItems('500ml cream').single.unit, 'ml');
    });

    test('dozen and pack', () {
      final dozen = parseItems('1 dozen eggs').single;
      expect(dozen.unit, 'dozen');
      expect(dozen.name, 'eggs');
      expect(parseItems('2 pack noodles').single.unit, 'pack');
    });

    test('unit words are case-insensitive', () {
      expect(parseItems('500G flour').single.unit, 'g');
      expect(parseItems('2KG rice').single.unit, 'kg');
    });

    test('a number alone is not an item', () {
      expect(parseItems('42'), isEmpty);
    });

    test('name that starts with a digit but is not a quantity', () {
      // "7up" must not become quantity 7, name "up"... it stays a name.
      final item = parseItems('7up').single;
      expect(item.name, '7up');
      expect(item.quantity, 1);
    });
  });

  group('parseItems — splitting', () {
    test('newlines split items', () {
      final items = parseItems('milk\n2x eggs\nbread');
      expect(items.map((i) => i.name), ['milk', 'eggs', 'bread']);
      expect(items[1].quantity, 2);
    });

    test('commas split items', () {
      final items = parseItems('milk, bread, 500g butter');
      expect(items, hasLength(3));
      expect(items.last.unit, 'g');
    });

    test('" and " splits items', () {
      final items = parseItems('milk and bread and 2 lemons');
      expect(items.map((i) => i.name), ['milk', 'bread', 'lemons']);
    });

    test('"and" inside a word does not split', () {
      final items = parseItems('pandan leaves');
      expect(items.single.name, 'pandan leaves');
    });

    test('blank segments are dropped', () {
      expect(parseItems('milk,\n\n, ,bread'), hasLength(2));
    });

    test('mixed separators', () {
      final items = parseItems('2x eggs, 500g flour\nmilk and 1.5L juice');
      expect(items, hasLength(4));
      expect(items[3].unit, 'L');
      expect(items[3].quantity, 1.5);
    });
  });

  group('normalizeItemName', () {
    test('lowercases and trims for the catalog key', () {
      expect(normalizeItemName('  Brown Bread '), 'brown bread');
    });

    test('collapses inner whitespace', () {
      expect(normalizeItemName('brown   bread'), 'brown bread');
    });
  });
}
