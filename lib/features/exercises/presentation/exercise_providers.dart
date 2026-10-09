import 'package:fitlog/features/exercises/data/exercise_repository.dart';
import 'package:fitlog/features/exercises/domain/exercise.dart';
import 'package:fitlog/features/exercises/domain/exercise_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exercises matching [filter]. Keyed by [ExerciseFilter] so each combination
/// is cached (docs/ARCHITECTURE.md section 10).
final exercisesProvider =
    FutureProvider.family<List<Exercise>, ExerciseFilter>((ref, filter) {
      return ref
          .watch(exerciseRepositoryProvider)
          .getAll(
            environment: filter.environment,
            muscle: filter.muscle,
            search: filter.search,
          );
    });

/// A single exercise by id.
final exerciseByIdProvider = FutureProvider.family<Exercise?, int>((ref, id) {
  return ref.watch(exerciseRepositoryProvider).getById(id);
});

/// All non-archived exercises, for pickers and dropdowns.
final allExercisesProvider = FutureProvider<List<Exercise>>((ref) {
  return ref.watch(exerciseRepositoryProvider).getAll();
});
