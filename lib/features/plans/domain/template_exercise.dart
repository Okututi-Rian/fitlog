import 'package:fitlog/features/exercises/domain/exercise.dart';

/// One exercise inside a [WorkoutTemplate] (docs/ARCHITECTURE.md section 6.2).
///
/// Plain Dart: no Flutter or database imports.
class TemplateExercise {
  const TemplateExercise({
    this.id,
    this.templateId,
    required this.exerciseId,
    required this.position,
    this.targetSets,
    this.targetRepsMin,
    this.targetRepsMax,
    this.restSeconds,
    this.notes,
    this.exercise,
  });

  final int? id;
  final int? templateId;
  final int exerciseId;
  final int position;
  final int? targetSets;
  final int? targetRepsMin;
  final int? targetRepsMax;
  final int? restSeconds;
  final String? notes;

  /// Populated when the row is read together with its exercise (a join).
  final Exercise? exercise;

  factory TemplateExercise.fromMap(
    Map<String, Object?> map, {
    Exercise? exercise,
  }) => TemplateExercise(
    id: map['id'] as int?,
    templateId: map['template_id'] as int?,
    exerciseId: map['exercise_id'] as int,
    position: map['position'] as int,
    targetSets: map['target_sets'] as int?,
    targetRepsMin: map['target_reps_min'] as int?,
    targetRepsMax: map['target_reps_max'] as int?,
    restSeconds: map['rest_seconds'] as int?,
    notes: map['notes'] as String?,
    exercise: exercise,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'template_id': templateId,
    'exercise_id': exerciseId,
    'position': position,
    'target_sets': targetSets,
    'target_reps_min': targetRepsMin,
    'target_reps_max': targetRepsMax,
    'rest_seconds': restSeconds,
    'notes': notes,
  };
}
