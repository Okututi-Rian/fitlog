import 'package:fitlog/app/app.dart';
import 'package:fitlog/core/database/app_database.dart';
import 'package:fitlog/core/database/database_provider.dart';
import 'package:fitlog/core/database/seeder.dart';
import 'package:fitlog/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the database and load built-in seed data before the first frame.
  final database = await AppDatabase().open();
  await Seeder(database).seed();

  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(AsyncValue.data(database))],
  );
  // Load settings up front so the router knows whether to show onboarding.
  await container.read(settingsProvider.notifier).load();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FitLogApp(),
    ),
  );
}
