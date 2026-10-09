import 'package:fitlog/core/utils/date_time_utils.dart';
import 'package:fitlog/features/session/data/session_repository.dart';
import 'package:fitlog/features/session/domain/session_set.dart';
import 'package:fitlog/features/session/domain/workout_session.dart';
import 'package:fitlog/features/settings/data/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The unfinished workout, if any (docs/ARCHITECTURE.md section 9.7).
final activeSessionProvider = FutureProvider<WorkoutSession?>((ref) {
  return ref.watch(sessionRepositoryProvider).getActiveSession();
});

/// True when the user's week starts on Monday (the default setting).
final weekStartMondayProvider = FutureProvider<bool>((ref) async {
  final value = await ref.watch(settingsRepositoryProvider).get('week_start');
  return value != 'sunday';
});

/// Workouts finished this week and in total, for the Home stats.
final workoutStatsProvider = FutureProvider<({int thisWeek, int total})>((
  ref,
) async {
  final mondayStart = await ref.watch(weekStartMondayProvider.future);
  final weekStart = startOfWeek(DateTime.now(), mondayStart: mondayStart);
  return ref.watch(sessionRepositoryProvider).getWorkoutStats(weekStart);
});

/// Full detail (exercises + sets) for a session.
final sessionDetailProvider =
    FutureProvider.family<SessionDetail?, int>((ref, sessionId) {
      return ref.watch(sessionRepositoryProvider).getSessionDetail(sessionId);
    });

/// Key for [previousSetsProvider]: one exercise, excluding the current session.
typedef PreviousSetsKey = ({int exerciseId, int sessionId});

/// The most recent other session's sets for an exercise (section 9.3).
final previousSetsProvider =
    FutureProvider.family<List<SessionSet>, PreviousSetsKey>((ref, key) {
      return ref
          .watch(sessionRepositoryProvider)
          .getPreviousSets(key.exerciseId, excludingSessionId: key.sessionId);
    });

/// Starts a workout from a plan. If a workout is already in progress, resumes
/// it instead so a session is never orphaned.
Future<WorkoutSession> startWorkoutFromTemplate(
  WidgetRef ref,
  int templateId,
) async {
  final repository = ref.read(sessionRepositoryProvider);
  final active = await repository.getActiveSession();
  final session = active ?? await repository.startFromTemplate(templateId);
  ref.invalidate(activeSessionProvider);
  return session;
}

/// Starts an empty workout, or resumes the in-progress one if there is one.
Future<WorkoutSession> startEmptyWorkout(WidgetRef ref) async {
  final repository = ref.read(sessionRepositoryProvider);
  final active = await repository.getActiveSession();
  final session = active ?? await repository.startEmpty();
  ref.invalidate(activeSessionProvider);
  return session;
}
