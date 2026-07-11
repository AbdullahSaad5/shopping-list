import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

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

  test('create appends positions; watchActive sorts pinned first', () async {
    final a = await lists.create(name: 'A', colorSeed: 0, icon: 'basket');
    final b = await lists.create(name: 'B', colorSeed: 1, icon: 'basket');
    await lists.setPinned(b, pinned: true);

    final active = await lists.watchActive().first;
    expect(active.map((l) => l.id), [b, a]);
  });

  test('archive and tombstone leave watchActive', () async {
    final a = await lists.create(name: 'A', colorSeed: 0, icon: 'basket');
    final b = await lists.create(name: 'B', colorSeed: 0, icon: 'basket');
    await lists.setArchived(a, archived: true);
    await lists.delete(b);

    expect(await lists.watchActive().first, isEmpty);
    final archived = await lists.watchArchived().first;
    expect(archived.map((l) => l.id), [a], reason: 'tombstoned ≠ archived');
  });

  test('reorder rewrites compact positions', () async {
    final a = await lists.create(name: 'A', colorSeed: 0, icon: 'basket');
    final b = await lists.create(name: 'B', colorSeed: 0, icon: 'basket');
    final c = await lists.create(name: 'C', colorSeed: 0, icon: 'basket');
    await lists.reorder([c, a, b]);

    final active = await lists.watchActive().first;
    expect(active.map((l) => l.name), ['C', 'A', 'B']);
  });

  test('update renames and clears budget explicitly', () async {
    final id = await lists.create(
      name: 'Groceries',
      colorSeed: 0,
      icon: 'basket',
      budgetMinor: 500000,
    );
    await lists.update(id, name: 'Weekly shop');
    var row = (await lists.watchActive().first).single;
    expect(row.name, 'Weekly shop');
    expect(row.budgetMinor, 500000, reason: 'absent field untouched');

    await lists.update(id, clearBudget: true);
    row = (await lists.watchActive().first).single;
    expect(row.budgetMinor, isNull);
  });

  test('watchActiveWithStats counts, checks, and estimates', () async {
    final id = await lists.create(name: 'G', colorSeed: 0, icon: 'basket');
    final milk = await items.add(id, const ParsedItem(name: 'Milk'));
    await items.add(
      id,
      const ParsedItem(name: 'Eggs', quantity: 2),
      priceMinor: 30000,
    );
    await items.setChecked(milk, checked: true);

    final stats = (await lists.watchActiveWithStats().first).single;
    expect(stats.totalItems, 2);
    expect(stats.checkedItems, 1);
    expect(stats.estimatedTotalMinor, 60000, reason: 'price × quantity');
    expect(stats.progress, 0.5);
  });

  test('stats stream re-emits when an item changes', () async {
    final id = await lists.create(name: 'G', colorSeed: 0, icon: 'basket');
    final stream = lists.watchActiveWithStats();
    final first = await stream.first;
    expect(first.single.totalItems, 0);

    // A fresh listen after a write must see the new state (regression shape
    // that bit ledgr's debts screen).
    await items.add(id, const ParsedItem(name: 'Milk'));
    final second = await stream.first;
    expect(second.single.totalItems, 1);
  });
}
