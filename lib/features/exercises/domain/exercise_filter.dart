/// Filter applied to the exercise list.
///
/// Value equality is required so Riverpod's `family` caches results per filter
/// instead of refetching on every rebuild (docs/ARCHITECTURE.md section 10).
class ExerciseFilter {
  const ExerciseFilter({this.environment, this.muscle, this.search});

  final String? environment;
  final String? muscle;
  final String? search;

  @override
  bool operator ==(Object other) =>
      other is ExerciseFilter &&
      other.environment == environment &&
      other.muscle == muscle &&
      other.search == search;

  @override
  int get hashCode => Object.hash(environment, muscle, search);
}
