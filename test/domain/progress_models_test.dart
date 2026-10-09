import 'package:fitlog/features/progress/domain/progress_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day1 = DateTime(2026, 1, 1);
  final day2 = DateTime(2026, 1, 3);

  test('e1rmSeries keeps the best set per day, oldest first', () {
    final points = e1rmSeries([
      ExerciseSetSample(date: day1, weightKg: 100, reps: 5), // 116.67
      ExerciseSetSample(date: day1, weightKg: 110, reps: 5), // 128.33
      ExerciseSetSample(date: day2, weightKg: 115, reps: 3), // 126.5
    ]);
    expect(points, hasLength(2));
    expect(points.first.date, day1);
    expect(points.first.estimatedOneRepMax, closeTo(128.33, 0.01));
    expect(points.last.estimatedOneRepMax, closeTo(126.5, 0.01));
  });

  test('e1rmSeries ignores sets without weight and reps', () {
    final points = e1rmSeries([
      ExerciseSetSample(date: day1, reps: 10),
      ExerciseSetSample(date: day1, weightKg: 60),
      ExerciseSetSample(date: day1, durationSeconds: 30),
    ]);
    expect(points, isEmpty);
  });

  test('personalRecords finds heaviest weight and best e1RM', () {
    final records = personalRecords([
      ExerciseSetSample(date: day1, weightKg: 100, reps: 5),
      ExerciseSetSample(date: day2, weightKg: 90, reps: 10), // e1RM 120
    ]);
    expect(records.heaviestWeightKg, 100);
    expect(records.heaviestWeightDate, day1);
    expect(records.bestE1rm, closeTo(120, 0.01));
    expect(records.bestE1rmDate, day2);
  });

  test('personalRecords is empty with no weighted sets', () {
    final records = personalRecords([
      ExerciseSetSample(date: day1, reps: 10),
    ]);
    expect(records.isEmpty, isTrue);
  });
}
