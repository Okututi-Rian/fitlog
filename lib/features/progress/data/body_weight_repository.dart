import 'package:fitlog/core/database/database_provider.dart';
import 'package:fitlog/features/progress/domain/body_weight_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes the `body_weight_entries` table. Weights are in kilograms.
class BodyWeightRepository {
  BodyWeightRepository(this._database);

  final Future<Database> _database;

  /// All entries, newest first.
  Future<List<BodyWeightEntry>> getAll() async {
    final db = await _database;
    final rows = await db.query(
      'body_weight_entries',
      orderBy: 'logged_at DESC',
    );
    return rows.map(BodyWeightEntry.fromMap).toList();
  }

  Future<BodyWeightEntry> add(double weightKg, DateTime loggedAt) async {
    final db = await _database;
    final utc = loggedAt.toUtc();
    final id = await db.insert('body_weight_entries', {
      'weight_kg': weightKg,
      'logged_at': utc.millisecondsSinceEpoch,
    });
    return BodyWeightEntry(id: id, weightKg: weightKg, loggedAt: utc);
  }
}

final bodyWeightRepositoryProvider = Provider<BodyWeightRepository>(
  (ref) => BodyWeightRepository(ref.watch(databaseProvider.future)),
);
