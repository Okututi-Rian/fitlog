import 'package:fitlog/features/session/domain/workout_math.dart';

/// One completed set performed for an exercise, used to build progress charts
/// and personal records (docs/ARCHITECTURE.md section 9.6).
class ExerciseSetSample {
  const ExerciseSetSample({
    required this.date,
    this.weightKg,
    this.reps,
    this.durationSeconds,
  });

  final DateTime date;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
}

/// A point on the estimated-1RM-over-time chart.
class ProgressPoint {
  const ProgressPoint({required this.date, required this.estimatedOneRepMax});

  final DateTime date;
  final double estimatedOneRepMax;
}

/// The best lifts recorded for an exercise (section 9.6).
class PersonalRecords {
  const PersonalRecords({
    this.heaviestWeightKg,
    this.heaviestWeightDate,
    this.bestE1rm,
    this.bestE1rmDate,
  });

  final double? heaviestWeightKg;
  final DateTime? heaviestWeightDate;
  final double? bestE1rm;
  final DateTime? bestE1rmDate;

  bool get isEmpty => heaviestWeightKg == null && bestE1rm == null;
}

/// The best estimated 1RM per calendar day, oldest first.
List<ProgressPoint> e1rmSeries(List<ExerciseSetSample> samples) {
  final best = <DateTime, double>{};
  for (final sample in samples) {
    final weight = sample.weightKg;
    final reps = sample.reps;
    if (weight == null || reps == null || reps <= 0) continue;
    final e1rm = estimatedOneRepMax(weight, reps);
    final day = DateTime(sample.date.year, sample.date.month, sample.date.day);
    if (!best.containsKey(day) || e1rm > best[day]!) best[day] = e1rm;
  }
  final days = best.keys.toList()..sort();
  return [
    for (final day in days)
      ProgressPoint(date: day, estimatedOneRepMax: best[day]!),
  ];
}

/// Heaviest weight and best estimated 1RM across [samples].
PersonalRecords personalRecords(List<ExerciseSetSample> samples) {
  double? heaviest;
  DateTime? heaviestDate;
  double? bestE1rm;
  DateTime? bestE1rmDate;

  for (final sample in samples) {
    final weight = sample.weightKg;
    if (weight != null && (heaviest == null || weight > heaviest)) {
      heaviest = weight;
      heaviestDate = sample.date;
    }
    final reps = sample.reps;
    if (weight != null && reps != null && reps > 0) {
      final e1rm = estimatedOneRepMax(weight, reps);
      if (bestE1rm == null || e1rm > bestE1rm) {
        bestE1rm = e1rm;
        bestE1rmDate = sample.date;
      }
    }
  }

  return PersonalRecords(
    heaviestWeightKg: heaviest,
    heaviestWeightDate: heaviestDate,
    bestE1rm: bestE1rm,
    bestE1rmDate: bestE1rmDate,
  );
}
