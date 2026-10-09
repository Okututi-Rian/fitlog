import 'package:fitlog/core/utils/date_time_utils.dart';
import 'package:fitlog/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startOfWeek', () {
    test('Monday start (2026-10-09 is a Friday)', () {
      expect(startOfWeek(DateTime(2026, 10, 9)), DateTime(2026, 10, 5));
    });

    test('Sunday start', () {
      expect(
        startOfWeek(DateTime(2026, 10, 9), mondayStart: false),
        DateTime(2026, 10, 4),
      );
    });
  });

  group('AppSettings.fromMap', () {
    test('parses stored values', () {
      final settings = AppSettings.fromMap({
        'unit_system': 'imperial',
        'environment_mode': 'home',
        'goal': 'lose_fat',
        'weekly_target': '4',
        'theme_mode': 'dark',
        'week_start': 'sunday',
        'onboarding_complete': 'true',
      });
      expect(settings.unitSystem, UnitSystem.imperial);
      expect(settings.environmentMode, 'home');
      expect(settings.goal, 'lose_fat');
      expect(settings.weeklyTarget, 4);
      expect(settings.themeMode, AppThemeMode.dark);
      expect(settings.weekStart, WeekStart.sunday);
      expect(settings.onboardingComplete, isTrue);
    });

    test('falls back to defaults when unset', () {
      final settings = AppSettings.fromMap({});
      expect(settings.unitSystem, UnitSystem.metric);
      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.weekStart, WeekStart.monday);
      expect(settings.onboardingComplete, isFalse);
    });
  });

  test('unit conversion round-trips', () {
    expect(UnitSystem.imperial.toDisplay(100), closeTo(220.462, 0.01));
    expect(UnitSystem.imperial.toStorage(220.462), closeTo(100, 0.01));
    expect(UnitSystem.metric.toDisplay(100), 100);
    expect(UnitSystem.metric.toStorage(100), 100);
  });
}
