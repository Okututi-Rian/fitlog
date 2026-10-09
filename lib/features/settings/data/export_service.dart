import 'dart:convert';
import 'dart:typed_data';

import 'package:fitlog/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

/// Builds a CSV of the user's workout history and hands it to the Android
/// share sheet (docs/ARCHITECTURE.md section 12).
class ExportService {
  ExportService(this._database);

  final Future<Database> _database;

  Future<String> buildCsv() async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT ws.id AS session_id, ws.name AS session_name, ws.started_at,
             e.name AS exercise_name, ss.set_number, ss.weight_kg, ss.reps,
             ss.duration_seconds, ss.is_warmup
      FROM session_sets ss
      JOIN session_exercises se ON se.id = ss.session_exercise_id
      JOIN workout_sessions ws ON ws.id = se.session_id
      JOIN exercises e ON e.id = se.exercise_id
      WHERE ws.ended_at IS NOT NULL
      ORDER BY ws.started_at, se.position, ss.set_number
    ''');

    final buffer = StringBuffer()
      ..writeln(
        'session_id,date,session_name,exercise,set_number,'
        'weight_kg,reps,duration_seconds,is_warmup',
      );
    for (final row in rows) {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(
        (row['started_at'] as num).toInt(),
        isUtc: true,
      ).toIso8601String();
      buffer.writeln(
        [
          row['session_id'],
          startedAt,
          _escape(row['session_name'] as String?),
          _escape(row['exercise_name'] as String?),
          row['set_number'],
          row['weight_kg'] ?? '',
          row['reps'] ?? '',
          row['duration_seconds'] ?? '',
          row['is_warmup'],
        ].join(','),
      );
    }
    return buffer.toString();
  }

  Future<void> exportAndShare() async {
    final csv = await buildCsv();
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final file = XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: 'fitlog_export.csv',
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], subject: 'FitLog export'),
    );
  }
}

String _escape(String? value) {
  if (value == null) return '';
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(ref.watch(databaseProvider.future)),
);
