import 'package:sqflite/sqflite.dart';

/// Applies numbered schema migrations for existing installs.
///
/// Rule (docs/ARCHITECTURE.md section 11): never edit an existing step, always
/// add a new one and bump [AppDatabase.schemaVersion]. Each step must be
/// guarded by its version so users updating the app keep their data.
Future<void> runMigrations(Database db, int oldVersion, int newVersion) async {
  // No migrations yet: schema version 1 is the initial schema, created by
  // AppDatabase._onCreate. When the schema changes, add steps like:
  //
  //   if (oldVersion < 2) {
  //     await db.execute('ALTER TABLE exercises ADD COLUMN notes TEXT');
  //   }
}
