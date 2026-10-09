import 'package:fitlog/features/session/domain/workout_math.dart';

/// The user's chosen weight unit. Storage is always kilograms; this only
/// affects display and input (docs/ARCHITECTURE.md sections 6.3 / 9.6).
enum UnitSystem { metric, imperial }

/// Light/dark/system preference.
enum AppThemeMode { system, light, dark }

/// Which day the user's week starts on.
enum WeekStart { monday, sunday }

/// All user-configurable settings, mirrored from the `user_settings` table.
///
/// Plain Dart: no Flutter imports (docs/ARCHITECTURE.md section 4).
class AppSettings {
  const AppSettings({
    this.unitSystem = UnitSystem.metric,
    this.environmentMode = 'both',
    this.goal,
    this.weeklyTarget,
    this.themeMode = AppThemeMode.system,
    this.weekStart = WeekStart.monday,
    this.onboardingComplete = false,
  });

  final UnitSystem unitSystem;
  final String environmentMode;
  final String? goal;
  final int? weeklyTarget;
  final AppThemeMode themeMode;
  final WeekStart weekStart;
  final bool onboardingComplete;

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      unitSystem: map['unit_system'] == 'imperial'
          ? UnitSystem.imperial
          : UnitSystem.metric,
      environmentMode: map['environment_mode'] ?? 'both',
      goal: map['goal'],
      weeklyTarget: int.tryParse(map['weekly_target'] ?? ''),
      themeMode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == map['theme_mode'],
        orElse: () => AppThemeMode.system,
      ),
      weekStart: map['week_start'] == 'sunday'
          ? WeekStart.sunday
          : WeekStart.monday,
      onboardingComplete: map['onboarding_complete'] == 'true',
    );
  }
}

extension UnitSystemConversion on UnitSystem {
  bool get isImperial => this == UnitSystem.imperial;

  /// Converts a stored kilogram value to the unit shown to the user.
  double toDisplay(double kg) => isImperial ? kgToLb(kg) : kg;

  /// Converts a value the user typed back to kilograms for storage.
  double toStorage(double value) => isImperial ? lbToKg(value) : value;

  String get weightLabel => isImperial ? 'lb' : 'kg';
}
