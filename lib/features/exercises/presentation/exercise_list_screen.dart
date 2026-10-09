import 'package:fitlog/app/routes.dart';
import 'package:fitlog/core/utils/formatters.dart';
import 'package:fitlog/core/widgets/empty_state.dart';
import 'package:fitlog/core/widgets/error_view.dart';
import 'package:fitlog/features/exercises/domain/exercise.dart';
import 'package:fitlog/features/exercises/domain/exercise_filter.dart';
import 'package:fitlog/features/exercises/domain/exercise_options.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Searchable, filterable list of exercises.
///
/// Embedded in the Plans tab's "Exercise Library" segment and reused wherever
/// the library is shown (docs/ARCHITECTURE.md section 8).
class ExerciseListScreen extends ConsumerStatefulWidget {
  const ExerciseListScreen({
    super.key,
    this.selectionMode = false,
    this.title,
  });

  /// When true, tapping a row returns the exercise to the caller instead of
  /// opening its detail (used by the plan editor's exercise picker).
  final bool selectionMode;

  /// Optional app bar title. Null when embedded in another screen's scaffold.
  final String? title;

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _environment;
  String? _muscle;

  ExerciseFilter get _filter {
    final search = _searchController.text.trim();
    return ExerciseFilter(
      environment: _environment,
      muscle: _muscle,
      search: search.isEmpty ? null : search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openExercise(Exercise exercise) {
    if (widget.selectionMode) {
      context.pop(exercise);
    } else if (exercise.id != null) {
      context.push(AppRoutes.exerciseDetail(exercise.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    final exercises = ref.watch(exercisesProvider(filter));

    return Scaffold(
      appBar: widget.title == null ? null : AppBar(title: Text(widget.title!)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search exercises',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _FilterChipRow(
            values: kEnvironments,
            selected: _environment,
            onSelected: (value) => setState(() => _environment = value),
          ),
          _FilterChipRow(
            values: kMuscleGroups,
            selected: _muscle,
            onSelected: (value) => setState(() => _muscle = value),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: exercises.when(
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      title: 'No exercises found',
                      message:
                          'Try a different search or filter, or add a custom exercise.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: items.length,
                      itemBuilder: (context, index) => _ExerciseTile(
                        exercise: items[index],
                        onTap: () => _openExercise(items[index]),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                message: '$error',
                onRetry: () => ref.invalidate(exercisesProvider(filter)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => context.push(AppRoutes.newExercise),
              tooltip: 'Add custom exercise',
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.onTap});

  final Exercise exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(exercise.name),
      subtitle: Text(humanize(exercise.primaryMuscle)),
      trailing: Chip(
        label: Text(humanize(exercise.equipment)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onTap: onTap,
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = values[index];
          return FilterChip(
            label: Text(humanize(value)),
            selected: selected == value,
            onSelected: (isSelected) => onSelected(isSelected ? value : null),
          );
        },
      ),
    );
  }
}
