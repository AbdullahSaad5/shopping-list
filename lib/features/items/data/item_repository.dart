import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';
import 'package:tokri/core/utils/item_parser.dart';

/// Items within a list, split into open and done for the two sections.
class ListItems {
  const ListItems({required this.open, required this.done});

  final List<Item> open;
  final List<Item> done;
}

/// All reads/writes for items + the catalog learning that rides on writes.
class ItemRepository {
  ItemRepository(this._db);

  final AppDatabase _db;

  /// Open items ordered per [sortMode]; done items newest-checked first.
  Stream<ListItems> watchForList(int listId, ListSortMode sortMode) {
    final query = _db.select(_db.items)
      ..where((i) => i.listId.equals(listId) & i.deletedAt.isNull());
    return query.watch().map((rows) {
      final open = rows.where((i) => !i.checked).toList();
      final done = rows.where((i) => i.checked).toList()
        ..sort(
          (a, b) => (b.checkedAt ?? b.createdAt)
              .compareTo(a.checkedAt ?? a.createdAt),
        );
      open.sort(switch (sortMode) {
        ListSortMode.manual => (a, b) => a.position.compareTo(b.position),
        ListSortMode.alpha => (a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        // createdAt is stored at second granularity; ties are common for
        // quick successive adds, so break them by id (insertion order).
        ListSortMode.recent => (a, b) {
          final byTime = b.createdAt.compareTo(a.createdAt);
          return byTime != 0 ? byTime : b.id.compareTo(a.id);
        },
        // Category order is applied by the UI via the categories stream
        // (position = aisle order); fall back to manual within a category.
        ListSortMode.category => (a, b) => a.position.compareTo(b.position),
        ListSortMode.uncheckedFirst => (a, b) =>
            a.position.compareTo(b.position),
      });
      return ListItems(open: open, done: done);
    });
  }

  /// Adds one parsed entry. If an open item with the same normalized name
  /// exists on the list, its quantity is bumped instead (dedupe-on-add).
  /// Returns the item id. Also teaches the catalog the display name/unit.
  Future<int> add(
    int listId,
    ParsedItem parsed, {
    int? categoryId,
    int? priceMinor,
    String? note,
  }) async {
    return _db.transaction(() async {
      final normalized = normalizeItemName(parsed.name);

      final existing = await (_db.select(_db.items)
            ..where(
              (i) =>
                  i.listId.equals(listId) &
                  i.deletedAt.isNull() &
                  i.checked.equals(false) &
                  i.name.lower().equals(normalized),
            ))
          .getSingleOrNull();
      if (existing != null && existing.unit == parsed.unit) {
        await (_db.update(_db.items)..where((i) => i.id.equals(existing.id)))
            .write(
          ItemsCompanion(
            quantity: Value(existing.quantity + parsed.quantity),
            updatedAt: Value(DateTime.now()),
          ),
        );
        return existing.id;
      }

      final catalogCategory =
          categoryId ?? await _catalogCategoryFor(normalized);

      final maxPos = _db.items.position.max();
      final row = await (_db.selectOnly(_db.items)
            ..addColumns([maxPos])
            ..where(_db.items.listId.equals(listId)))
          .getSingle();

      final id = await _db.into(_db.items).insert(
            ItemsCompanion.insert(
              listId: listId,
              name: parsed.name,
              quantity: Value(parsed.quantity),
              unit: Value(parsed.unit),
              priceMinor: Value(priceMinor),
              note: Value(note),
              categoryId: Value(catalogCategory),
              position: (row.read(maxPos) ?? -1) + 1,
            ),
          );

      await _learn(
        normalized: normalized,
        displayName: parsed.name,
        unit: parsed.unit,
        categoryId: catalogCategory,
      );
      return id;
    });
  }

  Future<int?> _catalogCategoryFor(String normalized) async {
    final entry = await (_db.select(_db.catalogEntries)
          ..where(
            (c) => c.nameNormalized.equals(normalized) & c.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    return entry?.categoryId;
  }

  /// Upserts the catalog entry for an added item: display name and default
  /// unit follow the latest add; purchase counters belong to shop mode (M3).
  Future<void> _learn({
    required String normalized,
    required String displayName,
    required String unit,
    int? categoryId,
  }) async {
    final existing = await (_db.select(_db.catalogEntries)
          ..where((c) => c.nameNormalized.equals(normalized)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.catalogEntries).insert(
            CatalogEntriesCompanion.insert(
              nameNormalized: normalized,
              displayName: displayName,
              defaultUnit: Value(unit),
              categoryId: Value(categoryId),
            ),
          );
    } else {
      await (_db.update(_db.catalogEntries)
            ..where((c) => c.id.equals(existing.id)))
          .write(
        CatalogEntriesCompanion(
          displayName: Value(displayName),
          defaultUnit: Value(unit),
          categoryId: categoryId == null
              ? const Value.absent()
              : Value(categoryId),
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Prefix autocomplete over the catalog, most-purchased then most recent.
  Future<List<CatalogEntry>> suggest(String prefix, {int limit = 8}) {
    final normalized = normalizeItemName(prefix);
    if (normalized.isEmpty) return Future.value(const []);
    final query = _db.select(_db.catalogEntries)
      ..where(
        (c) =>
            c.deletedAt.isNull() &
            c.nameNormalized.like('$normalized%'),
      )
      ..orderBy([
        (c) =>
            OrderingTerm(expression: c.timesPurchased, mode: OrderingMode.desc),
        (c) => OrderingTerm(
              expression: c.lastPurchasedAt,
              mode: OrderingMode.desc,
            ),
        (c) => OrderingTerm(expression: c.nameNormalized),
      ])
      ..limit(limit);
    return query.get();
  }

  Future<void> setChecked(int id, {required bool checked}) =>
      (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
        ItemsCompanion(
          checked: Value(checked),
          checkedAt: Value(checked ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> update(
    int id, {
    String? name,
    double? quantity,
    String? unit,
    int? priceMinor,
    bool clearPrice = false,
    String? note,
    bool clearNote = false,
    int? categoryId,
    bool clearCategory = false,
    bool? priority,
  }) {
    return (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
      ItemsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        quantity: quantity == null ? const Value.absent() : Value(quantity),
        unit: unit == null ? const Value.absent() : Value(unit),
        priceMinor: clearPrice
            ? const Value(null)
            : priceMinor == null
                ? const Value.absent()
                : Value(priceMinor),
        note: clearNote
            ? const Value(null)
            : note == null
                ? const Value.absent()
                : Value(note),
        categoryId: clearCategory
            ? const Value(null)
            : categoryId == null
                ? const Value.absent()
                : Value(categoryId),
        priority: priority == null ? const Value.absent() : Value(priority),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Tombstone; [restore] undoes it (swipe-delete undo snackbar).
  Future<void> delete(int id) =>
      (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
        ItemsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> restore(int id) =>
      (_db.update(_db.items)..where((i) => i.id.equals(id))).write(
        ItemsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Tombstones every checked item on the list ("clear checked").
  Future<void> clearChecked(int listId) =>
      (_db.update(_db.items)
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

  /// Persists a manual drag order for the open section.
  Future<void> reorder(List<int> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.items)
              ..where((it) => it.id.equals(orderedIds[i])))
            .write(
          ItemsCompanion(
            position: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}

final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => ItemRepository(ref.watch(databaseProvider)),
);

final listItemsProvider =
    StreamProvider.family<ListItems, ({int listId, ListSortMode sort})>(
  (ref, args) =>
      ref.watch(itemRepositoryProvider).watchForList(args.listId, args.sort),
);
