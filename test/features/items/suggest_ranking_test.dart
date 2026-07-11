import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

void main() {
  late AppDatabase db;
  late ItemRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ItemRepository(db);
  });
  tearDown(() => db.close());

  Future<int> insertCatalog(
    String name, {
    int timesPurchased = 0,
    DateTime? lastPurchasedAt,
    bool isSeeded = false,
  }) =>
      db.into(db.catalogEntries).insert(
            CatalogEntriesCompanion.insert(
              nameNormalized: normalizeItemName(name),
              displayName: name,
              timesPurchased: Value(timesPurchased),
              lastPurchasedAt: Value(lastPurchasedAt),
              isSeeded: Value(isSeeded),
            ),
          );

  group('suggest ranking (M2)', () {
    test('prefix matches rank above substring matches', () async {
      // 'quin' is outside both the seed catalog and the alias table
      // ('ka' would drown in alias fan-out).
      await insertCatalog('Quinoa');
      // Substring hit with a much higher purchase count still loses to
      // the prefix hit.
      await insertCatalog('Red quinoa', timesPurchased: 50);

      final hits = await repo.suggest('quin');
      final names = hits.map((h) => h.displayName).toList();
      expect(
        names.indexOf('Quinoa'),
        lessThan(names.indexOf('Red quinoa')),
      );
    });

    test('within a match tier: frequency desc, then recency desc', () async {
      // 'zorba' is deliberately absent from both the seed catalog and the
      // Roman-Urdu alias table ('anday' would alias-hit Eggs).
      await insertCatalog('Zorba desi', timesPurchased: 2);
      await insertCatalog('Zorba farmi', timesPurchased: 9);
      await insertCatalog(
        'Zorba duck',
        timesPurchased: 2,
        lastPurchasedAt: DateTime(2026, 7, 1),
      );

      final hits = await repo.suggest('zorba');
      expect(
        hits.map((h) => h.displayName).toList(),
        ['Zorba farmi', 'Zorba duck', 'Zorba desi'],
      );
    });

    test('substring matching finds mid-word hits', () async {
      final hits = await repo.suggest('powder');
      expect(
        hits.map((h) => h.displayName),
        containsAll(['Milk powder', 'Red chilli powder']),
      );
    });

    test('respects the limit across both tiers', () async {
      final hits = await repo.suggest('a', limit: 5);
      expect(hits, hasLength(5));
    });
  });

  group('topSuggestions (idle chips, M2)', () {
    late int listId;

    setUp(() async {
      listId = await ListRepository(db)
          .create(name: 'Groceries', colorSeed: 0, icon: 'shopping-basket');
    });

    test('learned entries surface; untouched seeded entries do not',
        () async {
      await repo.add(listId, const ParsedItem(name: 'Choco spread'));
      // Learned onto another list — still counts as history.
      final other = await ListRepository(db)
          .create(name: 'Party', colorSeed: 1, icon: 'gift');
      await repo.add(other, const ParsedItem(name: 'Paper cups'));

      final top = await repo.topSuggestions(listId);
      final names = top.map((t) => t.displayName).toList();
      expect(names, contains('Paper cups'));
      // 'Choco spread' is already on THIS list → excluded.
      expect(names, isNot(contains('Choco spread')));
      // Seeded rows with zero history stay out of idle chips.
      expect(names, isNot(contains('Milk')));
    });

    test('purchased seeded entries do surface, frequency first', () async {
      await db.update(db.catalogEntries).write(
            const CatalogEntriesCompanion(timesPurchased: Value(0)),
          );
      Future<void> bump(String normalized, int times) =>
          (db.update(db.catalogEntries)
                ..where((c) => c.nameNormalized.equals(normalized)))
              .write(CatalogEntriesCompanion(timesPurchased: Value(times)));
      await bump('milk', 5);
      await bump('eggs', 9);

      final top = await repo.topSuggestions(listId);
      expect(
        top.map((t) => t.displayName).take(2).toList(),
        ['Eggs', 'Milk'],
      );
    });

    test('checked items still count as on-list; deleted ones do not',
        () async {
      final milkId = await repo.add(listId, const ParsedItem(name: 'Milk'));
      await (db.update(db.catalogEntries)
            ..where((c) => c.nameNormalized.equals('milk')))
          .write(const CatalogEntriesCompanion(timesPurchased: Value(3)));

      await repo.setChecked(milkId, checked: true);
      var names =
          (await repo.topSuggestions(listId)).map((t) => t.displayName);
      expect(names, isNot(contains('Milk')), reason: 'checked = on list');

      await repo.delete(milkId);
      names = (await repo.topSuggestions(listId)).map((t) => t.displayName);
      expect(names, contains('Milk'), reason: 'deleted = suggestable again');
    });

    test('caps at 10', () async {
      for (var i = 0; i < 14; i++) {
        await insertCatalog('Learned $i', timesPurchased: i + 1);
      }
      final top = await repo.topSuggestions(listId);
      expect(top, hasLength(10));
    });
  });
}
