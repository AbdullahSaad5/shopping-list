import 'package:drift/drift.dart';
import 'package:tokri/core/db/enums.dart';
import 'package:uuid/uuid.dart';

// Authoritative schema (PLAN.md §5), with two deliberate deviations recorded
// in CLAUDE.md: money is integer minor units (paisa) — `priceMinor` /
// `budgetMinor` instead of REAL — and every syncable table carries the
// uuid/updatedAt/deletedAt trio so v2 Firebase sync is additive.
//
// DateTimes use drift's default integer (unix) storage on purpose: text
// storage reads back UTC and shifts days for PKT (ledgr's v3 migration).

/// Public (not private, not const): drift copies this expression verbatim
/// into database.g.dart, a separate library.
String genUuid() => const Uuid().v4();

mixin SyncColumns on Table {
  TextColumn get uuid => text().clientDefault(genUuid).unique()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class ShoppingLists extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// Index into the accent palette, not a raw color: themes restyle freely.
  IntColumn get colorSeed => integer()();
  TextColumn get icon => text()();
  IntColumn get budgetMinor => integer().nullable()();
  IntColumn get sortMode => intEnum<ListSortMode>()
      .withDefault(Constant(ListSortMode.category.index))();
  IntColumn get position => integer()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  BoolColumn get isTemplate => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
}

class Categories extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get icon => text()();
  IntColumn get color => integer()();

  /// Aisle order: drives shop-mode grouping.
  IntColumn get position => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class Items extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId => integer().references(
        ShoppingLists,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get name => text().withLength(min: 1, max: 80)();

  /// Real on purpose: 2.5 kg is a legitimate quantity. Prices stay integer.
  RealColumn get quantity => real().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant('pcs'))();
  IntColumn get priceMinor => integer().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get categoryId => integer().nullable().references(
        Categories,
        #id,
        onDelete: KeyAction.setNull,
      )();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  BoolColumn get priority => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer()();

  /// Reserved for v1.1 item photos.
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get checkedAt => dateTime().nullable()();
}

class CatalogEntries extends Table with SyncColumns {
  IntColumn get id => integer().autoIncrement()();

  /// Lowercased + trimmed dedupe key.
  TextColumn get nameNormalized => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get defaultUnit => text().withDefault(const Constant('pcs'))();
  IntColumn get categoryId => integer().nullable().references(
        Categories,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get lastPriceMinor => integer().nullable()();
  IntColumn get timesPurchased => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastPurchasedAt => dateTime().nullable()();
  BoolColumn get isSeeded => boolean().withDefault(const Constant(false))();
}

/// Written once when a shop-mode session completes. Not synced in v2 (local
/// history), so no SyncColumns.
class Trips extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get listId => integer().nullable().references(
        ShoppingLists,
        #id,
        onDelete: KeyAction.setNull,
      )();

  /// Denormalized so the trip survives list deletion.
  TextColumn get listName => text()();
  IntColumn get itemCount => integer()();
  IntColumn get totalSpentMinor => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get completedAt => dateTime()();
}
