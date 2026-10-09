import 'package:sqflite/sqflite.dart';

/// Loads the built-in exercise library and starter plans into the database.
///
/// Seeding is **idempotent**: every built-in row is matched by its `slug`, so
/// running the seeder repeatedly never creates duplicates and never overwrites
/// user changes. The seed data is kept inline (rather than a JSON asset) for
/// this phase; it can move to `assets/data/` later without changing the logic.
class Seeder {
  Seeder(this._db);

  final Database _db;

  /// Bump when new built-in items are added so upgraded installs pick them up.
  static const int seedVersion = 1;

  static const String _seedVersionKey = 'seed_version';

  /// Inserts any missing built-in data in a single transaction.
  Future<void> seed() async {
    await _db.transaction((txn) async {
      for (final exercise in _exerciseSeeds) {
        await _insertExerciseIfMissing(txn, exercise);
      }
      for (final template in _templateSeeds) {
        await _insertTemplateIfMissing(txn, template);
      }
      await txn.insert(
        'user_settings',
        {'key': _seedVersionKey, 'value': seedVersion.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _insertExerciseIfMissing(
    DatabaseExecutor txn,
    Map<String, Object?> exercise,
  ) async {
    final existing = await txn.query(
      'exercises',
      columns: ['id'],
      where: 'slug = ?',
      whereArgs: [exercise['slug']],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await txn.insert('exercises', exercise);
  }

  Future<void> _insertTemplateIfMissing(
    DatabaseExecutor txn,
    Map<String, Object?> template,
  ) async {
    final slug = template['slug'] as String;
    final existing = await txn.query(
      'workout_templates',
      columns: ['id'],
      where: 'slug = ?',
      whereArgs: [slug],
      limit: 1,
    );

    final int templateId;
    if (existing.isNotEmpty) {
      templateId = existing.first['id'] as int;
    } else {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      templateId = await txn.insert('workout_templates', {
        'slug': slug,
        'name': template['name'],
        'description': template['description'],
        'environment': template['environment'],
        'is_prebuilt': template['is_prebuilt'],
        'created_at': now,
        'updated_at': now,
      });
    }

    // template_exercises have no slug, so treat "already has rows" as seeded.
    final existingCount = Sqflite.firstIntValue(
      await txn.rawQuery(
        'SELECT COUNT(*) FROM template_exercises WHERE template_id = ?',
        [templateId],
      ),
    );
    if ((existingCount ?? 0) > 0) return;

    final exercises = template['exercises'] as List<Map<String, Object?>>;
    for (final entry in exercises) {
      final exerciseId = await _exerciseIdBySlug(txn, entry['slug'] as String);
      if (exerciseId == null) continue;
      await txn.insert('template_exercises', {
        'template_id': templateId,
        'exercise_id': exerciseId,
        'position': entry['position'],
        'target_sets': entry['target_sets'],
        'target_reps_min': entry['target_reps_min'],
        'target_reps_max': entry['target_reps_max'],
        'rest_seconds': entry['rest_seconds'],
        'notes': entry['notes'],
      });
    }
  }

  Future<int?> _exerciseIdBySlug(DatabaseExecutor txn, String slug) async {
    final rows = await txn.query(
      'exercises',
      columns: ['id'],
      where: 'slug = ?',
      whereArgs: [slug],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }
}

/// Built-in exercises: a mix of gym and home movements covering every
/// `primary_muscle` value in the data model.
const List<Map<String, Object?>> _exerciseSeeds = [
  {
    'slug': 'barbell_bench_press',
    'name': 'Barbell Bench Press',
    'primary_muscle': 'chest',
    'secondary_muscles': 'triceps,shoulders',
    'equipment': 'barbell',
    'environment': 'gym',
    'tracking_type': 'weight_reps',
    'instructions':
        'Lie on a flat bench, lower the bar to mid-chest, then press it back up.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'push_up',
    'name': 'Push-Up',
    'primary_muscle': 'chest',
    'secondary_muscles': 'triceps,shoulders',
    'equipment': 'bodyweight',
    'environment': 'both',
    'tracking_type': 'reps_only',
    'instructions':
        'Keep your body straight, lower your chest to the floor, then push back up.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'bent_over_barbell_row',
    'name': 'Bent-Over Barbell Row',
    'primary_muscle': 'back',
    'secondary_muscles': 'biceps',
    'equipment': 'barbell',
    'environment': 'gym',
    'tracking_type': 'weight_reps',
    'instructions':
        'Hinge at the hips with a flat back and pull the bar to your lower ribs.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'pull_up',
    'name': 'Pull-Up',
    'primary_muscle': 'back',
    'secondary_muscles': 'biceps,forearms',
    'equipment': 'bodyweight',
    'environment': 'both',
    'tracking_type': 'reps_only',
    'instructions': 'Hang from a bar and pull until your chin clears it.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'lat_pulldown',
    'name': 'Lat Pulldown',
    'primary_muscle': 'back',
    'secondary_muscles': 'biceps',
    'equipment': 'cable',
    'environment': 'gym',
    'tracking_type': 'weight_reps',
    'instructions':
        'Pull the bar down to your upper chest while keeping your torso upright.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'overhead_press',
    'name': 'Overhead Press',
    'primary_muscle': 'shoulders',
    'secondary_muscles': 'triceps',
    'equipment': 'barbell',
    'environment': 'gym',
    'tracking_type': 'weight_reps',
    'instructions':
        'Press the bar from shoulder height to overhead without leaning back.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'dumbbell_shoulder_press',
    'name': 'Dumbbell Shoulder Press',
    'primary_muscle': 'shoulders',
    'secondary_muscles': 'triceps',
    'equipment': 'dumbbell',
    'environment': 'both',
    'tracking_type': 'weight_reps',
    'instructions': 'Press two dumbbells from shoulder height to overhead.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'pike_push_up',
    'name': 'Pike Push-Up',
    'primary_muscle': 'shoulders',
    'secondary_muscles': 'triceps',
    'equipment': 'bodyweight',
    'environment': 'home',
    'tracking_type': 'reps_only',
    'instructions':
        'From a downward-dog position, lower the top of your head toward the floor.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'dumbbell_curl',
    'name': 'Dumbbell Curl',
    'primary_muscle': 'biceps',
    'secondary_muscles': 'forearms',
    'equipment': 'dumbbell',
    'environment': 'both',
    'tracking_type': 'weight_reps',
    'instructions':
        'Curl the dumbbells up while keeping your elbows at your sides.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'triceps_pushdown',
    'name': 'Triceps Pushdown',
    'primary_muscle': 'triceps',
    'secondary_muscles': null,
    'equipment': 'cable',
    'environment': 'gym',
    'tracking_type': 'weight_reps',
    'instructions':
        'Push the cable handle down until your arms are fully straight.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'bench_dip',
    'name': 'Bench Dip',
    'primary_muscle': 'triceps',
    'secondary_muscles': 'chest',
    'equipment': 'bodyweight',
    'environment': 'both',
    'tracking_type': 'reps_only',
    'instructions':
        'With hands on a bench behind you, lower your body and press back up.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'barbell_back_squat',
    'name': 'Barbell Back Squat',
    'primary_muscle': 'quads',
    'secondary_muscles': 'glutes,hamstrings,core',
    'equipment': 'barbell',
    'environment': 'gym',
    'tracking_type': 'weight_reps',
    'instructions':
        'Rest the bar on your upper back and squat until your thighs are parallel.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'bodyweight_squat',
    'name': 'Bodyweight Squat',
    'primary_muscle': 'quads',
    'secondary_muscles': 'glutes',
    'equipment': 'bodyweight',
    'environment': 'home',
    'tracking_type': 'reps_only',
    'instructions':
        'Squat down until your thighs are parallel, then stand back up.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'bulgarian_split_squat',
    'name': 'Bulgarian Split Squat',
    'primary_muscle': 'quads',
    'secondary_muscles': 'glutes,hamstrings',
    'equipment': 'dumbbell',
    'environment': 'both',
    'tracking_type': 'weight_reps',
    'instructions':
        'With your back foot elevated, lower into a lunge on the front leg.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'romanian_deadlift',
    'name': 'Romanian Deadlift',
    'primary_muscle': 'hamstrings',
    'secondary_muscles': 'glutes,back',
    'equipment': 'barbell',
    'environment': 'gym',
    'tracking_type': 'weight_reps',
    'instructions':
        'Hinge at the hips with a slight knee bend and lower the bar along your legs.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'lying_leg_curl',
    'name': 'Lying Leg Curl',
    'primary_muscle': 'hamstrings',
    'secondary_muscles': 'calves',
    'equipment': 'machine',
    'environment': 'gym',
    'tracking_type': 'weight_reps',
    'instructions':
        'Curl the pad toward your glutes while lying face down.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'glute_bridge',
    'name': 'Glute Bridge',
    'primary_muscle': 'glutes',
    'secondary_muscles': 'hamstrings,core',
    'equipment': 'bodyweight',
    'environment': 'home',
    'tracking_type': 'reps_only',
    'instructions':
        'Lie on your back and lift your hips until your body forms a straight line.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'standing_calf_raise',
    'name': 'Standing Calf Raise',
    'primary_muscle': 'calves',
    'secondary_muscles': null,
    'equipment': 'bodyweight',
    'environment': 'both',
    'tracking_type': 'reps_only',
    'instructions':
        'Rise onto the balls of your feet, pause at the top, then lower slowly.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'plank',
    'name': 'Plank',
    'primary_muscle': 'core',
    'secondary_muscles': 'shoulders,glutes',
    'equipment': 'bodyweight',
    'environment': 'both',
    'tracking_type': 'duration',
    'instructions':
        'Hold a straight line from head to heels, bracing your core.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'hanging_leg_raise',
    'name': 'Hanging Leg Raise',
    'primary_muscle': 'core',
    'secondary_muscles': 'forearms',
    'equipment': 'bodyweight',
    'environment': 'gym',
    'tracking_type': 'reps_only',
    'instructions':
        'Hang from a bar and raise your legs to hip height or higher.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'wrist_curl',
    'name': 'Wrist Curl',
    'primary_muscle': 'forearms',
    'secondary_muscles': null,
    'equipment': 'dumbbell',
    'environment': 'both',
    'tracking_type': 'weight_reps',
    'instructions':
        'Rest your forearms on your thighs and curl your wrists upward.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'burpee',
    'name': 'Burpee',
    'primary_muscle': 'full_body',
    'secondary_muscles': 'chest,quads,core',
    'equipment': 'bodyweight',
    'environment': 'both',
    'tracking_type': 'reps_only',
    'instructions':
        'Squat, kick back to a push-up, jump your feet in, then jump up.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'jumping_jack',
    'name': 'Jumping Jack',
    'primary_muscle': 'cardio',
    'secondary_muscles': 'full_body',
    'equipment': 'bodyweight',
    'environment': 'home',
    'tracking_type': 'duration',
    'instructions':
        'Jump while spreading your legs and raising your arms overhead.',
    'is_custom': 0,
    'is_archived': 0,
  },
  {
    'slug': 'treadmill_run',
    'name': 'Treadmill Run',
    'primary_muscle': 'cardio',
    'secondary_muscles': 'quads,hamstrings,calves',
    'equipment': 'machine',
    'environment': 'gym',
    'tracking_type': 'duration',
    'instructions': 'Run at a steady, sustainable pace on the treadmill.',
    'is_custom': 0,
    'is_archived': 0,
  },
];

/// Built-in starter plans. Each references exercises by slug.
const List<Map<String, Object?>> _templateSeeds = [
  {
    'slug': 'gym_full_body',
    'name': 'Gym Full Body',
    'description': 'A balanced full-body session for the gym.',
    'environment': 'gym',
    'is_prebuilt': 1,
    'exercises': <Map<String, Object?>>[
      {
        'slug': 'barbell_back_squat',
        'position': 1,
        'target_sets': 3,
        'target_reps_min': 8,
        'target_reps_max': 10,
        'rest_seconds': 120,
        'notes': null,
      },
      {
        'slug': 'barbell_bench_press',
        'position': 2,
        'target_sets': 3,
        'target_reps_min': 8,
        'target_reps_max': 10,
        'rest_seconds': 120,
        'notes': null,
      },
      {
        'slug': 'bent_over_barbell_row',
        'position': 3,
        'target_sets': 3,
        'target_reps_min': 8,
        'target_reps_max': 10,
        'rest_seconds': 120,
        'notes': null,
      },
      {
        'slug': 'overhead_press',
        'position': 4,
        'target_sets': 3,
        'target_reps_min': 8,
        'target_reps_max': 10,
        'rest_seconds': 90,
        'notes': null,
      },
      {
        'slug': 'romanian_deadlift',
        'position': 5,
        'target_sets': 3,
        'target_reps_min': 8,
        'target_reps_max': 10,
        'rest_seconds': 120,
        'notes': null,
      },
      {
        'slug': 'hanging_leg_raise',
        'position': 6,
        'target_sets': 3,
        'target_reps_min': 10,
        'target_reps_max': 15,
        'rest_seconds': 60,
        'notes': null,
      },
      {
        'slug': 'plank',
        'position': 7,
        'target_sets': 3,
        'target_reps_min': 30,
        'target_reps_max': 45,
        'rest_seconds': 60,
        'notes': 'Seconds',
      },
    ],
  },
  {
    'slug': 'home_full_body',
    'name': 'Home Full Body',
    'description': 'A no-equipment full-body session for home.',
    'environment': 'home',
    'is_prebuilt': 1,
    'exercises': <Map<String, Object?>>[
      {
        'slug': 'bodyweight_squat',
        'position': 1,
        'target_sets': 3,
        'target_reps_min': 15,
        'target_reps_max': 20,
        'rest_seconds': 60,
        'notes': null,
      },
      {
        'slug': 'push_up',
        'position': 2,
        'target_sets': 3,
        'target_reps_min': 10,
        'target_reps_max': 15,
        'rest_seconds': 60,
        'notes': null,
      },
      {
        'slug': 'pike_push_up',
        'position': 3,
        'target_sets': 3,
        'target_reps_min': 8,
        'target_reps_max': 12,
        'rest_seconds': 60,
        'notes': null,
      },
      {
        'slug': 'glute_bridge',
        'position': 4,
        'target_sets': 3,
        'target_reps_min': 15,
        'target_reps_max': 20,
        'rest_seconds': 60,
        'notes': null,
      },
      {
        'slug': 'burpee',
        'position': 5,
        'target_sets': 3,
        'target_reps_min': 10,
        'target_reps_max': 15,
        'rest_seconds': 60,
        'notes': null,
      },
      {
        'slug': 'plank',
        'position': 6,
        'target_sets': 3,
        'target_reps_min': 30,
        'target_reps_max': 45,
        'rest_seconds': 60,
        'notes': 'Seconds',
      },
      {
        'slug': 'jumping_jack',
        'position': 7,
        'target_sets': 3,
        'target_reps_min': 45,
        'target_reps_max': 60,
        'rest_seconds': 45,
        'notes': 'Seconds',
      },
    ],
  },
];
