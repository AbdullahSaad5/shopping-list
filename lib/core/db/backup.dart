/// Full local backup (PLAN §3 "Settings → Data"): one versioned JSON
/// document holding every table, tombstones included (sync contract).
/// Import is all-or-nothing: it validates first, then replaces the whole
/// database inside a transaction — a failed import leaves data untouched.
library;

import 'dart:convert';

import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/db/seed.dart';
import 'package:tokri/core/utils/share_codec.dart' show ImportException;

/// Settings → "Clear data": wipes everything and reseeds the defaults, as
/// if freshly installed. Irreversible; the UI double-confirms.
Future<void> clearAllData(AppDatabase db) => db.transaction(() async {
      await db.delete(db.trips).go();
      await db.delete(db.items).go();
      await db.delete(db.catalogEntries).go();
      await db.delete(db.shoppingLists).go();
      await db.delete(db.categories).go();
      await seedDefaults(db);
    });

const _backupVersion = 1;
const _tables = ['categories', 'lists', 'items', 'catalog', 'trips'];

/// Serializes the whole database. Row order follows FK dependencies so the
/// import can insert in file order.
Future<String> exportBackup(AppDatabase db) async {
  final payload = <String, Object?>{
    'v': _backupVersion,
    'exportedAt': DateTime.now().toIso8601String(),
    'categories': [
      for (final r in await db.select(db.categories).get()) r.toJson(),
    ],
    'lists': [
      for (final r in await db.select(db.shoppingLists).get()) r.toJson(),
    ],
    'items': [for (final r in await db.select(db.items).get()) r.toJson()],
    'catalog': [
      for (final r in await db.select(db.catalogEntries).get()) r.toJson(),
    ],
    'trips': [for (final r in await db.select(db.trips).get()) r.toJson()],
  };
  return jsonEncode(payload);
}

/// Replaces the database with [json]. Throws [ImportException] on anything
/// that is not a valid v1 backup; existing data survives a failed import.
Future<void> importBackup(AppDatabase db, String json) async {
  const failed = ImportException("This file doesn't look like a Tokri backup.");
  final Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on FormatException {
    throw failed;
  }
  if (decoded is! Map<String, Object?>) throw failed;
  if (decoded['v'] != _backupVersion) {
    throw const ImportException(
      'This backup was made by a newer Tokri — update to import it.',
    );
  }
  final sections = <String, List<Map<String, Object?>>>{};
  for (final key in _tables) {
    final raw = decoded[key];
    if (raw is! List) throw failed;
    sections[key] = [
      for (final row in raw)
        if (row is Map<String, Object?>) row else throw failed,
    ];
  }

  // Parse every row BEFORE wiping anything.
  late final List<Category> categories;
  late final List<ShoppingList> lists;
  late final List<Item> items;
  late final List<CatalogEntry> catalog;
  late final List<Trip> trips;
  try {
    categories =
        sections['categories']!.map(Category.fromJson).toList();
    lists = sections['lists']!.map(ShoppingList.fromJson).toList();
    items = sections['items']!.map(Item.fromJson).toList();
    catalog = sections['catalog']!.map(CatalogEntry.fromJson).toList();
    trips = sections['trips']!.map(Trip.fromJson).toList();
  } on Object {
    throw failed;
  }

  await db.transaction(() async {
    // Reverse-FK order for the wipe, forward for the insert.
    await db.delete(db.trips).go();
    await db.delete(db.items).go();
    await db.delete(db.catalogEntries).go();
    await db.delete(db.shoppingLists).go();
    await db.delete(db.categories).go();

    await db.batch((batch) {
      batch
        ..insertAll(db.categories, categories)
        ..insertAll(db.shoppingLists, lists)
        ..insertAll(db.items, items)
        ..insertAll(db.catalogEntries, catalog)
        ..insertAll(db.trips, trips);
    });
  });
}
