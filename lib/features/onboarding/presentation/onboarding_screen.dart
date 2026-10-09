import 'package:fitlog/features/settings/domain/app_settings.dart';
import 'package:fitlog/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// First-launch setup: environment, units, and goal + weekly target
/// (docs/ARCHITECTURE.md Journey A).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const List<({String value, String label})> _environments = [
    (value: 'gym', label: 'Gym'),
    (value: 'home', label: 'Home'),
    (value: 'both', label: 'Both'),
  ];
  static const List<({String value, String label})> _goals = [
    (value: 'build_muscle', label: 'Build muscle'),
    (value: 'get_stronger', label: 'Get stronger'),
    (value: 'lose_fat', label: 'Lose fat'),
    (value: 'general_fitness', label: 'General fitness'),
  ];

  final PageController _pageController = PageController();
  int _page = 0;

  String _environment = 'both';
  UnitSystem _unit = UnitSystem.metric;
  String _goal = 'build_muscle';
  int _weeklyTarget = 3;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    final controller = ref.read(settingsProvider.notifier);
    await controller.setEnvironment(_environment);
    await controller.setUnitSystem(_unit);
    await controller.setGoal(_goal);
    await controller.setWeeklyTarget(_weeklyTarget);
    // Setting this makes the router redirect to the tab shell.
    await controller.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Welcome to FitLog'),
        leading: _page > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _page = index),
              children: [_environmentPage(), _unitsPage(), _goalPage()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      i == _page ? Icons.circle : Icons.circle_outlined,
                      size: 12,
                      color: i == _page
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _next,
                  child: Text(_page == 2 ? 'Finish' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _environmentPage() {
    return _pageScaffold(
      title: 'Where do you train?',
      subtitle: 'We use this to show relevant exercises and plans.',
      child: Column(
        children: [
          for (final option in _environments)
            _optionTile(
              label: option.label,
              selected: _environment == option.value,
              onTap: () => setState(() => _environment = option.value),
            ),
        ],
      ),
    );
  }

  Widget _unitsPage() {
    return _pageScaffold(
      title: 'Which units do you use?',
      subtitle: 'Weights are stored the same way either way.',
      child: Column(
        children: [
          _optionTile(
            label: 'Kilograms (kg)',
            selected: _unit == UnitSystem.metric,
            onTap: () => setState(() => _unit = UnitSystem.metric),
          ),
          _optionTile(
            label: 'Pounds (lb)',
            selected: _unit == UnitSystem.imperial,
            onTap: () => setState(() => _unit = UnitSystem.imperial),
          ),
        ],
      ),
    );
  }

  Widget _goalPage() {
    final theme = Theme.of(context);
    return _pageScaffold(
      title: 'What is your goal?',
      subtitle: 'Pick what matters most right now.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final option in _goals)
            _optionTile(
              label: option.label,
              selected: _goal == option.value,
              onTap: () => setState(() => _goal = option.value),
            ),
          const SizedBox(height: 24),
          Text('Days per week', style: theme.textTheme.titleSmall),
          Slider(
            value: _weeklyTarget.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            label: '$_weeklyTarget days',
            onChanged: (value) =>
                setState(() => _weeklyTarget = value.round()),
          ),
          Center(child: Text('$_weeklyTarget days per week')),
        ],
      ),
    );
  }

  Widget _pageScaffold({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
        child,
      ],
    );
  }

  Widget _optionTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label),
        selected: selected,
        trailing: selected ? const Icon(Icons.check_circle) : null,
        onTap: onTap,
      ),
    );
  }
}
