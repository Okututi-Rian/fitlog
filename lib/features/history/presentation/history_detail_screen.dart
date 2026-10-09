import 'package:fitlog/core/utils/formatters.dart';
import 'package:fitlog/core/widgets/empty_state.dart';
import 'package:fitlog/core/widgets/error_view.dart';
import 'package:fitlog/features/history/presentation/history_providers.dart';
import 'package:fitlog/features/progress/presentation/progress_providers.dart';
import 'package:fitlog/features/session/data/session_repository.dart';
import 'package:fitlog/features/session/domain/session_set.dart';
import 'package:fitlog/features/session/domain/workout_math.dart';
import 'package:fitlog/features/session/presentation/session_providers.dart';
import 'package:fitlog/features/settings/domain/app_settings.dart';
import 'package:fitlog/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// A finished workout: every exercise and set, editable inline, deletable
/// (docs/ARCHITECTURE.md Journey D).
class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(sessionDetailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.session.name ?? 'Workout'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete workout',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: detail.when(
        data: (value) => value == null
            ? const EmptyState(
                icon: Icons.error_outline,
                title: 'Workout not found',
              )
            : _HistoryDetails(detail: value, sessionId: sessionId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(sessionDetailProvider(sessionId)),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('This workout will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(sessionRepositoryProvider).discard(sessionId);
    ref.invalidate(historyProvider);
    ref.invalidate(workoutStatsProvider);
    ref.invalidate(exerciseProgressProvider);
    if (context.mounted) context.pop();
  }
}

class _HistoryDetails extends ConsumerWidget {
  const _HistoryDetails({required this.detail, required this.sessionId});

  final SessionDetail detail;
  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unit = ref.watch(unitSystemProvider);
    final session = detail.session;
    final duration = session.endedAt?.difference(session.startedAt);
    final sets = [
      for (final entry in detail.exercises) ...entry.sets,
    ];
    final volume = unit.toDisplay(totalVolume(sets));
    final header = [
      DateFormat.yMMMd().add_jm().format(session.startedAt.toLocal()),
      if (duration != null) formatDuration(duration),
      '${sets.length} sets',
      '${volume.toStringAsFixed(0)} ${unit.weightLabel} volume',
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          header,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final entry in detail.exercises) ...[
          Text(
            entry.sessionExercise.exercise?.name ?? 'Exercise',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          for (final set in entry.sets)
            _EditableHistorySet(
              key: ValueKey('history-set-${set.id}'),
              set: set,
              trackingType:
                  entry.sessionExercise.exercise?.trackingType ?? 'weight_reps',
              sessionId: sessionId,
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _EditableHistorySet extends ConsumerStatefulWidget {
  const _EditableHistorySet({
    super.key,
    required this.set,
    required this.trackingType,
    required this.sessionId,
  });

  final SessionSet set;
  final String trackingType;
  final int sessionId;

  @override
  ConsumerState<_EditableHistorySet> createState() =>
      _EditableHistorySetState();
}

class _EditableHistorySetState extends ConsumerState<_EditableHistorySet> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  late final TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    final unit = ref.read(unitSystemProvider);
    final set = widget.set;
    _weightController = TextEditingController(
      text: set.weightKg == null
          ? ''
          : formatWeight(unit.toDisplay(set.weightKg!)),
    );
    _repsController = TextEditingController(text: set.reps?.toString() ?? '');
    _durationController = TextEditingController(
      text: set.durationSeconds?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trackingType = widget.trackingType;
    final unit = ref.read(unitSystemProvider);
    final display = parseDoubleOrNull(_weightController.text);
    await ref
        .read(sessionRepositoryProvider)
        .updateSet(
          widget.set.id!,
          weightKg: trackingType == 'weight_reps' && display != null
              ? unit.toStorage(display)
              : null,
          reps: trackingType == 'duration'
              ? null
              : parseIntOrNull(_repsController.text),
          durationSeconds: trackingType == 'duration'
              ? parseIntOrNull(_durationController.text)
              : null,
        );
    ref.invalidate(sessionDetailProvider(widget.sessionId));
    ref.invalidate(historyProvider);
    ref.invalidate(exerciseProgressProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set updated')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = ref.watch(unitSystemProvider);
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
              child: _field(
                _weightController,
                unit.weightLabel,
                decimal: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _field(_repsController, 'reps')),
          ] else if (trackingType == 'duration')
            Expanded(child: _field(_durationController, 'seconds'))
          else
            Expanded(child: _field(_repsController, 'reps')),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Save set',
            onPressed: _save,
          ),
        ],
      ),
    );
  }

  Widget _field(
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
