import 'package:fitlog/features/settings/data/settings_repository.dart';
import 'package:fitlog/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current settings.
///
/// Loaded from the database before the first frame (see `main`), then updated
/// in place as the user changes things, so the router and theme react live.
final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  /// Loads every setting from the database.
  Future<void> load() async {
    final map = await ref.read(settingsRepositoryProvider).getAll();
    state = AppSettings.fromMap(map);
  }

  Future<void> _update(String key, String value) async {
    final repository = ref.read(settingsRepositoryProvider);
    await repository.set(key, value);
    state = AppSettings.fromMap(await repository.getAll());
  }

  Future<void> setUnitSystem(UnitSystem unit) =>
      _update('unit_system', unit.name);

  Future<void> setThemeMode(AppThemeMode mode) =>
      _update('theme_mode', mode.name);

  Future<void> setWeekStart(WeekStart start) =>
      _update('week_start', start.name);

  Future<void> setEnvironment(String environment) =>
      _update('environment_mode', environment);

  Future<void> setGoal(String goal) => _update('goal', goal);

  Future<void> setWeeklyTarget(int days) =>
      _update('weekly_target', '$days');

  Future<void> completeOnboarding() =>
      _update('onboarding_complete', 'true');
}

/// The selected weight unit (metric = kg, imperial = lb).
final unitSystemProvider = Provider<UnitSystem>(
  (ref) => ref.watch(settingsProvider).unitSystem,
);

extension AppThemeModeX on AppThemeMode {
  ThemeMode toThemeMode() => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}
