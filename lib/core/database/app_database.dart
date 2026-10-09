import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

/// Owns the SQLite connection for FitLog.
///
/// The database file lives in the app's private storage. Weights are always
/// stored in kilograms and times as UTC epoch milliseconds (see
/// docs/ARCHITECTURE.md section 6).
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      // Named parameters cannot start with an underscore, so a private field
      // cannot be assigned through an initializing formal.
      // ignore: prefer_initializing_formals
      _path = path;

  /// The current schema version. Bump this when adding a migration.
  static const int schemaVersion = 1;

  /// File name of the on-device database.
  static const String fileName = 'fitlog.db';

  final DatabaseFactory _factory;
  final String? _path;

  /// Opens (and creates, on first run) the database.
  Future<Database> open() async {
    final path =
        _path ?? p.join(await _factory.getDatabasesPath(), fileName);
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  /// Runs every time a connection opens. SQLite ignores foreign keys unless
  /// they are switched on per connection (a classic gotcha).
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Runs once on a fresh install: creates every table and index.
  Future<void> _onCreate(Database db, int version) async {
    for (final statement in _schema) {
      await db.execute(statement);
    }
  }

  /// Runs when an existing install is upgraded to a higher schema version.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await runMigrations(db, oldVersion, newVersion);
  }
}

/// The full initial schema (docs/ARCHITECTURE.md section 6.2).
const List<String> _schema = [
  // exercises -----------------------------------------------------------------
  '''
  CREATE TABLE exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT UNIQUE,
    name TEXT NOT NULL,
    primary_muscle TEXT NOT NULL,
    secondary_muscles TEXT,
    equipment TEXT NOT NULL,
    environment TEXT NOT NULL,
    tracking_type TEXT NOT NULL,
    instructions TEXT,
    is_custom INTEGER NOT NULL DEFAULT 0,
    is_archived INTEGER NOT NULL DEFAULT 0
  )
  ''',

  // workout_templates ---------------------------------------------------------
  '''
  CREATE TABLE workout_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    environment TEXT NOT NULL,
    is_prebuilt INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER,
    updated_at INTEGER
  )
  ''',

  // template_exercises --------------------------------------------------------
  '''
  CREATE TABLE template_exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER NOT NULL
      REFERENCES workout_templates (id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL REFERENCES exercises (id),
    position INTEGER NOT NULL,
    target_sets INTEGER,
    target_reps_min INTEGER,
    target_reps_max INTEGER,
    rest_seconds INTEGER,
    notes TEXT
  )
  ''',

  // workout_sessions ----------------------------------------------------------
  '''
  CREATE TABLE workout_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER REFERENCES workout_templates (id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    environment TEXT,
    started_at INTEGER NOT NULL,
    ended_at INTEGER,
    notes TEXT
  )
  ''',

  // session_exercises ---------------------------------------------------------
  '''
  CREATE TABLE session_exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id INTEGER NOT NULL
      REFERENCES workout_sessions (id) ON DELETE CASCADE,
    exercise_id INTEGER NOT NULL REFERENCES exercises (id),
    position INTEGER NOT NULL,
    rest_seconds INTEGER,
    notes TEXT
  )
  ''',

  // session_sets --------------------------------------------------------------
  '''
  CREATE TABLE session_sets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_exercise_id INTEGER NOT NULL
      REFERENCES session_exercises (id) ON DELETE CASCADE,
    set_number INTEGER NOT NULL,
    weight_kg REAL,
    reps INTEGER,
    duration_seconds INTEGER,
    is_warmup INTEGER NOT NULL DEFAULT 0,
    is_completed INTEGER NOT NULL DEFAULT 0,
    completed_at INTEGER
  )
  ''',

  // body_weight_entries -------------------------------------------------------
  '''
  CREATE TABLE body_weight_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    weight_kg REAL NOT NULL,
    logged_at INTEGER NOT NULL
  )
  ''',

  // user_settings -------------------------------------------------------------
  '''
  CREATE TABLE user_settings (
    key TEXT PRIMARY KEY,
    value TEXT
  )
  ''',

  // indexes -------------------------------------------------------------------
  'CREATE INDEX idx_exercises_primary_muscle ON exercises (primary_muscle)',
  'CREATE INDEX idx_template_exercises_template_id ON template_exercises (template_id)',
  'CREATE INDEX idx_session_exercises_session_id ON session_exercises (session_id)',
  'CREATE INDEX idx_session_exercises_exercise_id ON session_exercises (exercise_id)',
  'CREATE INDEX idx_session_sets_session_exercise_id ON session_sets (session_exercise_id)',
  'CREATE INDEX idx_workout_sessions_started_at ON workout_sessions (started_at)',
];
