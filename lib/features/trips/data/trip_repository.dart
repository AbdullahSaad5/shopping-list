import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';
import 'package:tokri/core/utils/budget_math.dart';
import 'package:tokri/core/utils/item_parser.dart';

/// Shop-mode session results: writes the trip snapshot, teaches the catalog
/// what was actually bought (purchase counters = the suggestion-ranking
/// signal), and remembers prices (PLAN §3 "price memory").
class TripRepository {
  TripRepository(this._db);

  final AppDatabase _db;

  /// Ends a shop-mode session for [listId]: snapshots the checked section
  /// into a denormalized [Trip] row (survives list deletion), bumps
  /// `timesPurchased`/`lastPurchasedAt` on the checked items' catalog
  /// entries, and optionally tombstones the checked items. Returns the
  /// written trip.
  Future<Trip> completeTrip(
    int listId, {
    required DateTime startedAt,
    DateTime? now,
    bool clearChecked = false,
  }) {
    final endedAt = now ?? DateTime.now();
    return _db.transaction(() async {
      final list = await (_db.select(_db.shoppingLists)
            ..where((l) => l.id.equals(listId)))
          .getSingle();
      final checked = await (_db.select(_db.items)
            ..where(
              (i) =>
                  i.listId.equals(listId) &
                  i.deletedAt.isNull() &
                  i.checked.equals(true),
            ))
          .get();

      final est = estimateTotal([
        for (final i in checked)
          (priceMinor: i.priceMinor, quantity: i.quantity),
      ]);
      final anyPriced = checked.any((i) => i.priceMinor != null);

      final tripId = await _db.into(_db.trips).insert(
            TripsCompanion.insert(
              listId: Value(listId),
              listName: list.name,
              itemCount: checked.length,
              totalSpentMinor: Value(anyPriced ? est.estMinor : null),
              durationSeconds: Value(
                endedAt.difference(startedAt).inSeconds,
              ),
              completedAt: endedAt,
            ),
          );

      for (final item in checked) {
        await (_db.update(_db.catalogEntries)
              ..where(
                (c) =>
                    c.nameNormalized.equals(normalizeItemName(item.name)) &
                    c.deletedAt.isNull(),
              ))
            .write(
          CatalogEntriesCompanion.custom(
            timesPurchased:
                _db.catalogEntries.timesPurchased + const Constant(1),
            lastPurchasedAt: Variable(endedAt),
            updatedAt: Variable(DateTime.now()),
          ),
        );
      }

      if (clearChecked) {
        await (_db.update(_db.items)
              ..where(
                (i) =>
                    i.listId.equals(listId) &
                    i.checked.equals(true) &
                    i.deletedAt.isNull(),
              ))
            .write(
          ItemsCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      return (_db.select(_db.trips)..where((t) => t.id.equals(tripId)))
          .getSingle();
    });
  }

  /// Price pad write: the item gets the price now, the catalog remembers it
  /// for next time (price memory).
  Future<void> setPrice(int itemId, {required int priceMinor}) =>
      _db.transaction(() async {
        final item = await (_db.select(_db.items)
              ..where((i) => i.id.equals(itemId)))
            .getSingle();
        await (_db.update(_db.items)..where((i) => i.id.equals(itemId)))
            .write(
          ItemsCompanion(
            priceMinor: Value(priceMinor),
            updatedAt: Value(DateTime.now()),
          ),
        );
        await (_db.update(_db.catalogEntries)
              ..where(
                (c) =>
                    c.nameNormalized.equals(normalizeItemName(item.name)) &
                    c.deletedAt.isNull(),
              ))
            .write(
          CatalogEntriesCompanion(
            lastPriceMinor: Value(priceMinor),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

  /// Trip history, newest first.
  Stream<List<Trip>> watchRecent({int limit = 50}) => (_db.select(_db.trips)
        ..orderBy([
          (t) =>
              OrderingTerm(expression: t.completedAt, mode: OrderingMode.desc),
        ])
        ..limit(limit))
      .watch();
}

final tripRepositoryProvider = Provider<TripRepository>(
  (ref) => TripRepository(ref.watch(databaseProvider)),
);
