import 'package:fitlog/core/utils/formatters.dart';
import 'package:fitlog/core/widgets/error_view.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:fitlog/features/progress/data/body_weight_repository.dart';
import 'package:fitlog/features/progress/domain/body_weight_entry.dart';
import 'package:fitlog/features/progress/domain/progress_models.dart';
import 'package:fitlog/features/progress/presentation/progress_providers.dart';
import 'package:fitlog/features/settings/domain/app_settings.dart';
import 'package:fitlog/features/settings/presentation/settings_providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Track progress: estimated 1RM per exercise, personal records, and a
/// body-weight log (docs/ARCHITECTURE.md Journey E, section 9.6).
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int? _exerciseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = ref.watch(unitSystemProvider);
    final exercises = ref.watch(allExercisesProvider);
    final progress = _exerciseId == null
        ? null
        : ref.watch(exerciseProgressProvider(_exerciseId!));
    final bodyWeight = ref.watch(bodyWeightProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          exercises.when(
            data: (items) => DropdownButtonFormField<int>(
              initialValue: _exerciseId,
              decoration: const InputDecoration(
                labelText: 'Exercise',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final exercise in items)
                  DropdownMenuItem(
                    value: exercise.id,
                    child: Text(exercise.name),
                  ),
              ],
              onChanged: (value) => setState(() => _exerciseId = value),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(allExercisesProvider),
            ),
          ),
          const SizedBox(height: 16),
          if (progress == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Pick an exercise to see your progress.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            progress.when(
              data: (data) => Column(
                children: [
                  _ChartCard(points: data.points, unit: unit),
                  const SizedBox(height: 16),
                  _RecordsCard(records: data.records, unit: unit),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorView(
                message: '$error',
                onRetry: () =>
                    ref.invalidate(exerciseProgressProvider(_exerciseId!)),
              ),
            ),
          const Divider(height: 32),
          Row(
            children: [
              Text('Body weight', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addBodyWeight(unit),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          bodyWeight.when(
            data: (entries) => entries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No entries yet.'),
                  )
                : Column(
                    children: [
                      for (final entry in entries)
                        _BodyWeightTile(entry: entry, unit: unit),
                    ],
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(bodyWeightProvider),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addBodyWeight(UnitSystem unit) async {
    final result = await showDialog<({double weightKg, DateTime date})>(
      context: context,
      builder: (_) => _AddBodyWeightDialog(unit: unit),
    );
    if (result == null) return;
    await ref
        .read(bodyWeightRepositoryProvider)
        .add(result.weightKg, result.date);
    ref.invalidate(bodyWeightProvider);
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.points, required this.unit});

  final List<ProgressPoint> points;
  final UnitSystem unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estimated 1RM', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (points.length < 2)
              SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    points.isEmpty
                        ? 'No completed weighted sets yet.'
                        : 'Log another session to see a trend.',
                  ),
                ),
              )
            else
              SizedBox(height: 200, child: LineChart(_chartData(context))),
          ],
        ),
      ),
    );
  }

  LineChartData _chartData(BuildContext context) {
    final theme = Theme.of(context);
    final values = [
      for (final point in points) unit.toDisplay(point.estimatedOneRepMax),
    ];
    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    final span = (highest - lowest).abs();
    final padding = span < 1 ? 1.0 : span * 0.1;
    final minY = (lowest - padding).clamp(0.0, double.infinity);
    final maxY = highest + padding;
    final step = (points.length / 4).ceil();

    return LineChartData(
      minX: 0,
      maxX: (points.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < points.length; i++)
              FlSpot(
                i.toDouble(),
                unit.toDisplay(points[i].estimatedOneRepMax),
              ),
          ],
          isCurved: true,
          barWidth: 3,
          color: theme.colorScheme.primary,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
      ],
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final index = value.round();
              if (index < 0 || index >= points.length) {
                return const SizedBox.shrink();
              }
              if (index % step != 0 && index != points.length - 1) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('MMM d').format(points[index].date),
                  style: theme.textTheme.bodySmall,
                ),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: theme.colorScheme.outlineVariant, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard({required this.records, required this.unit});

  final PersonalRecords records;
  final UnitSystem unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal records', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (records.isEmpty)
              const Text('No records yet.')
            else ...[
              _recordRow(
                context,
                'Heaviest weight',
                records.heaviestWeightKg == null
                    ? '—'
                    : '${formatWeight(unit.toDisplay(records.heaviestWeightKg!))} '
                          '${unit.weightLabel}',
                records.heaviestWeightDate,
              ),
              _recordRow(
                context,
                'Best e1RM',
                records.bestE1rm == null
                    ? '—'
                    : '${formatWeight(unit.toDisplay(records.bestE1rm!))} '
                          '${unit.weightLabel}',
                records.bestE1rmDate,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recordRow(
    BuildContext context,
    String label,
    String value,
    DateTime? date,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (date != null)
                Text(
                  DateFormat.yMMMd().format(date),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BodyWeightTile extends StatelessWidget {
  const _BodyWeightTile({required this.entry, required this.unit});

  final BodyWeightEntry entry;
  final UnitSystem unit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${formatWeight(unit.toDisplay(entry.weightKg))} ${unit.weightLabel}',
      ),
      trailing: Text(DateFormat.yMMMd().format(entry.loggedAt.toLocal())),
    );
  }
}

class _AddBodyWeightDialog extends StatefulWidget {
  const _AddBodyWeightDialog({required this.unit});

  final UnitSystem unit;

  @override
  State<_AddBodyWeightDialog> createState() => _AddBodyWeightDialogState();
}

class _AddBodyWeightDialogState extends State<_AddBodyWeightDialog> {
  final TextEditingController _weightController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final display = parseDoubleOrNull(_weightController.text);
    if (display == null || display <= 0) return;
    Navigator.of(
      context,
    ).pop((weightKg: widget.unit.toStorage(display), date: _date));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log body weight'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _weightController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Weight (${widget.unit.weightLabel})',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(DateFormat.yMMMd().format(_date)),
              const Spacer(),
              TextButton(
                onPressed: _pickDate,
                child: const Text('Change date'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
