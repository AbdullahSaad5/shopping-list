import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/db/seed_catalog.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('fresh database ships the starter catalog, all rows marked seeded',
      () async {
    final rows = await db.select(db.catalogEntries).get();
    expect(rows.length, kSeedCatalog.length);
    expect(rows.length, greaterThanOrEqualTo(120));
    expect(rows.every((r) => r.isSeeded), isTrue);
    expect(rows.every((r) => r.timesPurchased == 0), isTrue);
    expect(rows.every((r) => r.lastPurchasedAt == null), isTrue);
  });

  test('seed names normalize uniquely and match their display names',
      () async {
    final rows = await db.select(db.catalogEntries).get();
    final normalized = rows.map((r) => r.nameNormalized).toSet();
    expect(normalized.length, rows.length, reason: 'no dupes after normalize');
    for (final r in rows) {
      expect(r.nameNormalized, normalizeItemName(r.displayName));
    }
  });

  test('every seed entry references a default category and a known unit',
      () async {
    final categoryIds =
        (await db.select(db.categories).get()).map((c) => c.id).toSet();
    final rows = await db.select(db.catalogEntries).get();
    for (final r in rows) {
      expect(r.categoryId, isNotNull, reason: r.displayName);
      expect(categoryIds, contains(r.categoryId), reason: r.displayName);
      expect(kUnitsSet, contains(r.defaultUnit), reason: r.displayName);
    }
  });

  test('prefix suggest surfaces starter entries on first run', () async {
    final listId = await ListRepository(db)
        .create(name: 'Groceries', colorSeed: 0, icon: 'shopping-basket');
    expect(listId, isPositive);

    final repo = ItemRepository(db);
    final milk = await repo.suggest('mil');
    expect(milk.map((e) => e.displayName), contains('Milk'));

    final egg = await repo.suggest('egg');
    expect(egg.map((e) => e.displayName), contains('Eggs'));
  });

  test('adding a seeded name updates the seed row instead of duplicating',
      () async {
    final listId = await ListRepository(db)
        .create(name: 'Groceries', colorSeed: 0, icon: 'shopping-basket');
    final before = (await db.select(db.catalogEntries).get()).length;

    await ItemRepository(db).add(listId, const ParsedItem(name: 'milk'));

    final rows = await db.select(db.catalogEntries).get();
    expect(rows.length, before, reason: 'learned into the seed row, no dupe');
    final milk = rows.singleWhere((r) => r.nameNormalized == 'milk');
    expect(milk.isSeeded, isTrue);
  });

  test('seeded category flows onto items added by name', () async {
    final listId = await ListRepository(db)
        .create(name: 'Groceries', colorSeed: 0, icon: 'shopping-basket');
    final repo = ItemRepository(db);

    await repo.add(listId, const ParsedItem(name: 'Milk'));
    final rows = await repo.watchForList(listId, ListSortMode.manual).first;
    final item = rows.open.single;

    final dairy = (await db.select(db.categories).get())
        .singleWhere((c) => c.name == 'Dairy & Eggs');
    expect(item.categoryId, dairy.id, reason: 'auto-categorized from seed');
  });
}
