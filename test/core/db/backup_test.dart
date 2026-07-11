import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/backup.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/core/utils/share_codec.dart' show ImportException;
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';
import 'package:tokri/features/trips/data/trip_repository.dart';

void main() {
  test('backup round-trips the whole database', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);

    final lists = ListRepository(source);
    final items = ItemRepository(source);
    final listId = await lists.create(
      name: 'Groceries',
      colorSeed: 3,
      icon: 'shopping-basket',
      budgetMinor: 500000,
    );
    final milk = await items.add(
      listId,
      const ParsedItem(name: 'Milk', quantity: 2),
      priceMinor: 45000,
    );
    await items.setChecked(milk, checked: true);
    await TripRepository(source).completeTrip(
      listId,
      startedAt: DateTime(2026, 7, 11, 9),
      now: DateTime(2026, 7, 11, 9, 20),
    );
    // A tombstone must survive backup (sync contract).
    final bread = await items.add(listId, const ParsedItem(name: 'Bread'));
    await items.delete(bread);

    final json = await exportBackup(source);

    final target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(target.close);
    await importBackup(target, json);

    final restoredLists = await target.select(target.shoppingLists).get();
    expect(restoredLists.single.name, 'Groceries');
    expect(restoredLists.single.budgetMinor, 500000);

    final restoredItems = await target.select(target.items).get();
    expect(restoredItems, hasLength(2));
    final restoredMilk =
        restoredItems.singleWhere((i) => i.name == 'Milk');
    expect(restoredMilk.checked, isTrue);
    expect(restoredMilk.priceMinor, 45000);
    expect(restoredMilk.listId, restoredLists.single.id);
    expect(
      restoredItems.singleWhere((i) => i.name == 'Bread').deletedAt,
      isNotNull,
    );

    final restoredTrips = await target.select(target.trips).get();
    expect(restoredTrips.single.itemCount, 1);
    expect(restoredTrips.single.totalSpentMinor, 90000);

    // Catalog learning came along (seeds + learned rows, same count).
    final sourceCatalog = await source.select(source.catalogEntries).get();
    final targetCatalog = await target.select(target.catalogEntries).get();
    expect(targetCatalog.length, sourceCatalog.length);

    // Import replaced the target's seed categories, not duplicated them.
    final sourceCats = await source.select(source.categories).get();
    final targetCats = await target.select(target.categories).get();
    expect(targetCats.length, sourceCats.length);
  });

  test('malformed or wrong-version backups are rejected cleanly', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await expectLater(
      importBackup(db, 'not json at all'),
      throwsA(isA<ImportException>()),
    );
    await expectLater(
      importBackup(db, '{"v":99}'),
      throwsA(isA<ImportException>()),
    );
    await expectLater(
      importBackup(db, '{"v":1}'),
      throwsA(isA<ImportException>()),
    );

    // Nothing was wiped by the failed imports.
    expect(await db.select(db.categories).get(), isNotEmpty);
  });
}
