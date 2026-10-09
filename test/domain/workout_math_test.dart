import 'package:fitlog/features/session/domain/session_set.dart';
import 'package:fitlog/features/session/domain/workout_math.dart';
import 'package:flutter_test/flutter_test.dart';

SessionSet _set({
  double? weight,
  int? reps,
  bool completed = true,
  bool warmup = false,
}) {
  return SessionSet(
    sessionExerciseId: 1,
    setNumber: 1,
    weightKg: weight,
    reps: reps,
    isCompleted: completed,
    isWarmup: warmup,
  );
}

void main() {
  test('volume sums weight × reps of completed sets', () {
    final volume = totalVolume([
      _set(weight: 60, reps: 10),
      _set(weight: 50, reps: 8),
    ]);
    expect(volume, 1000);
  });

  test('volume ignores warm-up and unfinished sets', () {
    final volume = totalVolume([
      _set(weight: 100, reps: 5, warmup: true),
      _set(weight: 100, reps: 5, completed: false),
    ]);
    expect(volume, 0);
  });

  test('Epley one-rep max', () {
    expect(estimatedOneRepMax(100, 1), 100);
    expect(estimatedOneRepMax(100, 10), closeTo(133.33, 0.01));
  });

  test('kilograms to pounds', () {
    expect(kgToLb(100), closeTo(220.462, 0.001));
  });
}
