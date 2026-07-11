import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';
import 'package:tokri/core/utils/fuzzy_match.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/core/utils/urdu_aliases.dart';

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
        // Every add teaches the catalog — also revives a suggestion the
        // user "forgot" and then typed again on purpose.
        await _learn(
          normalized: normalized,
          displayName: parsed.name,
          unit: parsed.unit,
          categoryId: existing.categoryId,
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
    if (entry?.categoryId != null) return entry!.categoryId;

    // Roman-Urdu fallback: "anday" categorizes like "eggs". First canonical
    // with a category wins (gosht → beef's aisle).
    for (final canonical in canonicalsFor(normalized)) {
      final aliased = await (_db.select(_db.catalogEntries)
            ..where(
              (c) =>
                  c.nameNormalized.equals(canonical) & c.deletedAt.isNull(),
            ))
          .getSingleOrNull();
      if (aliased?.categoryId != null) return aliased!.categoryId;
    }
    return null;
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

  /// Autocomplete over the catalog (M2 ranking): prefix matches first, then
  /// substring matches; within each tier most-purchased then most recent.
  /// Roman-Urdu words ("doodh", "sawaiyan") resolve through the alias table
  /// so their canonical entries surface too.
  Future<List<CatalogEntry>> suggest(String prefix, {int limit = 8}) async {
    final raw = normalizeItemName(prefix);
    if (raw.isEmpty) return const [];
    final normalized = _escapeLike(raw);
    final query = _db.select(_db.catalogEntries)
      ..where(
        (c) =>
            c.deletedAt.isNull() &
            c.nameNormalized.like('%$normalized%', escapeChar: r'\'),
      )
      ..orderBy([
        (c) => OrderingTerm(
              expression:
                  c.nameNormalized.like('$normalized%', escapeChar: r'\'),
              mode: OrderingMode.desc,
            ),
        (c) =>
            OrderingTerm(expression: c.timesPurchased, mode: OrderingMode.desc),
        (c) => OrderingTerm(
              expression: c.lastPurchasedAt,
              mode: OrderingMode.desc,
            ),
        (c) => OrderingTerm(expression: c.nameNormalized),
      ])
      ..limit(limit);
    final direct = await query.get();

    final canonicals = {
      ...canonicalsFor(raw),
      ...aliasCanonicalsForPrefix(raw),
    };
    final aliasRows = canonicals.isEmpty
        ? const <CatalogEntry>[]
        : await (_db.select(_db.catalogEntries)
              ..where(
                (c) =>
                    c.deletedAt.isNull() & c.nameNormalized.isIn(canonicals),
              ))
            .get();
    // Alias hits lead (that's what the user meant), then direct matches.
    final seen = aliasRows.map((r) => r.id).toSet();
    final merged = [
      ...aliasRows,
      ...direct.where((r) => !seen.contains(r.id)),
    ];
    if (merged.length >= limit) return merged.take(limit).toList();

    // Fuzzy fill (bad typing welcome): leftover slots go to typo-distance
    // matches against catalog names AND Roman-Urdu alias keys, so both
    // "tomatos" and "sawaian" land. Never displaces exact/alias hits.
    final fuzzy = await _fuzzyRows(raw, exclude: merged.map((r) => r.id));
    return [...merged, ...fuzzy].take(limit).toList();
  }

  Future<List<CatalogEntry>> _fuzzyRows(
    String query, {
    required Iterable<int> exclude,
  }) async {
    if (query.length < 4) return const [];
    final all = await (_db.select(_db.catalogEntries)
          ..where((c) => c.deletedAt.isNull()))
        .get();
    final byNormalized = {for (final r in all) r.nameNormalized: r};
    final excluded = exclude.toSet();

    // candidate normalized name → best distance for ranking.
    final scores = <String, int>{};
    void consider(String candidate, String target) {
      if (!fuzzyMatches(query, candidate)) return;
      final distance = fuzzyDistance(query, candidate);
      scores.update(
        target,
        (best) => distance < best ? distance : best,
        ifAbsent: () => distance,
      );
    }

    for (final row in all) {
      consider(row.nameNormalized, row.nameNormalized);
    }
    for (final entry in kUrduAliases.entries) {
      for (final canonical in entry.value) {
        consider(entry.key, canonical);
      }
    }

    final ranked = scores.entries
        .map((e) => (row: byNormalized[e.key], distance: e.value))
        .where((e) => e.row != null && !excluded.contains(e.row!.id))
        .toList()
      ..sort((a, b) {
        final byDistance = a.distance.compareTo(b.distance);
        if (byDistance != 0) return byDistance;
        return b.row!.timesPurchased.compareTo(a.row!.timesPurchased);
      });
    return [for (final e in ranked) e.row!];
  }

  /// Idle chips for an empty, focused quick-add bar (M2): the most frequent
  /// catalog entries the user has real history with (purchased, or learned
  /// from their own adds — untouched seed rows stay out), excluding names
  /// already on this list.
  Future<List<CatalogEntry>> topSuggestions(
    int listId, {
    int limit = 10,
  }) async {
    final onList = await (_db.selectOnly(_db.items)
          ..addColumns([_db.items.name])
          ..where(
            _db.items.listId.equals(listId) & _db.items.deletedAt.isNull(),
          ))
        .map((r) => normalizeItemName(r.read(_db.items.name)!))
        .get();
    final taken = onList.toSet();

    final query = _db.select(_db.catalogEntries)
      ..where(
        (c) =>
            c.deletedAt.isNull() &
            (c.timesPurchased.isBiggerThanValue(0) |
                c.isSeeded.equals(false)),
      )
      ..orderBy([
        (c) =>
            OrderingTerm(expression: c.timesPurchased, mode: OrderingMode.desc),
        (c) => OrderingTerm(
              expression: c.lastPurchasedAt,
              mode: OrderingMode.desc,
            ),
        (c) => OrderingTerm(expression: c.updatedAt, mode: OrderingMode.desc),
        (c) => OrderingTerm(expression: c.nameNormalized),
      ])
      ..limit(limit + taken.length);
    final rows = await query.get();
    return rows
        .where((c) => !taken.contains(c.nameNormalized))
        .take(limit)
        .toList();
  }

  /// SQLite LIKE wildcards in user input must match literally.
  String _escapeLike(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

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
  /// Returns the affected ids so the action can be undone.
  Future<List<int>> clearChecked(int listId) => _db.transaction(() async {
        final ids = await (_db.selectOnly(_db.items)
              ..addColumns([_db.items.id])
              ..where(
                _db.items.listId.equals(listId) &
                    _db.items.checked.equals(true) &
                    _db.items.deletedAt.isNull(),
              ))
            .map((r) => r.read(_db.items.id)!)
            .get();
        if (ids.isEmpty) return const <int>[];
        await (_db.update(_db.items)..where((i) => i.id.isIn(ids))).write(
          ItemsCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );
        return ids;
      });

  /// Undo for bulk tombstones ([clearChecked]).
  Future<void> restoreMany(List<int> ids) => ids.isEmpty
      ? Future.value()
      : (_db.update(_db.items)..where((i) => i.id.isIn(ids))).write(
          ItemsCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(DateTime.now()),
          ),
        );

  /// Moves an item to another list, appended at the end (PLAN §6.3
  /// "move to list").
  Future<void> moveToList(int itemId, int targetListId) =>
      _db.transaction(() async {
        final maxPos = _db.items.position.max();
        final row = await (_db.selectOnly(_db.items)
              ..addColumns([maxPos])
              ..where(_db.items.listId.equals(targetListId)))
            .getSingle();
        await (_db.update(_db.items)..where((i) => i.id.equals(itemId)))
            .write(
          ItemsCompanion(
            listId: Value(targetListId),
            position: Value((row.read(maxPos) ?? -1) + 1),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

  /// Bulk tombstone for multi-select; undo with [restoreMany].
  Future<void> deleteMany(List<int> ids) => ids.isEmpty
      ? Future.value()
      : (_db.update(_db.items)..where((i) => i.id.isIn(ids))).write(
          ItemsCompanion(
            deletedAt: Value(DateTime.now()),
            updatedAt: Value(DateTime.now()),
          ),
        );

  /// Bulk move for multi-select: appended at the target's end, keeping
  /// the dragged order.
  Future<void> moveMany(List<int> ids, int targetListId) =>
      _db.transaction(() async {
        for (final id in ids) {
          await moveToList(id, targetListId);
        }
      });

  /// Bulk recategorize for multi-select.
  Future<void> setCategoryMany(List<int> ids, int? categoryId) => ids.isEmpty
      ? Future.value()
      : (_db.update(_db.items)..where((i) => i.id.isIn(ids))).write(
          ItemsCompanion(
            categoryId: Value(categoryId),
            updatedAt: Value(DateTime.now()),
          ),
        );

  /// Removes a learned entry from autocomplete (tombstone). Adding the
  /// same name again revives it via _learn.
  Future<void> forgetSuggestion(int catalogEntryId) =>
      (_db.update(_db.catalogEntries)
            ..where((c) => c.id.equals(catalogEntryId)))
          .write(
        CatalogEntriesCompanion(
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
