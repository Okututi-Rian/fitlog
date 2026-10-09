import 'package:fitlog/features/progress/data/body_weight_repository.dart';
import 'package:fitlog/features/progress/data/progress_repository.dart';
import 'package:fitlog/features/progress/domain/body_weight_entry.dart';
import 'package:fitlog/features/progress/domain/progress_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chart points and personal records for one exercise.
typedef ExerciseProgress = ({
  List<ProgressPoint> points,
  PersonalRecords records,
});

/// Estimated-1RM series and PRs for an exercise (section 9.6).
final exerciseProgressProvider =
    FutureProvider.family<ExerciseProgress, int>((ref, exerciseId) async {
      final samples = await ref
          .watch(progressRepositoryProvider)
          .getCompletedSetsForExercise(exerciseId);
      return (points: e1rmSeries(samples), records: personalRecords(samples));
    });

/// All logged body-weight entries, newest first.
final bodyWeightProvider = FutureProvider<List<BodyWeightEntry>>((ref) {
  return ref.watch(bodyWeightRepositoryProvider).getAll();
});
