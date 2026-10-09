import 'package:fitlog/app/routes.dart';
import 'package:fitlog/core/widgets/empty_state.dart';
import 'package:fitlog/core/widgets/error_view.dart';
import 'package:fitlog/features/plans/data/template_repository.dart';
import 'package:fitlog/features/plans/presentation/plan_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Lists built-in and user-created plans with their exercise counts.
///
/// Shown in the Plans tab's "My Plans" segment (docs/ARCHITECTURE.md section 8).
class PlansListScreen extends ConsumerWidget {
  const PlansListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(templatesProvider);

    return Scaffold(
      body: plans.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No plans yet',
              message: 'Tap "New plan" to build your first workout.',
            );
          }
          final builtIn = items
              .where((summary) => summary.template.isPrebuilt)
              .toList();
          final mine = items
              .where((summary) => !summary.template.isPrebuilt)
              .toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (builtIn.isNotEmpty)
                ..._section(context, 'Built-in', builtIn),
              if (mine.isNotEmpty) ..._section(context, 'My Plans', mine),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(templatesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newPlan),
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
      ),
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    List<TemplateSummary> plans,
  ) {
    final theme = Theme.of(context);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title, style: theme.textTheme.titleSmall),
      ),
      for (final summary in plans)
        ListTile(
          title: Text(summary.template.name),
          subtitle: Text(
            '${summary.exerciseCount} '
            '${summary.exerciseCount == 1 ? 'exercise' : 'exercises'}',
          ),
          trailing: summary.template.isPrebuilt
              ? const Chip(
                  label: Text('Built-in'),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )
              : const Icon(Icons.chevron_right),
          onTap: () =>
              context.push(AppRoutes.planDetail(summary.template.id!)),
        ),
    ];
  }
}
