import 'package:fitlog/features/session/data/session_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Finished workouts with their set count and volume, newest first.
final historyProvider = FutureProvider<List<SessionSummary>>((ref) {
  return ref.watch(sessionRepositoryProvider).getHistorySummaries();
});
