import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';
import 'package:tokri/features/lists/data/search_repository.dart';

void main() {
  late AppDatabase db;
  late ListRepository lists;
  late ItemRepository items;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    lists = ListRepository(db);
    items = ItemRepository(db);
  });
  tearDown(() => db.close());

  group('templates', () {
    test('saveAsTemplate copies the list and items, unchecked', () async {
      final listId = await lists.create(
        name: 'Weekly',
        colorSeed: 0,
        icon: 'shopping-basket',
      );
      final milk = await items.add(listId, const ParsedItem(name: 'Milk'));
      await items.add(
        listId,
        const ParsedItem(name: 'Flour', quantity: 500, unit: 'g'),
      );
      await items.setChecked(milk, checked: true);

      final templateId = await lists.saveAsTemplate(listId);

      final templates = await lists.watchTemplates().first;
      expect(templates.single.id, templateId);
      expect(templates.single.isTemplate, isTrue);
      expect(templates.single.name, 'Weekly');

      final rows =
          await items.watchForList(templateId, ListSortMode.manual).first;
      expect(rows.open, hasLength(2), reason: 'checked state resets');
      expect(rows.done, isEmpty);
      // The original list is untouched.
      final original =
          await items.watchForList(listId, ListSortMode.manual).first;
      expect(original.done, hasLength(1));
      // Templates never show on the active home stream.
      expect(
        (await lists.watchActive().first).map((l) => l.id),
        isNot(contains(templateId)),
      );
    });

    test('instantiate creates a fresh list from the template', () async {
      final listId = await lists.create(
        name: 'Weekly',
        colorSeed: 2,
        icon: 'wrench',
      );
      await items.add(listId, const ParsedItem(name: 'Milk'));
      final templateId = await lists.saveAsTemplate(listId);

      final newId =
          await lists.instantiateTemplate(templateId, name: 'Week 29');

      final active = await lists.watchActive().first;
      final created = active.singleWhere((l) => l.id == newId);
      expect(created.name, 'Week 29');
      expect(created.colorSeed, 2);
      expect(created.isTemplate, isFalse);
      final rows = await items.watchForList(newId, ListSortMode.manual).first;
      expect(rows.open.single.name, 'Milk');
    });

    test('deleting a template does not touch instantiated lists', () async {
      final listId = await lists.create(
        name: 'Weekly',
        colorSeed: 0,
        icon: 'shopping-basket',
      );
      await items.add(listId, const ParsedItem(name: 'Milk'));
      final templateId = await lists.saveAsTemplate(listId);
      final newId = await lists.instantiateTemplate(templateId);

      await lists.delete(templateId);

      expect(await lists.watchTemplates().first, isEmpty);
      final rows = await items.watchForList(newId, ListSortMode.manual).first;
      expect(rows.open, hasLength(1));
    });
  });

  group('search', () {
    late SearchRepository search;

    setUp(() => search = SearchRepository(db));

    test('matches item names across lists and list names', () async {
      final groceries = await lists.create(
        name: 'Groceries',
        colorSeed: 0,
        icon: 'shopping-basket',
      );
      final hardware = await lists.create(
        name: 'Hardware run',
        colorSeed: 1,
        icon: 'wrench',
      );
      await items.add(groceries, const ParsedItem(name: 'Milk'));
      await items.add(hardware, const ParsedItem(name: 'Wall paint'));

      final result = await search.search('milk');
      expect(result.items.single.item.name, 'Milk');
      expect(result.items.single.list.name, 'Groceries');
      expect(result.lists, isEmpty);

      final byList = await search.search('hardware');
      expect(byList.lists.single.name, 'Hardware run');

      final substring = await search.search('paint');
      expect(substring.items.single.item.name, 'Wall paint');
    });

    test('skips tombstoned and template rows; empty query is empty',
        () async {
      final listId = await lists.create(
        name: 'Groceries',
        colorSeed: 0,
        icon: 'shopping-basket',
      );
      final milk = await items.add(listId, const ParsedItem(name: 'Milk'));
      await items.delete(milk);
      await lists.saveAsTemplate(listId);

      final result = await search.search('milk');
      expect(result.items, isEmpty);
      final listHits = await search.search('groceries');
      expect(listHits.lists, hasLength(1), reason: 'template excluded');

      final empty = await search.search('   ');
      expect(empty.items, isEmpty);
      expect(empty.lists, isEmpty);
    });
  });
}
