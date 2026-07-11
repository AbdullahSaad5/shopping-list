import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

void main() {
  late AppDatabase db;
  late ItemRepository repo;
  late int listId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ItemRepository(db);
    listId = await ListRepository(db)
        .create(name: 'Groceries', colorSeed: 0, icon: 'shopping-basket');
  });
  tearDown(() => db.close());

  Future<Category> categoryOf(Item item) async =>
      (db.select(db.categories)..where((c) => c.id.equals(item.categoryId!)))
          .getSingle();

  group('suggest understands Roman Urdu', () {
    test('full words map through the alias table', () async {
      expect(
        (await repo.suggest('doodh')).map((e) => e.displayName),
        contains('Milk'),
      );
      expect(
        (await repo.suggest('cheeni')).map((e) => e.displayName),
        contains('Sugar'),
      );
      expect(
        (await repo.suggest('anday')).map((e) => e.displayName),
        contains('Eggs'),
      );
    });

    test('partial typing already surfaces the target', () async {
      expect(
        (await repo.suggest('sawai')).map((e) => e.displayName),
        contains('Vermicelli'),
      );
      expect(
        (await repo.suggest('tama')).map((e) => e.displayName),
        contains('Tomatoes'),
      );
    });

    test('ambiguous dal fans out to every daal', () async {
      final names =
          (await repo.suggest('dal', limit: 12)).map((e) => e.displayName);
      expect(
        names,
        containsAll(
          ['Daal chana', 'Daal masoor', 'Daal moong', 'Daal mash'],
        ),
      );
    });

    test('alias hits do not duplicate normal matches', () async {
      // 'daal' prefix-matches the seeded rows directly AND via alias.
      final hits = await repo.suggest('daal', limit: 12);
      final ids = hits.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'no duplicate rows');
    });
  });

  group('fuzzy suggest (bad typing welcome)', () {
    test('English typos still find the row', () async {
      expect(
        (await repo.suggest('tomatos')).map((e) => e.displayName),
        contains('Tomatoes'),
      );
      expect(
        (await repo.suggest('chesse')).map((e) => e.displayName),
        contains('Cheese'),
      );
      expect(
        (await repo.suggest('vermicelli'.replaceAll('ll', 'l')))
            .map((e) => e.displayName),
        contains('Vermicelli'),
      );
    });

    test('Roman-Urdu typos resolve through the alias table', () async {
      // 'sawaian' is not an alias key; fuzzy hits 'sawaiyan' → Vermicelli.
      expect(
        (await repo.suggest('sawaian')).map((e) => e.displayName),
        contains('Vermicelli'),
      );
      expect(
        (await repo.suggest('chenni')).map((e) => e.displayName),
        contains('Sugar'),
      );
      expect(
        (await repo.suggest('dhodh')).map((e) => e.displayName),
        contains('Milk'),
      );
      expect(
        (await repo.suggest('tamatr')).map((e) => e.displayName),
        contains('Tomatoes'),
      );
    });

    test('exact matches always outrank fuzzy fill', () async {
      final names =
          (await repo.suggest('milk')).map((e) => e.displayName).toList();
      expect(names.first, 'Milk');
    });

    test('short garbage stays empty', () async {
      expect(await repo.suggest('zx'), isEmpty);
    });
  });

  group('adding a Roman-Urdu item', () {
    test('keeps the typed name but categorizes via the alias', () async {
      await repo.add(listId, const ParsedItem(name: 'Anday'));
      final rows = await repo.watchForList(listId, ListSortMode.manual).first;
      final item = rows.open.single;
      expect(item.name, 'Anday', reason: "user's word is the display name");
      expect((await categoryOf(item)).name, 'Dairy & Eggs');
    });

    test('handles the sawaiyan edge case', () async {
      await repo.add(listId, const ParsedItem(name: 'Sawaiyan'));
      final item =
          (await repo.watchForList(listId, ListSortMode.manual).first)
              .open
              .single;
      expect((await categoryOf(item)).name, 'Rice, Flour & Grains');
    });

    test('ambiguous gosht takes the first canonical (beef aisle)', () async {
      await repo.add(listId, const ParsedItem(name: 'Gosht'));
      final item =
          (await repo.watchForList(listId, ListSortMode.manual).first)
              .open
              .single;
      expect((await categoryOf(item)).name, 'Meat & Fish');
    });

    test('unknown words still land uncategorized', () async {
      await repo.add(listId, const ParsedItem(name: 'Mystery thing'));
      final item =
          (await repo.watchForList(listId, ListSortMode.manual).first)
              .open
              .single;
      expect(item.categoryId, isNull);
    });
  });
}
