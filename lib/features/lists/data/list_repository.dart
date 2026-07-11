import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';

/// All reads/writes for shopping lists. The only class touching the
/// shopping_lists table.
class ListRepository {
  ListRepository(this._db);

  final AppDatabase _db;

  /// Active lists: not archived, not templates, not tombstoned. Pinned
  /// first, then manual position.
  Stream<List<ShoppingList>> watchActive() {
    final query = _db.select(_db.shoppingLists)
      ..where(
        (l) =>
            l.archived.equals(false) &
            l.isTemplate.equals(false) &
            l.deletedAt.isNull(),
      )
      ..orderBy([
        (l) => OrderingTerm(expression: l.pinned, mode: OrderingMode.desc),
        (l) => OrderingTerm(expression: l.position),
      ]);
    return query.watch();
  }
}

final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(ref.watch(databaseProvider)),
);

final activeListsProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(listRepositoryProvider).watchActive(),
);
