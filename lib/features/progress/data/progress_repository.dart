import 'package:fitlog/core/database/database_provider.dart';
import 'package:fitlog/features/progress/domain/progress_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Read-only queries that power the Progress tab.
class ProgressRepository {
  ProgressRepository(this._database);

  final Future<Database> _database;

  /// Every completed, non-warm-up set for [exerciseId] in finished sessions,
  /// oldest first. The date is each set's session start (local time).
  Future<List<ExerciseSetSample>> getCompletedSetsForExercise(
    int exerciseId,
  ) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT ws.started_at AS started_at,
             ss.weight_kg, ss.reps, ss.duration_seconds
      FROM session_sets ss
      JOIN session_exercises se ON se.id = ss.session_exercise_id
      JOIN workout_sessions ws ON ws.id = se.session_id
      WHERE se.exercise_id = ?
        AND ws.ended_at IS NOT NULL
        AND ss.is_completed = 1
        AND ss.is_warmup = 0
      ORDER BY ws.started_at
    ''', [exerciseId]);
    return rows.map((row) {
      final date = DateTime.fromMillisecondsSinceEpoch(
        (row['started_at'] as num).toInt(),
        isUtc: true,
      ).toLocal();
      return ExerciseSetSample(
        date: date,
        weightKg: (row['weight_kg'] as num?)?.toDouble(),
        reps: row['reps'] as int?,
        durationSeconds: row['duration_seconds'] as int?,
      );
    }).toList();
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(databaseProvider.future)),
);
