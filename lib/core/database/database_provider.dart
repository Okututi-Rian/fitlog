import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'seeder.dart';

/// The database wrapper (path + schema). Overridden in tests to inject a
/// different [DatabaseFactory] such as the FFI one.
final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

/// Opens the database, seeds built-in data on first run, and exposes the ready
/// [Database] to repositories. Depend on this from the data layer only.
final databaseProvider = FutureProvider<Database>((ref) async {
  final db = await ref.watch(appDatabaseProvider).open();
  await Seeder(db).seed();
  return db;
});
