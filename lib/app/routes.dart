/// Route paths used across the app (docs/ARCHITECTURE.md section 8).
///
/// Kept separate from `router.dart` so feature screens can navigate without
/// importing the router (which imports the screens).
class AppRoutes {
  AppRoutes._();

  static const String home = '/home';
  static const String plans = '/plans';
  static const String history = '/history';
  static const String progress = '/progress';
  static const String onboarding = '/onboarding';
  static const String settings = '/settings';

  static const String newExercise = '/plans/exercises/new';
  static const String pickExercise = '/pick-exercise';

  static const String newPlan = '/plans/templates/new';

  /// Full-screen route (outside the tab shell) for the active workout.
  static const String activeSessionPattern = '/session/active/:id';
  static String activeSession(int id) => '/session/active/$id';

  static String exerciseDetail(int id) => '/plans/exercises/$id';
  static String planDetail(int id) => '/plans/templates/$id';
  static String editPlan(int id) => '/plans/templates/$id/edit';
  static String duplicatePlan(int id) => '/plans/templates/$id/duplicate';
  static String historyDetail(int id) => '/history/$id';
}
