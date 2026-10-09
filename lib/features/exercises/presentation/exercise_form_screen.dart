import 'package:fitlog/core/utils/formatters.dart';
import 'package:fitlog/features/exercises/data/exercise_repository.dart';
import 'package:fitlog/features/exercises/domain/exercise.dart';
import 'package:fitlog/features/exercises/domain/exercise_options.dart';
import 'package:fitlog/features/exercises/presentation/exercise_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Simple form for creating a custom exercise.
class ExerciseFormScreen extends ConsumerStatefulWidget {
  const ExerciseFormScreen({super.key});

  @override
  ConsumerState<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends ConsumerState<ExerciseFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String _muscle = kMuscleGroups.first;
  String _equipment = kEquipmentTypes.first;
  String _environment = kEnvironments.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(exerciseRepositoryProvider)
          .insertCustom(
            Exercise(
              name: _nameController.text.trim(),
              primaryMuscle: _muscle,
              equipment: _equipment,
              environment: _environment,
              trackingType: 'weight_reps',
            ),
          );
      // Refresh every cached exercise list, then return to it.
      ref.invalidate(exercisesProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save exercise: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Exercise')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a name'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _muscle,
              decoration: const InputDecoration(
                labelText: 'Muscle group',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final muscle in kMuscleGroups)
                  DropdownMenuItem(value: muscle, child: Text(humanize(muscle))),
              ],
              onChanged: (value) =>
                  setState(() => _muscle = value ?? _muscle),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _equipment,
              decoration: const InputDecoration(
                labelText: 'Equipment',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final equipment in kEquipmentTypes)
                  DropdownMenuItem(
                    value: equipment,
                    child: Text(humanize(equipment)),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _equipment = value ?? _equipment),
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
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save exercise'),
            ),
          ],
        ),
      ),
    );
  }
}
