import 'package:fitlog/core/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes the `user_settings` key/value table.
class SettingsRepository {
  SettingsRepository(this._database);

  final Future<Database> _database;

  Future<String?> get(String key) async {
    final db = await _database;
    final rows = await db.query(
      'user_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await _database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Every stored setting as a key/value map.
  Future<Map<String, String>> getAll() async {
    final db = await _database;
    final rows = await db.query('user_settings');
    return {
      for (final row in rows)
        row['key'] as String: (row['value'] as String?) ?? '',
    };
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider.future)),
);
