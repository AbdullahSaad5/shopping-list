import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/db/seed.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('fresh database seeds the default aisle-ordered categories', () async {
    final categories = await db.select(db.categories).get();
    expect(categories, hasLength(14));
    expect(categories.first.name, 'Fruits & Vegetables');
    expect(categories.last.name, 'Other');
    // Aisle order is the position column, 0-based and gapless.
    expect(
      categories.map((c) => c.position),
      List.generate(14, (i) => i),
    );
    expect(categories.every((c) => c.isDefault), isTrue);
    // Sync-ready columns present from day 1.
    expect(categories.every((c) => c.uuid.isNotEmpty), isTrue);
  });

  test('catalog starts empty — suggestions are learned, not shipped',
      () async {
    expect(await db.select(db.catalogEntries).get(), isEmpty);
  });

  test('units list offers pcs first', () {
    expect(kUnits.first, 'pcs');
    expect(kUnits, contains('kg'));
  });

  test('lists and items round-trip with cascade delete', () async {
    final listId = await db.into(db.shoppingLists).insert(
          ShoppingListsCompanion.insert(
            name: 'Groceries',
            colorSeed: 0,
            icon: 'shopping-basket',
            position: 0,
          ),
        );
    await db.into(db.items).insert(
          ItemsCompanion.insert(name: 'Milk', listId: listId, position: 0),
        );

    final items = await db.select(db.items).get();
    expect(items.single.name, 'Milk');
    expect(items.single.unit, 'pcs');
    expect(items.single.quantity, 1);
    expect(items.single.checked, isFalse);

    await (db.delete(db.shoppingLists)
          ..where((l) => l.id.equals(listId)))
        .go();
    expect(await db.select(db.items).get(), isEmpty,
        reason: 'items cascade with their list');
  });

  test('deleting a category nulls the item reference, not the item',
      () async {
    final listId = await db.into(db.shoppingLists).insert(
          ShoppingListsCompanion.insert(
            name: 'L',
            colorSeed: 0,
            icon: 'x',
            position: 0,
          ),
        );
    final cat = (await db.select(db.categories).get()).first;
    await db.into(db.items).insert(
          ItemsCompanion.insert(
            name: 'Apples',
            listId: listId,
            position: 0,
            categoryId: Value(cat.id),
          ),
        );
    await (db.delete(db.categories)..where((c) => c.id.equals(cat.id))).go();
    final item = (await db.select(db.items).get()).single;
    expect(item.name, 'Apples');
    expect(item.categoryId, isNull);
  });

  test('catalog nameNormalized is unique', () async {
    await db.into(db.catalogEntries).insert(
          CatalogEntriesCompanion.insert(
            nameNormalized: 'milk',
            displayName: 'Milk',
          ),
        );
    expect(
      () => db.into(db.catalogEntries).insert(
            CatalogEntriesCompanion.insert(
              nameNormalized: 'milk',
              displayName: 'MILK',
            ),
          ),
      throwsA(anything),
    );
  });
}
