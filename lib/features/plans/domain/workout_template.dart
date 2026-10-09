import 'package:fitlog/core/utils/date_time_utils.dart';

/// A saved workout plan ("template"), e.g. "Push Day".
///
/// Plain Dart: no Flutter or database imports (docs/ARCHITECTURE.md section 4).
class WorkoutTemplate {
  const WorkoutTemplate({
    this.id,
    this.slug,
    required this.name,
    this.description,
    required this.environment,
    this.isPrebuilt = false,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String? slug;
  final String name;
  final String? description;
  final String environment;
  final bool isPrebuilt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WorkoutTemplate.fromMap(Map<String, Object?> map) => WorkoutTemplate(
    id: map['id'] as int?,
    slug: map['slug'] as String?,
    name: map['name'] as String,
    description: map['description'] as String?,
    environment: map['environment'] as String,
    isPrebuilt: (map['is_prebuilt'] as int? ?? 0) == 1,
    createdAt: epochMillisToDateTime(map['created_at']),
    updatedAt: epochMillisToDateTime(map['updated_at']),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'slug': slug,
    'name': name,
    'description': description,
    'environment': environment,
    'is_prebuilt': isPrebuilt ? 1 : 0,
    'created_at': dateTimeToEpochMillis(createdAt),
    'updated_at': dateTimeToEpochMillis(updatedAt),
  };
}
