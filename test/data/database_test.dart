import 'package:fitlog/core/database/app_database.dart';
import 'package:fitlog/core/database/seeder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<int> _countRows(Database db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS count FROM $table');
  return rows.first['count'] as int;
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('onCreate builds the schema and seeding is idempotent', () async {
    final appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    final db = await appDatabase.open();
    addTearDown(db.close);

    final seeder = Seeder(db);
    await seeder.seed();

    final exerciseCount = await _countRows(db, 'exercises');
    expect(exerciseCount, greaterThan(0));
    expect(await _countRows(db, 'workout_templates'), 2);
    expect(await _countRows(db, 'template_exercises'), greaterThan(0));

    // Running the seeder a second time must not create duplicates.
    await seeder.seed();
    expect(await _countRows(db, 'exercises'), exerciseCount);
    expect(await _countRows(db, 'workout_templates'), 2);
  });
}
