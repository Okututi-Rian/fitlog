import 'package:fitlog/features/exercises/domain/exercise.dart';

/// An exercise performed within a [WorkoutSession].
///
/// Plain Dart: no Flutter or database imports (docs/ARCHITECTURE.md section 4).
class SessionExercise {
  const SessionExercise({
    this.id,
    this.sessionId,
    required this.exerciseId,
    required this.position,
    this.restSeconds,
    this.notes,
    this.exercise,
  });

  final int? id;
  final int? sessionId;
  final int exerciseId;
  final int position;
  final int? restSeconds;
  final String? notes;

  /// Populated when the row is read together with its exercise (a join).
  final Exercise? exercise;

  factory SessionExercise.fromMap(
    Map<String, Object?> map, {
    Exercise? exercise,
  }) => SessionExercise(
    id: map['id'] as int?,
    sessionId: map['session_id'] as int?,
    exerciseId: map['exercise_id'] as int,
    position: map['position'] as int,
    restSeconds: map['rest_seconds'] as int?,
    notes: map['notes'] as String?,
    exercise: exercise,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'session_id': sessionId,
    'exercise_id': exerciseId,
    'position': position,
    'rest_seconds': restSeconds,
    'notes': notes,
  };
}
