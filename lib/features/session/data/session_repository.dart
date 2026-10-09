import 'package:fitlog/core/database/database_provider.dart';
import 'package:fitlog/features/exercises/domain/exercise.dart';
import 'package:fitlog/features/plans/domain/template_exercise.dart';
import 'package:fitlog/features/session/domain/session_exercise.dart';
import 'package:fitlog/features/session/domain/session_set.dart';
import 'package:fitlog/features/session/domain/workout_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// A session exercise together with its ordered sets.
typedef SessionExerciseWithSets = ({
  SessionExercise sessionExercise,
  List<SessionSet> sets,
});

/// A full session: the session plus every exercise and its sets.
typedef SessionDetail = ({
  WorkoutSession session,
  List<SessionExerciseWithSets> exercises,
});

/// A completed session plus the stats shown in the history list.
typedef SessionSummary = ({
  WorkoutSession session,
  int setCount,
  double volume,
});

/// Reads and writes `workout_sessions`, `session_exercises` and `session_sets`.
class SessionRepository {
  SessionRepository(this._database);

  final Future<Database> _database;

  /// Starts a workout from a template: snapshots the plan into a new session
  /// and pre-creates one empty set row per target set. All in one transaction
  /// (docs/ARCHITECTURE.md section 9.1).
  Future<WorkoutSession> startFromTemplate(int templateId) async {
    final db = await _database;
    final sessionId = await db.transaction((txn) async {
      final templateRows = await txn.query(
        'workout_templates',
        where: 'id = ?',
        whereArgs: [templateId],
        limit: 1,
      );
      if (templateRows.isEmpty) {
        throw StateError('Template $templateId not found.');
      }
      final templateName = templateRows.first['name'] as String;
      final environment = templateRows.first['environment'] as String?;

      final id = await txn.insert('workout_sessions', {
        'template_id': templateId,
        'name': templateName,
        'environment': environment,
        'started_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'ended_at': null,
      });

      final templateExercises = await txn.query(
        'template_exercises',
        where: 'template_id = ?',
        whereArgs: [templateId],
        orderBy: 'position',
      );
      for (final row in templateExercises) {
        final templateExercise = TemplateExercise.fromMap(row);
        final sessionExerciseId = await txn.insert('session_exercises', {
          'session_id': id,
          'exercise_id': templateExercise.exerciseId,
          'position': templateExercise.position,
          'rest_seconds': templateExercise.restSeconds,
          'notes': templateExercise.notes,
        });
        final targetSets = templateExercise.targetSets ?? 3;
        for (var setNumber = 1; setNumber <= targetSets; setNumber++) {
          await txn.insert('session_sets', {
            'session_exercise_id': sessionExerciseId,
            'set_number': setNumber,
            'is_warmup': 0,
            'is_completed': 0,
          });
        }
      }
      return id;
    });
    return (await _getSessionById(db, sessionId))!;
  }

  /// Starts an empty, template-less workout.
  Future<WorkoutSession> startEmpty({
    String name = 'Empty Workout',
    String? environment,
  }) async {
    final db = await _database;
    final id = await db.insert('workout_sessions', {
      'template_id': null,
      'name': name,
      'environment': environment,
      'started_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      'ended_at': null,
    });
    return (await _getSessionById(db, id))!;
  }

  /// The most recent workout that is still in progress, if any (section 9.7).
  Future<WorkoutSession?> getActiveSession() async {
    final db = await _database;
    final rows = await db.query(
      'workout_sessions',
      where: 'ended_at IS NULL',
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : WorkoutSession.fromMap(rows.first);
  }

  /// Marks a set as done and stores what the user logged (section 9.2).
  Future<void> completeSet(
    int setId, {
    double? weightKg,
    int? reps,
    int? durationSeconds,
    bool isWarmup = false,
  }) async {
    final db = await _database;
    await db.update(
      'session_sets',
      {
        'weight_kg': weightKg,
        'reps': reps,
        'duration_seconds': durationSeconds,
        'is_warmup': isWarmup ? 1 : 0,
        'is_completed': 1,
        'completed_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  /// Edits the values of an already-completed set (history corrections).
  /// Does not change completion state or `completed_at`.
  Future<void> updateSet(
    int setId, {
    double? weightKg,
    int? reps,
    int? durationSeconds,
  }) async {
    final db = await _database;
    await db.update(
      'session_sets',
      {
        'weight_kg': weightKg,
        'reps': reps,
        'duration_seconds': durationSeconds,
      },
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  /// Adds one more empty set row to an exercise.
  Future<SessionSet> addSetRow(int sessionExerciseId) async {    final db = await _database;
    final maxRows = await db.rawQuery(
      'SELECT MAX(set_number) AS max_set FROM session_sets '
      'WHERE session_exercise_id = ?',
      [sessionExerciseId],
    );
    final next = ((maxRows.first['max_set'] as int?) ?? 0) + 1;
    final id = await db.insert('session_sets', {
      'session_exercise_id': sessionExerciseId,
      'set_number': next,
      'is_warmup': 0,
      'is_completed': 0,
    });
    return SessionSet(
      id: id,
      sessionExerciseId: sessionExerciseId,
      setNumber: next,
    );
  }

  /// Adds an exercise to an in-progress session with one empty set row.
  Future<void> addExercise(
    int sessionId,
    int exerciseId, {
    int? restSeconds,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      final positionRows = await txn.rawQuery(
        'SELECT MAX(position) AS max_position FROM session_exercises '
        'WHERE session_id = ?',
        [sessionId],
      );
      final position = ((positionRows.first['max_position'] as int?) ?? 0) + 1;
      final sessionExerciseId = await txn.insert('session_exercises', {
        'session_id': sessionId,
        'exercise_id': exerciseId,
        'position': position,
        'rest_seconds': restSeconds,
      });
      await txn.insert('session_sets', {
        'session_exercise_id': sessionExerciseId,
        'set_number': 1,
        'is_warmup': 0,
        'is_completed': 0,
      });
    });
  }

  /// Ends a workout: drops never-completed sets and empty exercises, then
  /// stamps `ended_at` (section 9.5).
  Future<void> finish(int sessionId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete(
        'session_sets',
        where:
            'is_completed = 0 AND session_exercise_id IN '
            '(SELECT id FROM session_exercises WHERE session_id = ?)',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'session_exercises',
        where:
            'session_id = ? AND id NOT IN '
            '(SELECT session_exercise_id FROM session_sets)',
        whereArgs: [sessionId],
      );
      await txn.update(
        'workout_sessions',
        {'ended_at': DateTime.now().toUtc().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  /// Deletes a session entirely (its exercises and sets cascade away).
  Future<void> discard(int sessionId) async {
    final db = await _database;
    await db.delete(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Completed workouts, newest first.
  Future<List<WorkoutSession>> getHistory() async {
    final db = await _database;
    final rows = await db.query(
      'workout_sessions',
      where: 'ended_at IS NOT NULL',
      orderBy: 'started_at DESC',
    );
    return rows.map(WorkoutSession.fromMap).toList();
  }

  /// Completed workouts with their completed-set count and volume, newest
  /// first (used by the History list).
  Future<List<SessionSummary>> getHistorySummaries() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT ws.*,
        COALESCE(SUM(CASE WHEN ss.is_completed = 1 THEN 1 ELSE 0 END), 0)
          AS set_count,
        COALESCE(SUM(
          CASE WHEN ss.is_completed = 1 AND ss.is_warmup = 0
            THEN COALESCE(ss.weight_kg, 0) * COALESCE(ss.reps, 0)
            ELSE 0 END), 0) AS volume
      FROM workout_sessions ws
      LEFT JOIN session_exercises se ON se.session_id = ws.id
      LEFT JOIN session_sets ss ON ss.session_exercise_id = se.id
      WHERE ws.ended_at IS NOT NULL
      GROUP BY ws.id
      ORDER BY ws.started_at DESC
    ''');
    return rows
        .map(
          (row) => (
            session: WorkoutSession.fromMap(row),
            setCount: (row['set_count'] as int?) ?? 0,
            volume: (row['volume'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
  }

  /// How many workouts were finished since [weekStart], and in total.
  Future<({int thisWeek, int total})> getWorkoutStats(
    DateTime weekStart,
  ) async {
    final db = await _database;
    final total =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM workout_sessions WHERE ended_at IS NOT NULL',
          ),
        ) ??
        0;
    final thisWeek =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM workout_sessions '
            'WHERE ended_at IS NOT NULL AND started_at >= ?',
            [weekStart.toUtc().millisecondsSinceEpoch],
          ),
        ) ??
        0;
    return (thisWeek: thisWeek, total: total);
  }

  /// The session with all of its exercises and sets.
  Future<SessionDetail?> getSessionDetail(int sessionId) async {
    final db = await _database;
    final session = await _getSessionById(db, sessionId);
    if (session == null) return null;

    final exerciseRows = await db.query(
      'session_exercises',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'position',
    );
    final exercisesById = await _exercisesById(
      db,
      exerciseRows.map((row) => row['exercise_id'] as int),
    );
    final sessionExercises = exerciseRows
        .map(
          (row) => SessionExercise.fromMap(
            row,
            exercise: exercisesById[row['exercise_id']],
          ),
        )
        .toList();
    final setsByExercise = await _setsByExercise(
      db,
      sessionExercises.map((e) => e.id!),
    );

    return (
      session: session,
      exercises: sessionExercises
          .map(
            (exercise) => (
              sessionExercise: exercise,
              sets: setsByExercise[exercise.id] ?? <SessionSet>[],
            ),
          )
          .toList(),
    );
  }

  /// The non-warm-up, completed sets of the most recent *other* finished
  /// session that contains [exerciseId] (section 9.3).
  Future<List<SessionSet>> getPreviousSets(
    int exerciseId, {
    int? excludingSessionId,
  }) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT ss.*
      FROM session_sets ss
      JOIN session_exercises se ON se.id = ss.session_exercise_id
      WHERE se.exercise_id = ?
        AND ss.is_completed = 1
        AND ss.is_warmup = 0
        AND se.session_id = (
          SELECT se2.session_id
          FROM session_exercises se2
          JOIN workout_sessions ws2 ON ws2.id = se2.session_id
          WHERE se2.exercise_id = ?
            AND ws2.ended_at IS NOT NULL
            AND (? IS NULL OR se2.session_id != ?)
          ORDER BY ws2.started_at DESC
          LIMIT 1
        )
      ORDER BY ss.set_number
      ''',
      [exerciseId, exerciseId, excludingSessionId, excludingSessionId],
    );
    return rows.map(SessionSet.fromMap).toList();
  }

  Future<WorkoutSession?> _getSessionById(
    DatabaseExecutor db,
    int id,
  ) async {
    final rows = await db.query(
      'workout_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : WorkoutSession.fromMap(rows.first);
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

  Future<Map<int, List<SessionSet>>> _setsByExercise(
    DatabaseExecutor db,
    Iterable<int> sessionExerciseIds,
  ) async {
    final uniqueIds = sessionExerciseIds.toSet().toList();
    if (uniqueIds.isEmpty) return {};
    final rows = await db.query(
      'session_sets',
      where: 'session_exercise_id IN (${_placeholders(uniqueIds.length)})',
      whereArgs: uniqueIds,
      orderBy: 'set_number',
    );
    final result = <int, List<SessionSet>>{};
    for (final row in rows) {
      final set = SessionSet.fromMap(row);
      result.putIfAbsent(set.sessionExerciseId, () => []).add(set);
    }
    return result;
  }
}

String _placeholders(int count) => List.filled(count, '?').join(', ');

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider.future)),
);
