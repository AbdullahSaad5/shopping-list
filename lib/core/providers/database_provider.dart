import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/core/db/database.dart';

/// The single app database. Tests override with an in-memory instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
