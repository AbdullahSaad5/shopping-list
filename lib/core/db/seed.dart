import 'package:drift/drift.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/db/seed_catalog.dart';
import 'package:tokri/core/utils/item_parser.dart';

/// Units offered in the quantity picker. 'pcs' is the default everywhere.
const kUnits = <String>[
  'pcs',
  'kg',
  'g',
  'L',
  'ml',
  'pack',
  'dozen',
];

class _SeedCategory {
  const _SeedCategory(this.name, this.icon, this.color);
  final String name;
  final String icon;
  final int color;
}

/// Default aisle-ordered categories (PLAN.md §5; exact list refined by the
/// seed-data ticket #4 — this is the working default so a fresh install is
/// never empty). Order = typical store walk: produce first, household last.
const _categories = <_SeedCategory>[
  _SeedCategory('Fruits & Vegetables', 'carrot', 0xFF43A047),
  _SeedCategory('Bakery', 'croissant', 0xFFBF8341),
  _SeedCategory('Dairy & Eggs', 'milk', 0xFF1E88E5),
  _SeedCategory('Meat & Fish', 'beef', 0xFFE53935),
  _SeedCategory('Rice, Flour & Grains', 'wheat', 0xFFF9A825),
  _SeedCategory('Spices & Condiments', 'flame', 0xFFE64A19),
  _SeedCategory('Snacks & Biscuits', 'cookie', 0xFF8E24AA),
  _SeedCategory('Beverages', 'cup-soda', 0xFF00ACC1),
  _SeedCategory('Frozen', 'snowflake', 0xFF039BE5),
  _SeedCategory('Household & Cleaning', 'spray-can', 0xFF00897B),
  _SeedCategory('Personal Care', 'sparkles', 0xFFEC407A),
  _SeedCategory('Baby', 'baby', 0xFF7CB342),
  _SeedCategory('Pharmacy', 'pill', 0xFF5E35B1),
  _SeedCategory('Other', 'shopping-basket', 0xFF9E9E9E),
];

/// Inserts the default categories and the starter catalog (ticket #4).
/// Starter rows ship with zero purchase counters so anything the user
/// actually buys outranks them once ranking uses counters. Called once
/// from the database's onCreate.
Future<void> seedDefaults(AppDatabase db) async {
  await db.batch((batch) {
    var position = 0;
    for (final c in _categories) {
      batch.insert(
        db.categories,
        CategoriesCompanion.insert(
          name: c.name,
          icon: c.icon,
          color: c.color,
          position: position++,
          isDefault: const Value(true),
        ),
      );
    }
  });

  final categoryIds = {
    for (final c in await db.select(db.categories).get()) c.name: c.id,
  };
  await db.batch((batch) {
    for (final entry in kSeedCatalog) {
      batch.insert(
        db.catalogEntries,
        CatalogEntriesCompanion.insert(
          nameNormalized: normalizeItemName(entry.name),
          displayName: entry.name,
          defaultUnit: Value(entry.unit),
          categoryId: Value(categoryIds[entry.category]),
          isSeeded: const Value(true),
        ),
      );
    }
  });
}
