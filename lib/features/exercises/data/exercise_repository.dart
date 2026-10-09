import 'package:fitlog/core/database/database_provider.dart';
import 'package:fitlog/features/exercises/domain/exercise.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes the `exercises` table. The only place SQL touches
/// exercises (docs/ARCHITECTURE.md section 4).
class ExerciseRepository {
  ExerciseRepository(this._database);

  final Future<Database> _database;

  /// Built-in and custom exercises, excluding archived ones.
  ///
  /// [environment] matches the exact value or `both`; [muscle] matches the
  /// primary muscle or any secondary muscle; [search] matches the name.
  Future<List<Exercise>> getAll({
    String? environment,
    String? muscle,
    String? search,
  }) async {
    final db = await _database;
    final clauses = <String>['is_archived = 0'];
    final args = <Object?>[];

    if (environment != null) {
      clauses.add('(environment = ? OR environment = ?)');
      args.addAll([environment, 'both']);
    }
    if (muscle != null) {
      clauses.add('(primary_muscle = ? OR secondary_muscles LIKE ?)');
      args.addAll([muscle, '%$muscle%']);
    }
    final query = search?.trim();
    if (query != null && query.isNotEmpty) {
      clauses.add('name LIKE ?');
      args.add('%$query%');
    }

    final rows = await db.query(
      'exercises',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'name',
    );
    return rows.map(Exercise.fromMap).toList();
  }

  Future<Exercise?> getById(int id) async {
    final db = await _database;
    final rows = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Exercise.fromMap(rows.first);
  }

  /// Inserts a user-created exercise (`is_custom = 1`) and returns it with its
  /// assigned id.
  Future<Exercise> insertCustom(Exercise exercise) async {
    final db = await _database;
    final map = exercise.toMap()
      ..remove('id')
      ..['is_custom'] = 1;
    final id = await db.insert('exercises', map);
    return (await getById(id))!;
  }

  /// Soft-deletes an exercise so existing history still resolves.
  Future<void> archive(int id) async {
    final db = await _database;
    await db.update(
      'exercises',
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider.future)),
);
