import 'package:fitlog/core/utils/date_time_utils.dart';

/// A single set within a [SessionExercise].
///
/// Plain Dart: no Flutter or database imports (docs/ARCHITECTURE.md section 4).
class SessionSet {
  const SessionSet({
    this.id,
    required this.sessionExerciseId,
    required this.setNumber,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.isWarmup = false,
    this.isCompleted = false,
    this.completedAt,
  });

  final int? id;
  final int sessionExerciseId;
  final int setNumber;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final bool isWarmup;
  final bool isCompleted;
  final DateTime? completedAt;

  factory SessionSet.fromMap(Map<String, Object?> map) => SessionSet(
    id: map['id'] as int?,
    sessionExerciseId: map['session_exercise_id'] as int,
    setNumber: map['set_number'] as int,
    weightKg: (map['weight_kg'] as num?)?.toDouble(),
    reps: map['reps'] as int?,
    durationSeconds: map['duration_seconds'] as int?,
    isWarmup: (map['is_warmup'] as int? ?? 0) == 1,
    isCompleted: (map['is_completed'] as int? ?? 0) == 1,
    completedAt: epochMillisToDateTime(map['completed_at']),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'session_exercise_id': sessionExerciseId,
    'set_number': setNumber,
    'weight_kg': weightKg,
    'reps': reps,
    'duration_seconds': durationSeconds,
    'is_warmup': isWarmup ? 1 : 0,
    'is_completed': isCompleted ? 1 : 0,
    'completed_at': dateTimeToEpochMillis(completedAt),
  };
}
