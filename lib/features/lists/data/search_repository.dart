import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';

/// One item hit with the list it lives on (result rows show a list badge).
typedef ItemHit = ({Item item, ShoppingList list});

/// Global search results (PLAN §6.6).
typedef SearchResults = ({List<ItemHit> items, List<ShoppingList> lists});

/// Global search: item names across active lists + list names. Templates
/// and tombstones never match.
class SearchRepository {
  SearchRepository(this._db);

  final AppDatabase _db;

  Future<SearchResults> search(String query, {int limit = 30}) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return (items: const <ItemHit>[], lists: const <ShoppingList>[]);
    }
    final escaped = needle
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final pattern = '%$escaped%';

    final itemRows = await (_db.select(_db.items).join([
      innerJoin(
        _db.shoppingLists,
        _db.shoppingLists.id.equalsExp(_db.items.listId),
      ),
    ])
          ..where(
            _db.items.deletedAt.isNull() &
                _db.items.name.lower().like(pattern, escapeChar: r'\') &
                _db.shoppingLists.deletedAt.isNull() &
                _db.shoppingLists.isTemplate.equals(false),
          )
          ..limit(limit))
        .get();

    final listRows = await (_db.select(_db.shoppingLists)
          ..where(
            (l) =>
                l.deletedAt.isNull() &
                l.isTemplate.equals(false) &
                l.name.lower().like(pattern, escapeChar: r'\'),
          )
          ..limit(limit))
        .get();

    return (
      items: [
        for (final row in itemRows)
          (
            item: row.readTable(_db.items),
            list: row.readTable(_db.shoppingLists),
          ),
      ],
      lists: listRows,
    );
  }
}

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(databaseProvider)),
);
