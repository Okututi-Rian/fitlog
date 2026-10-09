import 'package:fitlog/core/utils/date_time_utils.dart';

/// A body-weight log entry. Weight is always stored in kilograms.
///
/// Plain Dart: no Flutter or database imports (docs/ARCHITECTURE.md section 4).
class BodyWeightEntry {
  const BodyWeightEntry({
    this.id,
    required this.weightKg,
    required this.loggedAt,
  });

  final int? id;
  final double weightKg;
  final DateTime loggedAt;

  factory BodyWeightEntry.fromMap(Map<String, Object?> map) => BodyWeightEntry(
    id: map['id'] as int?,
    weightKg: (map['weight_kg'] as num).toDouble(),
    loggedAt: epochMillisToDateTime(map['logged_at'])!,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'weight_kg': weightKg,
    'logged_at': dateTimeToEpochMillis(loggedAt),
  };
}
