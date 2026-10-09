import 'dart:async';

import 'package:fitlog/app/routes.dart';
import 'package:fitlog/core/utils/formatters.dart';
import 'package:fitlog/core/widgets/error_view.dart';
import 'package:fitlog/features/exercises/domain/exercise.dart';
import 'package:fitlog/features/history/presentation/history_providers.dart';
import 'package:fitlog/features/progress/presentation/progress_providers.dart';
import 'package:fitlog/features/session/data/session_repository.dart';
import 'package:fitlog/features/session/domain/session_exercise.dart';
import 'package:fitlog/features/session/domain/session_set.dart';
import 'package:fitlog/features/session/domain/workout_math.dart';
import 'package:fitlog/features/session/presentation/session_providers.dart';
import 'package:fitlog/features/settings/domain/app_settings.dart';
import 'package:fitlog/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Signature for "user ticked a set": carries whatever the tracking type needs.
typedef CompleteSetCallback =
    void Function(
      int setId, {
      double? weightKg,
      int? reps,
      int? durationSeconds,
    });

/// The focused, full-screen workout logger (docs/ARCHITECTURE.md section 7
/// Journey B, sections 9.1-9.5).
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  /// When the current rest ends. Remaining time is always computed from the
  /// clock, never by counting ticks (section 9.4).
  DateTime? _restEndsAt;
  String? _restExerciseName;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _setWakelock(true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _setWakelock(false);
    super.dispose();
  }

  Future<void> _setWakelock(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {
      // Wakelock is not available on every platform (e.g. tests).
    }
  }

  Duration get _restRemaining {
    final endsAt = _restEndsAt;
    if (endsAt == null) return Duration.zero;
    final remaining = endsAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _startRest(int seconds, String exerciseName) {
    if (seconds <= 0) return;
    _ticker?.cancel();
    setState(() {
      _restEndsAt = DateTime.now().add(Duration(seconds: seconds));
      _restExerciseName = exerciseName;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_restRemaining <= Duration.zero) {
        _ticker?.cancel();
        _ticker = null;
        HapticFeedback.vibrate();
        setState(() {
          _restEndsAt = null;
          _restExerciseName = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  void _skipRest() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _restEndsAt = null;
      _restExerciseName = null;
    });
  }

  Future<void> _completeSet(
    SessionExercise sessionExercise,
    int setId, {
    double? weightKg,
    int? reps,
    int? durationSeconds,
  }) async {
    await ref
        .read(sessionRepositoryProvider)
        .completeSet(
          setId,
          weightKg: weightKg,
          reps: reps,
          durationSeconds: durationSeconds,
        );
    ref.invalidate(sessionDetailProvider(widget.sessionId));
    _startRest(
      sessionExercise.restSeconds ?? 90,
      sessionExercise.exercise?.name ?? 'Rest',
    );
  }

  Future<void> _addSet(SessionExercise sessionExercise) async {
    await ref.read(sessionRepositoryProvider).addSetRow(sessionExercise.id!);
    ref.invalidate(sessionDetailProvider(widget.sessionId));
  }

  Future<void> _addExercise() async {
    final picked = await context.push<Exercise>(AppRoutes.pickExercise);
    if (picked == null || !mounted) return;
    await ref
        .read(sessionRepositoryProvider)
        .addExercise(widget.sessionId, picked.id!);
    ref.invalidate(sessionDetailProvider(widget.sessionId));
  }

  Future<void> _finish() async {
    final detail = ref.read(sessionDetailProvider(widget.sessionId)).value;
    if (detail == null) return;

    final sets = [
      for (final entry in detail.exercises) ...entry.sets,
    ];
    final volume = totalVolume(sets);
    final completedSets = sets.where((set) => set.isCompleted).length;
    final duration = sessionDuration(detail.session);
    final unit = ref.read(unitSystemProvider);

    // Drop empty rows and stamp ended_at (section 9.5).
    await ref.read(sessionRepositoryProvider).finish(widget.sessionId);
    ref.invalidate(activeSessionProvider);
    ref.invalidate(sessionDetailProvider(widget.sessionId));
    ref.invalidate(workoutStatsProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(exerciseProgressProvider);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Workout complete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow('Duration', formatDuration(duration)),
            _summaryRow(
              'Total volume',
              '${unit.toDisplay(volume).toStringAsFixed(0)} ${unit.weightLabel}',
            ),
            _summaryRow('Sets completed', '$completedSets'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (mounted) context.go(AppRoutes.home);
  }

  Future<void> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text(
          'This workout and everything logged in it will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionRepositoryProvider).discard(widget.sessionId);
    ref.invalidate(activeSessionProvider);
    ref.invalidate(sessionDetailProvider(widget.sessionId));
    ref.invalidate(workoutStatsProvider);
    ref.invalidate(historyProvider);
    ref.invalidate(exerciseProgressProvider);
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(sessionDetailProvider(widget.sessionId));
    final session = detail.value?.session;

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.name ?? 'Workout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Discard',
            onPressed: _confirmDiscard,
          ),
          TextButton(onPressed: _finish, child: const Text('Finish')),
        ],
      ),
      body: Column(
        children: [
          if (_restEndsAt != null)
            _RestTimerBar(
              exerciseName: _restExerciseName,
              remaining: _restRemaining,
              onSkip: _skipRest,
            ),
          Expanded(
            child: detail.when(
              data: (value) => value == null
                  ? const Center(child: Text('Workout not found.'))
                  : _buildWorkout(value),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                message: '$error',
                onRetry: () =>
                    ref.invalidate(sessionDetailProvider(widget.sessionId)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkout(SessionDetail detail) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        if (detail.exercises.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No exercises yet — add one below.')),
          ),
        for (final entry in detail.exercises)
          _ExerciseCard(
            sessionId: widget.sessionId,
            sessionExercise: entry.sessionExercise,
            sets: entry.sets,
            onCompleteSet: (setId, {weightKg, reps, durationSeconds}) =>
                _completeSet(
                  entry.sessionExercise,
                  setId,
                  weightKg: weightKg,
                  reps: reps,
                  durationSeconds: durationSeconds,
                ),
            onAddSet: () => _addSet(entry.sessionExercise),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addExercise,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
      ],
    );
  }
}

class _RestTimerBar extends StatelessWidget {
  const _RestTimerBar({
    required this.exerciseName,
    required this.remaining,
    required this.onSkip,
  });

  final String? exerciseName;
  final Duration remaining;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${exerciseName ?? 'Rest'} · ${formatCountdown(remaining)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton(onPressed: onSkip, child: const Text('Skip')),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.sessionId,
    required this.sessionExercise,
    required this.sets,
    required this.onCompleteSet,
    required this.onAddSet,
  });

  final int sessionId;
  final SessionExercise sessionExercise;
  final List<SessionSet> sets;
  final CompleteSetCallback onCompleteSet;
  final VoidCallback onAddSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trackingType =
        sessionExercise.exercise?.trackingType ?? 'weight_reps';
    final unit = ref.watch(unitSystemProvider);
    final previous = ref.watch(
      previousSetsProvider((
        exerciseId: sessionExercise.exerciseId,
        sessionId: sessionId,
      )),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sessionExercise.exercise?.name ?? 'Exercise',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            previous.when(
              data: (prev) => Text(
                _previousText(prev, trackingType, unit),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            previous.when(
              data: (prev) => _setRows(prev, unit),
              // Wait for previous values so new rows can be pre-filled.
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => _setRows(const [], unit),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddSet,
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setRows(List<SessionSet> previous, UnitSystem unit) {
    final trackingType =
        sessionExercise.exercise?.trackingType ?? 'weight_reps';
    return Column(
      children: [
        for (var i = 0; i < sets.length; i++)
          _SetRow(
            key: ValueKey('set-${sets[i].id}'),
            set: sets[i],
            trackingType: trackingType,
            unit: unit,
            previous: i < previous.length ? previous[i] : null,
            onComplete: onCompleteSet,
          ),
      ],
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.trackingType,
    required this.unit,
    required this.previous,
    required this.onComplete,
  });

  final SessionSet set;
  final String trackingType;
  final UnitSystem unit;
  final SessionSet? previous;
  final CompleteSetCallback onComplete;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  late final TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    final set = widget.set;
    final previous = widget.previous;
    final weightKg = set.weightKg ?? previous?.weightKg;
    _weightController = TextEditingController(
      text: _formatWeight(
        weightKg == null ? null : widget.unit.toDisplay(weightKg),
      ),
    );
    _repsController = TextEditingController(
      text: _formatInt(set.reps ?? previous?.reps),
    );
    _durationController = TextEditingController(
      text: _formatInt(set.durationSeconds ?? previous?.durationSeconds),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  double? get _weightDisplay {
    final raw = _weightController.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  int? get _reps => _parseInt(_repsController.text);
  int? get _duration => _parseInt(_durationController.text);

  void _complete() {
    final trackingType = widget.trackingType;
    final display = _weightDisplay;
    widget.onComplete(
      widget.set.id!,
      weightKg: trackingType == 'weight_reps' && display != null
          ? widget.unit.toStorage(display)
          : null,
      reps: trackingType == 'duration' ? null : _reps,
      durationSeconds: trackingType == 'duration' ? _duration : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = widget.set.isCompleted;
    final trackingType = widget.trackingType;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${widget.set.setNumber}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (trackingType == 'weight_reps') ...[
            Expanded(
              child: _input(
                _weightController,
                widget.unit.weightLabel,
                decimal: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _input(_repsController, 'reps')),
          ] else if (trackingType == 'duration')
            Expanded(child: _input(_durationController, 'seconds'))
          else
            Expanded(child: _input(_repsController, 'reps')),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _complete,
            tooltip: 'Complete set',
            icon: Icon(
              completed ? Icons.check_circle : Icons.check_circle_outline,
              color: completed
                  ? Colors.green
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

Widget _summaryRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}

String _previousText(
  List<SessionSet> previous,
  String trackingType,
  UnitSystem unit,
) {
  if (previous.isEmpty) return 'No previous data';
  final parts = previous.map((set) {
    if (trackingType == 'duration') return '${set.durationSeconds ?? 0}s';
    if (trackingType == 'reps_only') return '${set.reps ?? 0} reps';
    final weight = set.weightKg;
    final weightLabel = weight == null
        ? 'BW'
        : '${_formatWeight(unit.toDisplay(weight))}${unit.weightLabel}';
    return '$weightLabel × ${set.reps ?? 0}';
  });
  return 'Previous: ${parts.join(', ')}';
}

String _formatInt(int? value) => value == null ? '' : '$value';

String _formatWeight(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

int? _parseInt(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}
