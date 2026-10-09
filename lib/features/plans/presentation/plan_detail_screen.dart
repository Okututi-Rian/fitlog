import 'package:fitlog/app/routes.dart';
import 'package:fitlog/core/utils/formatters.dart';
import 'package:fitlog/core/widgets/empty_state.dart';
import 'package:fitlog/core/widgets/error_view.dart';
import 'package:fitlog/features/plans/data/template_repository.dart';
import 'package:fitlog/features/plans/domain/template_exercise.dart';
import 'package:fitlog/features/plans/presentation/plan_providers.dart';
import 'package:fitlog/features/session/presentation/session_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shows a plan's ordered exercises and targets, with actions to start it,
/// edit it (user plans) or duplicate it (built-in plans).
class PlanDetailScreen extends ConsumerWidget {
  const PlanDetailScreen({super.key, required this.templateId});

  final int templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(templateDetailProvider(templateId));
    final data = detail.value;

    return Scaffold(
      appBar: AppBar(title: Text(data?.template.name ?? 'Plan')),
      body: detail.when(
        data: (value) => value == null
            ? const EmptyState(
                icon: Icons.error_outline,
                title: 'Plan not found',
              )
            : _PlanDetails(detail: value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(templateDetailProvider(templateId)),
        ),
      ),
      bottomNavigationBar: data == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: () => _start(context, ref),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start workout'),
                ),
              ),
            ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final session = await startWorkoutFromTemplate(ref, templateId);
    if (context.mounted) context.push(AppRoutes.activeSession(session.id!));
  }
}

class _PlanDetails extends StatelessWidget {
  const _PlanDetails({required this.detail});

  final TemplateWithExercises detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final template = detail.template;
    final description = template.description?.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(template.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(humanize(template.environment))),
            if (template.isPrebuilt)
              const Chip(
                label: Text('Built-in'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(description),
        ],
        const SizedBox(height: 24),
        Text('Exercises', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        if (detail.exercises.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('This plan has no exercises yet.'),
          )
        else
          for (var i = 0; i < detail.exercises.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(
                detail.exercises[i].exercise?.name ?? 'Unknown exercise',
              ),
              subtitle: Text(_targetLabel(detail.exercises[i])),
              trailing: detail.exercises[i].restSeconds == null
                  ? null
                  : Text('${detail.exercises[i].restSeconds}s rest'),
            ),
        const SizedBox(height: 16),
        if (template.isPrebuilt)
          OutlinedButton.icon(
            onPressed: () =>
                context.push(AppRoutes.duplicatePlan(template.id!)),
            icon: const Icon(Icons.copy),
            label: const Text('Duplicate to edit'),
          )
        else
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.editPlan(template.id!)),
            icon: const Icon(Icons.edit),
            label: const Text('Edit plan'),
          ),
      ],
    );
  }
}

String _targetLabel(TemplateExercise exercise) {
  final unit = exercise.exercise?.trackingType == 'duration' ? 'sec' : 'reps';
  final sets = exercise.targetSets;
  final min = exercise.targetRepsMin;
  final max = exercise.targetRepsMax;

  final setsLabel = sets == null ? '' : '$sets sets';
  var repsLabel = '';
  if (min != null || max != null) {
    repsLabel = (min != null && max != null && min != max)
        ? '$min–$max $unit'
        : '${min ?? max} $unit';
  }

  if (setsLabel.isEmpty) return repsLabel.isEmpty ? 'No targets set' : repsLabel;
  if (repsLabel.isEmpty) return setsLabel;
  return '$setsLabel × $repsLabel';
}
