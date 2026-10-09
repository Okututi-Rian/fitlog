/// A single exercise in the library (built-in or user-created).
///
/// Plain Dart: no Flutter or database imports (docs/ARCHITECTURE.md section 4).
class Exercise {
  const Exercise({
    this.id,
    this.slug,
    required this.name,
    required this.primaryMuscle,
    this.secondaryMuscles,
    required this.equipment,
    required this.environment,
    required this.trackingType,
    this.instructions,
    this.isCustom = false,
    this.isArchived = false,
  });

  final int? id;
  final String? slug;
  final String name;
  final String primaryMuscle;
  final String? secondaryMuscles;
  final String equipment;
  final String environment;
  final String trackingType;
  final String? instructions;
  final bool isCustom;
  final bool isArchived;

  factory Exercise.fromMap(Map<String, Object?> map) => Exercise(
    id: map['id'] as int?,
    slug: map['slug'] as String?,
    name: map['name'] as String,
    primaryMuscle: map['primary_muscle'] as String,
    secondaryMuscles: map['secondary_muscles'] as String?,
    equipment: map['equipment'] as String,
    environment: map['environment'] as String,
    trackingType: map['tracking_type'] as String,
    instructions: map['instructions'] as String?,
    isCustom: (map['is_custom'] as int? ?? 0) == 1,
    isArchived: (map['is_archived'] as int? ?? 0) == 1,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'slug': slug,
    'name': name,
    'primary_muscle': primaryMuscle,
    'secondary_muscles': secondaryMuscles,
    'equipment': equipment,
    'environment': environment,
    'tracking_type': trackingType,
    'instructions': instructions,
    'is_custom': isCustom ? 1 : 0,
    'is_archived': isArchived ? 1 : 0,
  };
}
