import 'package:drift/drift.dart';
import 'package:tokri/core/db/connection.dart';
import 'package:tokri/core/db/enums.dart';
import 'package:tokri/core/db/seed.dart';
import 'package:tokri/core/db/tables.dart';

export 'package:tokri/core/db/enums.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [ShoppingLists, Categories, Items, CatalogEntries, Trips],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// In-memory database for tests: same schema, same seed.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX idx_items_list ON items (list_id, checked, position)',
          );
          await customStatement(
            'CREATE INDEX idx_trips_completed ON trips (completed_at)',
          );
          await seedDefaults(this);
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
