import 'package:fitlog/core/utils/formatters.dart';
import 'package:fitlog/core/widgets/empty_state.dart';
import 'package:fitlog/core/widgets/error_view.dart';
import 'package:fitlog/features/exercises/domain/exercise.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read-only view of a single exercise's fields.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(exerciseId));

    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      body: exercise.when(
        data: (value) => value == null
            ? const EmptyState(
                icon: Icons.error_outline,
                title: 'Exercise not found',
              )
            : _ExerciseDetails(exercise: value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(exerciseByIdProvider(exerciseId)),
        ),
      ),
    );
  }
}

class _ExerciseDetails extends StatelessWidget {
  const _ExerciseDetails({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final instructions = exercise.instructions?.trim();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(exercise.name, style: theme.textTheme.headlineSmall),
        if (exercise.isCustom) ...[
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.person_outline, size: 18),
            label: const Text('Custom'),
            visualDensity: VisualDensity.compact,
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(label: Text(humanize(exercise.primaryMuscle))),
            Chip(label: Text(humanize(exercise.equipment))),
            Chip(label: Text(humanize(exercise.environment))),
            Chip(label: Text(humanize(exercise.trackingType))),
          ],
        ),
        const SizedBox(height: 24),
        if (exercise.secondaryMuscles != null &&
            exercise.secondaryMuscles!.trim().isNotEmpty) ...[
          Text('Secondary muscles', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(humanize(exercise.secondaryMuscles!)),
          const SizedBox(height: 16),
        ],
        Text('Instructions', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          instructions == null || instructions.isEmpty
              ? 'No instructions provided.'
              : instructions,
        ),
      ],
    );
  }
}
