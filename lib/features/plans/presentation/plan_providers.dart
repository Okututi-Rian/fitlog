import 'package:fitlog/features/plans/data/template_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// All plans (built-in and user-created) with their exercise counts.
final templatesProvider = FutureProvider<List<TemplateSummary>>((ref) {
  return ref.watch(templateRepositoryProvider).getAllWithCounts();
});

/// A single plan with its ordered exercises.
final templateDetailProvider =
    FutureProvider.family<TemplateWithExercises?, int>((ref, id) {
      return ref.watch(templateRepositoryProvider).getById(id);
    });
