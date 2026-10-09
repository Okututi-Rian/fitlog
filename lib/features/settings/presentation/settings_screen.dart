import 'package:fitlog/features/settings/data/export_service.dart';
import 'package:fitlog/features/settings/domain/app_settings.dart';
import 'package:fitlog/features/settings/presentation/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Settings: units, theme, week start, CSV export and the health disclaimer.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await ref.read(exportServiceProvider).exportAndShare();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle(context, 'Units'),
          SegmentedButton<UnitSystem>(
            segments: const [
              ButtonSegment(value: UnitSystem.metric, label: Text('kg')),
              ButtonSegment(value: UnitSystem.imperial, label: Text('lb')),
            ],
            selected: {settings.unitSystem},
            onSelectionChanged: (selection) =>
                controller.setUnitSystem(selection.first),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Theme'),
          SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(value: AppThemeMode.system, label: Text('System')),
              ButtonSegment(value: AppThemeMode.light, label: Text('Light')),
              ButtonSegment(value: AppThemeMode.dark, label: Text('Dark')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) =>
                controller.setThemeMode(selection.first),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Week starts on'),
          SegmentedButton<WeekStart>(
            segments: const [
              ButtonSegment(value: WeekStart.monday, label: Text('Monday')),
              ButtonSegment(value: WeekStart.sunday, label: Text('Sunday')),
            ],
            selected: {settings.weekStart},
            onSelectionChanged: (selection) =>
                controller.setWeekStart(selection.first),
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Data'),
          OutlinedButton.icon(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: const Text('Export to CSV'),
          ),
          const SizedBox(height: 32),
          Text(
            'FitLog is not medical advice. Exercise instructions are general '
            'guidance only — consult a qualified professional before starting '
            'a new exercise programme.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
