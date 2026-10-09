import 'package:fitlog/core/database/app_database.dart';
import 'package:fitlog/core/database/seeder.dart';
import 'package:fitlog/features/plans/data/template_repository.dart';
import 'package:fitlog/features/session/data/session_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<int> _count(
  Database db,
  String table, {
  String? where,
  List<Object?>? whereArgs,
}) async {
  final sql =
      'SELECT COUNT(*) AS count FROM $table${where == null ? '' : ' WHERE $where'}';
  final rows = await db.rawQuery(sql, whereArgs);
  return rows.first['count'] as int;
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late SessionRepository sessions;
  late TemplateRepository templates;
  late int gymTemplateId;

  setUp(() async {
    final appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    db = await appDatabase.open();
    await Seeder(db).seed();

    final database = Future.value(db);
    sessions = SessionRepository(database);
    templates = TemplateRepository(database);

    final all = await templates.getAll();
    gymTemplateId = all.firstWhere((t) => t.slug == 'gym_full_body').id!;
  });

  tearDown(() => db.close());

  test('startFromTemplate creates the right rows', () async {
    final session = await sessions.startFromTemplate(gymTemplateId);

    final sessionExercises = await _count(
      db,
      'session_exercises',
      where: 'session_id = ?',
      whereArgs: [session.id],
    );
    final sessionSets = await _count(
      db,
      'session_sets',
      where:
          'session_exercise_id IN '
          '(SELECT id FROM session_exercises WHERE session_id = ?)',
      whereArgs: [session.id],
    );

    // Gym Full Body has 7 exercises, each with 3 target sets.
    expect(sessionExercises, 7);
    expect(sessionSets, 21);
    expect(session.isInProgress, isTrue);
  });

  test('completeSet updates the row correctly', () async {
    final session = await sessions.startFromTemplate(gymTemplateId);
    final detail = await sessions.getSessionDetail(session.id!);
    final setId = detail!.exercises.first.sets.first.id!;

    await sessions.completeSet(setId, weightKg: 60, reps: 10);

    final row = (await db.query(
      'session_sets',
      where: 'id = ?',
      whereArgs: [setId],
    )).single;
    expect(row['weight_kg'], 60.0);
    expect(row['reps'], 10);
    expect(row['is_completed'], 1);
    expect(row['completed_at'], isNotNull);
  });

  test('getPreviousSets returns the most recent other session', () async {
    // Session A: log one set, then finish it.
    final sessionA = await sessions.startFromTemplate(gymTemplateId);
    final detailA = await sessions.getSessionDetail(sessionA.id!);
    final firstExercise = detailA!.exercises.first;
    final exerciseId = firstExercise.sessionExercise.exerciseId;
    await sessions.completeSet(
      firstExercise.sets.first.id!,
      weightKg: 50,
      reps: 8,
    );
    await sessions.finish(sessionA.id!);

    // Session B: a new active session with the same exercise.
    final sessionB = await sessions.startFromTemplate(gymTemplateId);

    final previous = await sessions.getPreviousSets(
      exerciseId,
      excludingSessionId: sessionB.id,
    );

    expect(previous, hasLength(1));
    expect(previous.first.weightKg, 50);
    expect(previous.first.reps, 8);
  });
}
