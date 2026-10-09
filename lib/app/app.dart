import 'package:fitlog/app/router.dart';
import 'package:fitlog/app/theme.dart';
import 'package:fitlog/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: wires the Material 3 themes and the go_router configuration.
class FitLogApp extends ConsumerWidget {
  const FitLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'FitLog',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: settings.themeMode.toThemeMode(),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
