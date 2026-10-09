import 'package:fitlog/app/routes.dart';
import 'package:fitlog/core/utils/formatters.dart';
import 'package:fitlog/core/widgets/empty_state.dart';
import 'package:fitlog/core/widgets/error_view.dart';
import 'package:fitlog/features/history/presentation/history_providers.dart';
import 'package:fitlog/features/session/data/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Finished workouts, newest first (docs/ARCHITECTURE.md Journey D).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: history.when(
        data: (items) => items.isEmpty
            ? const EmptyState(
                icon: Icons.history,
                title: 'No workouts yet',
                message: 'Finish a workout and it will appear here.',
              )
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) =>
                    _HistoryTile(summary: items[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(historyProvider),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final session = summary.session;
    final duration = session.endedAt?.difference(session.startedAt);
    final subtitle = [
      DateFormat.yMMMd().add_jm().format(session.startedAt.toLocal()),
      if (duration != null) formatDuration(duration),
    ].join(' · ');

    return ListTile(
      title: Text(session.name),
      subtitle: Text(subtitle),
      trailing: Text('${summary.setCount} sets'),
      onTap: () => context.push(AppRoutes.historyDetail(session.id!)),
    );
  }
}
