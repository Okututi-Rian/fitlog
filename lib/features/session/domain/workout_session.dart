import 'package:fitlog/core/utils/date_time_utils.dart';

/// One actual workout the user performed (or is performing).
///
/// Plain Dart: no Flutter or database imports (docs/ARCHITECTURE.md section 4).
class WorkoutSession {
  const WorkoutSession({
    this.id,
    this.templateId,
    required this.name,
    this.environment,
    required this.startedAt,
    this.endedAt,
    this.notes,
  });

  final int? id;

  /// Null for an empty (template-less) workout.
  final int? templateId;
  final String name;
  final String? environment;
  final DateTime startedAt;

  /// Null while the workout is still in progress.
  final DateTime? endedAt;
  final String? notes;

  /// `ended_at IS NULL` means the workout is still in progress.
  bool get isInProgress => endedAt == null;

  factory WorkoutSession.fromMap(Map<String, Object?> map) => WorkoutSession(
    id: map['id'] as int?,
    templateId: map['template_id'] as int?,
    name: map['name'] as String,
    environment: map['environment'] as String?,
    startedAt: epochMillisToDateTime(map['started_at'])!,
    endedAt: epochMillisToDateTime(map['ended_at']),
    notes: map['notes'] as String?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'template_id': templateId,
    'name': name,
    'environment': environment,
    'started_at': dateTimeToEpochMillis(startedAt),
    'ended_at': dateTimeToEpochMillis(endedAt),
    'notes': notes,
  };
}
