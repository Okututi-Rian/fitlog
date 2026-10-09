import 'package:fitlog/features/session/domain/session_set.dart';
import 'package:fitlog/features/session/domain/workout_session.dart';

/// Volume of a single set = weight × reps. Warm-up and unfinished sets count
/// as zero (docs/ARCHITECTURE.md section 9.6).
double setVolume(SessionSet set) {
  if (!set.isCompleted || set.isWarmup) return 0;
  return (set.weightKg ?? 0) * (set.reps ?? 0);
}

/// Total volume across many sets (section 9.6).
double totalVolume(Iterable<SessionSet> sets) =>
    sets.fold(0, (sum, set) => sum + setVolume(set));

/// Estimated one-rep max using the Epley formula (section 9.6).
double estimatedOneRepMax(double weightKg, int reps) {
  if (reps <= 1) return weightKg;
  return weightKg * (1 + reps / 30);
}

/// Kilograms to pounds (section 9.6).
double kgToLb(double kg) => kg * 2.20462;

/// Pounds to kilograms (section 9.6).
double lbToKg(double lb) => lb / 2.20462;

/// How long a session lasted, measured to [now] if it is still running.
Duration sessionDuration(WorkoutSession session, {DateTime? now}) {
  final end = session.endedAt ?? (now ?? DateTime.now().toUtc());
  return end.difference(session.startedAt);
}
