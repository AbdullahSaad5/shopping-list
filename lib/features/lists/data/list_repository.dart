import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';

/// A list joined with its live item stats for the home cards.
class ListWithStats {
  const ListWithStats({
    required this.list,
    required this.totalItems,
    required this.checkedItems,
    required this.estimatedTotalMinor,
  });

  final ShoppingList list;
  final int totalItems;
  final int checkedItems;

  /// Σ price×quantity of priced items; null when nothing is priced.
  final int? estimatedTotalMinor;

  double get progress => totalItems == 0 ? 0 : checkedItems / totalItems;
}

/// All reads/writes for shopping lists. The only class touching the
/// shopping_lists table. Every write touches updatedAt (sync contract).
class ListRepository {
  ListRepository(this._db);

  final AppDatabase _db;

  Expression<bool> _active($ShoppingListsTable l) =>
      l.archived.equals(false) &
      l.isTemplate.equals(false) &
      l.deletedAt.isNull();

  /// Active lists: pinned first, then manual position.
  Stream<List<ShoppingList>> watchActive() {
    final query = _db.select(_db.shoppingLists)
      ..where(_active)
      ..orderBy([
        (l) => OrderingTerm(expression: l.pinned, mode: OrderingMode.desc),
        (l) => OrderingTerm(expression: l.position),
      ]);
    return query.watch();
  }

  Stream<List<ShoppingList>> watchArchived() {
    final query = _db.select(_db.shoppingLists)
      ..where(
        (l) =>
            l.archived.equals(true) &
            l.isTemplate.equals(false) &
            l.deletedAt.isNull(),
      )
      ..orderBy([
        (l) => OrderingTerm(expression: l.updatedAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  Stream<ShoppingList?> watchById(int id) {
    return (_db.select(_db.shoppingLists)..where((l) => l.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Active lists with item counts + estimated totals, pinned first. One
  /// joined query with explicit readsFrom, recomputed when either table
  /// changes (ledgr stream rules).
  Stream<List<ListWithStats>> watchActiveWithStats() {
    final query = _db.customSelect(
      '''
      SELECT l.id,
             COUNT(i.id) AS total,
             COALESCE(SUM(i.checked), 0) AS checked,
             SUM(CASE WHEN i.price_minor IS NOT NULL
                 THEN CAST(i.price_minor * i.quantity AS INTEGER) END) AS est
      FROM shopping_lists l
      LEFT JOIN items i
        ON i.list_id = l.id AND i.deleted_at IS NULL
      WHERE l.archived = 0 AND l.is_template = 0 AND l.deleted_at IS NULL
      GROUP BY l.id
      ORDER BY l.pinned DESC, l.position
      ''',
      readsFrom: {_db.shoppingLists, _db.items},
    ).watch();

    return query.asyncMap((rows) async {
      final stats = {
        for (final r in rows)
          r.read<int>('id'): (
            total: r.read<int>('total'),
            checked: r.read<int>('checked'),
            est: r.readNullable<int>('est'),
          ),
      };
      final lists = await (_db.select(_db.shoppingLists)
            ..where(_active)
            ..orderBy([
              (l) =>
                  OrderingTerm(expression: l.pinned, mode: OrderingMode.desc),
              (l) => OrderingTerm(expression: l.position),
            ]))
          .get();
      return [
        for (final l in lists)
          ListWithStats(
            list: l,
            totalItems: stats[l.id]?.total ?? 0,
            checkedItems: stats[l.id]?.checked ?? 0,
            estimatedTotalMinor: stats[l.id]?.est,
          ),
      ];
    });
  }

  Future<int> create({
    required String name,
    required int colorSeed,
    required String icon,
    int? budgetMinor,
  }) async {
    final maxPos = _db.shoppingLists.position.max();
    final row = await (_db.selectOnly(_db.shoppingLists)
          ..addColumns([maxPos]))
        .getSingle();
    return _db.into(_db.shoppingLists).insert(
          ShoppingListsCompanion.insert(
            name: name,
            colorSeed: colorSeed,
            icon: icon,
            budgetMinor: Value(budgetMinor),
            position: (row.read(maxPos) ?? -1) + 1,
          ),
        );
  }

  Future<void> update(
    int id, {
    String? name,
    int? colorSeed,
    String? icon,
    int? budgetMinor,
    bool clearBudget = false,
  }) {
    return (_db.update(_db.shoppingLists)..where((l) => l.id.equals(id)))
        .write(
      ShoppingListsCompanion(
        name: name == null ? const Value.absent() : Value(name),
        colorSeed: colorSeed == null ? const Value.absent() : Value(colorSeed),
        icon: icon == null ? const Value.absent() : Value(icon),
        budgetMinor: clearBudget
            ? const Value(null)
            : budgetMinor == null
                ? const Value.absent()
                : Value(budgetMinor),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setSortMode(int id, ListSortMode mode) =>
      (_db.update(_db.shoppingLists)..where((l) => l.id.equals(id))).write(
        ShoppingListsCompanion(
          sortMode: Value(mode),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setPinned(int id, {required bool pinned}) =>
      (_db.update(_db.shoppingLists)..where((l) => l.id.equals(id))).write(
        ShoppingListsCompanion(
          pinned: Value(pinned),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setArchived(int id, {required bool archived}) =>
      (_db.update(_db.shoppingLists)..where((l) => l.id.equals(id))).write(
        ShoppingListsCompanion(
          archived: Value(archived),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Persists a manual drag order: positions are rewritten compact.
  Future<void> reorder(List<int> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.shoppingLists)
              ..where((l) => l.id.equals(orderedIds[i])))
            .write(
          ShoppingListsCompanion(
            position: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  /// Undoes [delete] (snackbar undo).
  Future<void> restore(int id) =>
      (_db.update(_db.shoppingLists)..where((l) => l.id.equals(id))).write(
        ShoppingListsCompanion(
          deletedAt: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );

  /// Tombstone, never hard delete (sync contract). Items stay attached to
  /// the tombstoned list and disappear with it from every query.
  Future<void> delete(int id) =>
      (_db.update(_db.shoppingLists)..where((l) => l.id.equals(id))).write(
        ShoppingListsCompanion(
          deletedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
}

final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(ref.watch(databaseProvider)),
);

final activeListsProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(listRepositoryProvider).watchActive(),
);

final activeListsWithStatsProvider = StreamProvider<List<ListWithStats>>(
  (ref) => ref.watch(listRepositoryProvider).watchActiveWithStats(),
);

final listByIdProvider = StreamProvider.family<ShoppingList?, int>(
  (ref, id) => ref.watch(listRepositoryProvider).watchById(id),
);
