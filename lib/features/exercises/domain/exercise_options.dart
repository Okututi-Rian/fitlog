/// The option sets the exercise UI offers. Kept as plain data in the domain
/// (docs/ARCHITECTURE.md section 6.2).
library;

const List<String> kMuscleGroups = [
  'chest',
  'back',
  'shoulders',
  'biceps',
  'triceps',
  'quads',
  'hamstrings',
  'glutes',
  'calves',
  'core',
  'forearms',
  'full_body',
  'cardio',
];

const List<String> kEquipmentTypes = [
  'barbell',
  'dumbbell',
  'machine',
  'cable',
  'bodyweight',
  'kettlebell',
  'band',
  'none',
];

const List<String> kEnvironments = ['gym', 'home', 'both'];
