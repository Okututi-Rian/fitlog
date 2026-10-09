import 'package:fitlog/app/routes.dart';
import 'package:fitlog/core/utils/formatters.dart';
import 'package:fitlog/features/exercises/domain/exercise.dart';
import 'package:fitlog/features/exercises/domain/exercise_options.dart';
import 'package:fitlog/features/plans/data/template_repository.dart';
import 'package:fitlog/features/plans/domain/template_exercise.dart';
import 'package:fitlog/features/plans/domain/workout_template.dart';
import 'package:fitlog/features/plans/presentation/plan_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creates a new plan, edits an existing user plan, or duplicates a built-in
/// plan (Journey C, docs/ARCHITECTURE.md section 7).
///
/// - both [templateId] and [duplicateFromId] null: create a blank plan
/// - [templateId] set: edit that plan
/// - [duplicateFromId] set: copy that plan into a new user plan
class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key, this.templateId, this.duplicateFromId});

  final int? templateId;
  final int? duplicateFromId;

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final List<_EditableExercise> _exercises = [];
  String _environment = 'both';
  bool _loading = true;
  bool _saving = false;

  int? get _sourceId => widget.templateId ?? widget.duplicateFromId;

  @override
  void initState() {
    super.initState();
    if (_sourceId == null) {
      _loading = false;
    } else {
      _loadSource();
    }
  }

  Future<void> _loadSource() async {
    try {
      final detail = await ref.read(templateDetailProvider(_sourceId!).future);
      if (!mounted) return;
      setState(() {
        if (detail != null) {
          _nameController.text = widget.duplicateFromId != null
              ? '${detail.template.name} (copy)'
              : detail.template.name;
          _environment = detail.template.environment;
          _exercises
            ..clear()
            ..addAll(
              detail.exercises
                  .where((exercise) => exercise.exercise != null)
                  .map(
                    (exercise) => _EditableExercise(
                      exercise: exercise.exercise!,
                      targetSets: exercise.targetSets ?? 3,
                      targetRepsMin: exercise.targetRepsMin ?? 8,
                      targetRepsMax: exercise.targetRepsMax ?? 12,
                      restSeconds: exercise.restSeconds ?? 90,
                    ),
                  ),
            );
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final exercise in _exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  Future<void> _addExercise() async {
    final picked = await context.push<Exercise>(AppRoutes.pickExercise);
    if (picked == null || !mounted) return;
    if (_exercises.any((entry) => entry.exercise.id == picked.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That exercise is already in the plan.')),
      );
      return;
    }
    setState(() => _exercises.add(_EditableExercise(exercise: picked)));
  }

  void _move(int from, int to) {
    setState(() {
      final entry = _exercises.removeAt(from);
      _exercises.insert(to, entry);
    });
  }

  void _remove(int index) {
    setState(() => _exercises.removeAt(index).dispose());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise.')),
      );
      return;
    }

    setState(() => _saving = true);
    final template = WorkoutTemplate(
      id: widget.templateId,
      name: _nameController.text.trim(),
      environment: _environment,
      isPrebuilt: false,
    );
    final exercises = [
      for (var i = 0; i < _exercises.length; i++)
        TemplateExercise(
          exerciseId: _exercises[i].exercise.id!,
          position: i + 1,
          targetSets: _exercises[i].targetSets,
          targetRepsMin: _exercises[i].targetRepsMin,
          targetRepsMax: _exercises[i].targetRepsMax,
          restSeconds: _exercises[i].restSeconds,
        ),
    ];

    try {
      final repository = ref.read(templateRepositoryProvider);
      if (widget.templateId == null) {
        await repository.create(template, exercises);
      } else {
        await repository.update(template, exercises);
        ref.invalidate(templateDetailProvider(widget.templateId!));
      }
      ref.invalidate(templatesProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save plan: $error')),
      );
    }
  }

  String get _title {
    if (widget.templateId != null) return 'Edit Plan';
    if (widget.duplicateFromId != null) return 'Duplicate Plan';
    return 'New Plan';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          TextButton(
            onPressed: (_loading || _saving) ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Plan name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter a name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _environment,
                    decoration: const InputDecoration(
                      labelText: 'Environment',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final environment in kEnvironments)
                        DropdownMenuItem(
                          value: environment,
                          child: Text(humanize(environment)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _environment = value ?? _environment),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Exercises',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_exercises.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No exercises yet. Add one from the library below.',
                      ),
                    ),
                  for (var i = 0; i < _exercises.length; i++)
                    _buildExerciseCard(i),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _addExercise,
                    icon: const Icon(Icons.add),
                    label: const Text('Add exercise'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildExerciseCard(int index) {
    final entry = _exercises[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.exercise.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: 'Move up',
                  onPressed: index == 0 ? null : () => _move(index, index - 1),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  tooltip: 'Move down',
                  onPressed: index == _exercises.length - 1
                      ? null
                      : () => _move(index, index + 1),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Remove',
                  onPressed: () => _remove(index),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _numberField(entry.setsController, 'Sets'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(entry.restController, 'Rest (s)'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _numberField(entry.repsMinController, 'Reps min'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numberField(entry.repsMaxController, 'Reps max'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (value) {
        final parsed = int.tryParse(value?.trim() ?? '');
        if (parsed == null || parsed < 0) return 'Required';
        return null;
      },
    );
  }
}

/// Mutable working copy of a template exercise while editing.
class _EditableExercise {
  _EditableExercise({
    required this.exercise,
    int targetSets = 3,
    int targetRepsMin = 8,
    int targetRepsMax = 12,
    int restSeconds = 90,
  }) : setsController = TextEditingController(text: '$targetSets'),
       repsMinController = TextEditingController(text: '$targetRepsMin'),
       repsMaxController = TextEditingController(text: '$targetRepsMax'),
       restController = TextEditingController(text: '$restSeconds');

  final Exercise exercise;
  final TextEditingController setsController;
  final TextEditingController repsMinController;
  final TextEditingController repsMaxController;
  final TextEditingController restController;

  int get targetSets => int.tryParse(setsController.text.trim()) ?? 0;
  int get targetRepsMin => int.tryParse(repsMinController.text.trim()) ?? 0;
  int get targetRepsMax => int.tryParse(repsMaxController.text.trim()) ?? 0;
  int get restSeconds => int.tryParse(restController.text.trim()) ?? 0;

  void dispose() {
    setsController.dispose();
    repsMinController.dispose();
    repsMaxController.dispose();
    restController.dispose();
  }
}
