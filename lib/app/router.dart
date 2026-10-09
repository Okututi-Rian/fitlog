import 'package:fitlog/app/routes.dart';
import 'package:fitlog/features/exercises/presentation/exercise_detail_screen.dart';
import 'package:fitlog/features/exercises/presentation/exercise_form_screen.dart';
import 'package:fitlog/features/exercises/presentation/exercise_list_screen.dart';
import 'package:fitlog/features/history/presentation/history_detail_screen.dart';
import 'package:fitlog/features/history/presentation/history_screen.dart';
import 'package:fitlog/features/onboarding/presentation/onboarding_screen.dart';
import 'package:fitlog/features/plans/presentation/plan_detail_screen.dart';
import 'package:fitlog/features/plans/presentation/plan_editor_screen.dart';
import 'package:fitlog/features/plans/presentation/plans_screen.dart';
import 'package:fitlog/features/progress/presentation/progress_screen.dart';
import 'package:fitlog/features/session/presentation/active_workout_screen.dart';
import 'package:fitlog/features/session/presentation/home_screen.dart';
import 'package:fitlog/features/settings/domain/app_settings.dart';
import 'package:fitlog/features/settings/presentation/settings_providers.dart';
import 'package:fitlog/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The app router.
///
/// Onboarding is shown until `onboarding_complete` is set, then the tab shell
/// (docs/ARCHITECTURE.md section 8, Journey A).
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AppSettings>(ref.read(settingsProvider));
  ref.listen<AppSettings>(settingsProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final onboardingComplete = ref
          .read(settingsProvider)
          .onboardingComplete;
      final atOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!onboardingComplete) {
        return atOnboarding ? null : AppRoutes.onboarding;
      }
      if (atOnboarding) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            _AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.plans,
                builder: (context, state) => const PlansScreen(),
                routes: [
                  // Plans. `templates/new` must precede `templates/:id`.
                  GoRoute(
                    path: 'templates/new',
                    builder: (context, state) => const PlanEditorScreen(),
                  ),
                  GoRoute(
                    path: 'templates/:id',
                    builder: (context, state) => PlanDetailScreen(
                      templateId: int.parse(state.pathParameters['id']!),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) => PlanEditorScreen(
                          templateId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                      GoRoute(
                        path: 'duplicate',
                        builder: (context, state) => PlanEditorScreen(
                          duplicateFromId: int.parse(
                            state.pathParameters['id']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Exercise library. `new` must precede `:id`.
                  GoRoute(
                    path: 'exercises/new',
                    builder: (context, state) => const ExerciseFormScreen(),
                  ),
                  GoRoute(
                    path: 'exercises/:id',
                    builder: (context, state) => ExerciseDetailScreen(
                      exerciseId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => HistoryDetailScreen(
                      sessionId: int.parse(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.activeSessionPattern,
        builder: (context, state) => ActiveWorkoutScreen(
          sessionId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.pickExercise,
        builder: (context, state) => const ExerciseListScreen(
          selectionMode: true,
          title: 'Add exercise',
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

/// Scaffold that hosts the bottom navigation around the current tab.
class _AppShell extends StatelessWidget {
  const _AppShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the current tab returns it to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            label: 'Plans',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.insights), label: 'Progress'),
        ],
      ),
    );
  }
}
