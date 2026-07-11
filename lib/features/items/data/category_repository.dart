import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';

/// Aisle categories: reads, CRUD, and the tombstone-safe delete.
class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchAll() {
    final query = _db.select(_db.categories)
      ..where((c) => c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm(expression: c.position)]);
    return query.watch();
  }

  Future<int> create({
    required String name,
    required String icon,
    required int color,
  }) async {
    final maxPos = _db.categories.position.max();
    final row = await (_db.selectOnly(_db.categories)..addColumns([maxPos]))
        .getSingle();
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: name,
            icon: icon,
            color: color,
            position: (row.read(maxPos) ?? -1) + 1,
          ),
        );
  }

  Future<void> update(
    int id, {
    String? name,
    String? icon,
    int? color,
  }) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        icon: icon == null ? const Value.absent() : Value(icon),
        color: color == null ? const Value.absent() : Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Tombstones the category and detaches every live reference in the same
  /// transaction — items and catalog entries must never point at a
  /// tombstoned row (ledgr's category-delete lesson).
  Future<void> delete(int id) {
    return _db.transaction(() async {
      final now = DateTime.now();
      await (_db.update(_db.items)..where((i) => i.categoryId.equals(id)))
          .write(
        ItemsCompanion(categoryId: const Value(null), updatedAt: Value(now)),
      );
      await (_db.update(_db.catalogEntries)
            ..where((c) => c.categoryId.equals(id)))
          .write(
        CatalogEntriesCompanion(
          categoryId: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  /// Persists a manual aisle order.
  Future<void> reorder(List<int> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.categories)
              ..where((c) => c.id.equals(orderedIds[i])))
            .write(
          CategoriesCompanion(
            position: Value(i),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final categoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

/// id → Category for icon/name/color lookups in tiles.
final categoryMapProvider = Provider<Map<int, Category>>((ref) {
  final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
  return {for (final c in categories) c.id: c};
});
