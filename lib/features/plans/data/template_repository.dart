import 'package:fitlog/core/database/database_provider.dart';
import 'package:fitlog/features/exercises/domain/exercise.dart';
import 'package:fitlog/features/plans/domain/template_exercise.dart';
import 'package:fitlog/features/plans/domain/workout_template.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// A template together with its ordered exercises (each carrying its [Exercise]).
typedef TemplateWithExercises = ({
  WorkoutTemplate template,
  List<TemplateExercise> exercises,
});

/// A plan plus how many exercises it contains (for the plans list).
typedef TemplateSummary = ({WorkoutTemplate template, int exerciseCount});

/// Reads and writes `workout_templates` and `template_exercises`.
class TemplateRepository {
  TemplateRepository(this._database);

  final Future<Database> _database;

  Future<List<WorkoutTemplate>> getAll() async {
    final db = await _database;
    final rows = await db.query(
      'workout_templates',
      orderBy: 'is_prebuilt DESC, name',
    );
    return rows.map(WorkoutTemplate.fromMap).toList();
  }

  /// All plans (built-in first) with their exercise counts, in one query.
  Future<List<TemplateSummary>> getAllWithCounts() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT t.*, COUNT(te.id) AS exercise_count
      FROM workout_templates t
      LEFT JOIN template_exercises te ON te.template_id = t.id
      GROUP BY t.id
      ORDER BY t.is_prebuilt DESC, t.name
    ''');
    return rows
        .map(
          (row) => (
            template: WorkoutTemplate.fromMap(row),
            exerciseCount: (row['exercise_count'] as int?) ?? 0,
          ),
        )
        .toList();
  }

  /// Returns the template with its exercises (joined to their [Exercise]),
  /// or null if no template has that id.
  Future<TemplateWithExercises?> getById(int id) async {
    final db = await _database;
    final templateRows = await db.query(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (templateRows.isEmpty) return null;

    final exerciseRows = await db.query(
      'template_exercises',
      where: 'template_id = ?',
      whereArgs: [id],
      orderBy: 'position',
    );
    final exercisesById = await _exercisesById(
      db,
      exerciseRows.map((row) => row['exercise_id'] as int),
    );

    return (
      template: WorkoutTemplate.fromMap(templateRows.first),
      exercises: exerciseRows
          .map(
            (row) => TemplateExercise.fromMap(
              row,
              exercise: exercisesById[row['exercise_id']],
            ),
          )
          .toList(),
    );
  }

  /// Creates a template and its exercises in one transaction.
  Future<WorkoutTemplate> create(
    WorkoutTemplate template,
    List<TemplateExercise> exercises,
  ) async {
    final db = await _database;
    final templateId = await db.transaction((txn) async {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      final map = template.toMap()
        ..remove('id')
        ..['created_at'] = now
        ..['updated_at'] = now;
      final id = await txn.insert('workout_templates', map);
      await _replaceExercises(txn, id, exercises);
      return id;
    });
    return (await getById(templateId))!.template;
  }

  /// Updates the template and replaces its exercises in one transaction.
  Future<void> update(
    WorkoutTemplate template,
    List<TemplateExercise> exercises,
  ) async {
    final templateId = template.id;
    if (templateId == null) {
      throw ArgumentError('Cannot update a template without an id.');
    }
    final db = await _database;
    await db.transaction((txn) async {
      final map = template.toMap()
        ..remove('id')
        ..remove('created_at')
        ..['updated_at'] = DateTime.now().toUtc().millisecondsSinceEpoch;
      await txn.update(
        'workout_templates',
        map,
        where: 'id = ?',
        whereArgs: [templateId],
      );
      await txn.delete(
        'template_exercises',
        where: 'template_id = ?',
        whereArgs: [templateId],
      );
      await _replaceExercises(txn, templateId, exercises);
    });
  }

  /// Deletes a template; its `template_exercises` cascade away.
  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('workout_templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _replaceExercises(
    DatabaseExecutor txn,
    int templateId,
    List<TemplateExercise> exercises,
  ) async {
    for (var i = 0; i < exercises.length; i++) {
      final exercise = exercises[i];
      await txn.insert('template_exercises', {
        'template_id': templateId,
        'exercise_id': exercise.exerciseId,
        'position': exercise.position > 0 ? exercise.position : i + 1,
        'target_sets': exercise.targetSets,
        'target_reps_min': exercise.targetRepsMin,
        'target_reps_max': exercise.targetRepsMax,
        'rest_seconds': exercise.restSeconds,
        'notes': exercise.notes,
      });
    }
  }

  Future<Map<int, Exercise>> _exercisesById(
    DatabaseExecutor db,
    Iterable<int> ids,
  ) async {
    final uniqueIds = ids.toSet().toList();
    if (uniqueIds.isEmpty) return {};
    final rows = await db.query(
      'exercises',
      where: 'id IN (${_placeholders(uniqueIds.length)})',
      whereArgs: uniqueIds,
    );
    return {for (final row in rows) row['id'] as int: Exercise.fromMap(row)};
  }
}

String _placeholders(int count) => List.filled(count, '?').join(', ');

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => TemplateRepository(ref.watch(databaseProvider.future)),
);
