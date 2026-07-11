import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';
import 'package:tokri/features/trips/data/trip_repository.dart';

void main() {
  late AppDatabase db;
  late ItemRepository items;
  late TripRepository trips;
  late int listId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    items = ItemRepository(db);
    trips = TripRepository(db);
    listId = await ListRepository(db)
        .create(name: 'Weekly shop', colorSeed: 0, icon: 'shopping-basket');
  });
  tearDown(() => db.close());

  Future<Item> itemById(int id) =>
      (db.select(db.items)..where((i) => i.id.equals(id))).getSingle();

  test('completeTrip snapshots checked items into a denormalized row',
      () async {
    final milk = await items.add(
      listId,
      const ParsedItem(name: 'Milk', quantity: 2),
      priceMinor: 25000,
    );
    final eggs =
        await items.add(listId, const ParsedItem(name: 'Eggs'));
    await items.add(listId, const ParsedItem(name: 'Bread')); // stays open
    await items.setChecked(milk, checked: true);
    await items.setChecked(eggs, checked: true);

    final started = DateTime(2026, 7, 11, 9);
    final trip = await trips.completeTrip(
      listId,
      startedAt: started,
      now: DateTime(2026, 7, 11, 9, 25),
    );

    expect(trip.listName, 'Weekly shop');
    expect(trip.itemCount, 2);
    expect(trip.totalSpentMinor, 50000, reason: 'only priced+checked lines');
    expect(trip.durationSeconds, 25 * 60);
    expect(trip.listId, listId);
  });

  test('completeTrip with nothing priced records a null total', () async {
    final id = await items.add(listId, const ParsedItem(name: 'Eggs'));
    await items.setChecked(id, checked: true);

    final trip = await trips.completeTrip(
      listId,
      startedAt: DateTime(2026, 7, 11, 9),
      now: DateTime(2026, 7, 11, 9, 5),
    );
    expect(trip.totalSpentMinor, isNull);
    expect(trip.itemCount, 1);
  });

  test('completeTrip bumps purchase counters for checked items only',
      () async {
    final milk = await items.add(listId, const ParsedItem(name: 'Milk'));
    await items.add(listId, const ParsedItem(name: 'Bread'));
    await items.setChecked(milk, checked: true);

    final now = DateTime(2026, 7, 11, 10);
    await trips.completeTrip(
      listId,
      startedAt: DateTime(2026, 7, 11, 9),
      now: now,
    );

    final catalog = await db.select(db.catalogEntries).get();
    final milkEntry =
        catalog.singleWhere((c) => c.nameNormalized == 'milk');
    final breadEntry =
        catalog.singleWhere((c) => c.nameNormalized == 'bread');
    expect(milkEntry.timesPurchased, 1);
    expect(milkEntry.lastPurchasedAt, now);
    expect(breadEntry.timesPurchased, 0);
    expect(breadEntry.lastPurchasedAt, isNull);

    // A second trip keeps counting.
    await items.setChecked(milk, checked: true);
    await trips.completeTrip(
      listId,
      startedAt: now,
      now: now.add(const Duration(minutes: 10)),
    );
    final again = await db.select(db.catalogEntries).get();
    expect(
      again.singleWhere((c) => c.nameNormalized == 'milk').timesPurchased,
      2,
    );
  });

  test('completeTrip can clear the checked section', () async {
    final milk = await items.add(listId, const ParsedItem(name: 'Milk'));
    await items.add(listId, const ParsedItem(name: 'Bread'));
    await items.setChecked(milk, checked: true);

    await trips.completeTrip(
      listId,
      startedAt: DateTime(2026, 7, 11, 9),
      now: DateTime(2026, 7, 11, 9, 30),
      clearChecked: true,
    );

    final rows = await items.watchForList(listId, ListSortMode.manual).first;
    expect(rows.done, isEmpty);
    expect(rows.open, hasLength(1));
  });

  test('setPrice writes the item and remembers it in the catalog', () async {
    final milk = await items.add(listId, const ParsedItem(name: 'Milk'));

    await trips.setPrice(milk, priceMinor: 45000);

    expect((await itemById(milk)).priceMinor, 45000);
    final entry = (await db.select(db.catalogEntries).get())
        .singleWhere((c) => c.nameNormalized == 'milk');
    expect(entry.lastPriceMinor, 45000, reason: 'price memory');
  });

  test('watchRecent returns newest first', () async {
    final a = await items.add(listId, const ParsedItem(name: 'Milk'));
    await items.setChecked(a, checked: true);
    await trips.completeTrip(
      listId,
      startedAt: DateTime(2026, 7, 10, 9),
      now: DateTime(2026, 7, 10, 9, 10),
    );
    final b = await items.add(listId, const ParsedItem(name: 'Eggs'));
    await items.setChecked(b, checked: true);
    await trips.completeTrip(
      listId,
      startedAt: DateTime(2026, 7, 11, 9),
      now: DateTime(2026, 7, 11, 9, 10),
    );

    final recent = await trips.watchRecent().first;
    expect(recent, hasLength(2));
    expect(
      recent.first.completedAt.isAfter(recent.last.completedAt),
      isTrue,
    );
  });
}
