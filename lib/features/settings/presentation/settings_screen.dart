import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/backup.dart';
import 'package:tokri/core/db/seed.dart';
import 'package:tokri/core/providers/database_provider.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/core/utils/share_codec.dart' show ImportException;
import 'package:tokri/features/lists/data/list_repository.dart';

/// Settings (PLAN §3, trimmed by M4): appearance, behavior, data.
/// Dynamic color + global accent are deferred to M5 — the warm-bazaar
/// theme is the brand until Saad says otherwise.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final json = await exportBackup(ref.read(databaseProvider));
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().toIso8601String().split('T').first;
    final file = File(p.join(dir.path, 'tokri-backup-$stamp.json'));
    await file.writeAsString(json);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
    );
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    const jsonType = XTypeGroup(label: 'Tokri backup', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: const [jsonType]);
    if (file == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace everything?'),
        content: const Text(
          'Importing a backup replaces all current lists, items, and '
          'history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await importBackup(ref.read(databaseProvider), await file.readAsString());
      if (context.mounted) _toast(context, 'Backup restored.');
    } on ImportException catch (e) {
      if (context.mounted) _toast(context, e.message);
    }
  }

  Future<void> _clearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
          'Every list, item, and trip will be deleted. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await clearAllData(ref.read(databaseProvider));
    await ref.read(settingsProvider.notifier).setDefaultListId(null);
    if (context.mounted) _toast(context, 'All data cleared.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final lists = ref.watch(activeListsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gaps.xl),
        children: [
          const _SectionHeader('Appearance'),
          RadioGroup<ThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (mode) {
              if (mode != null) notifier.setThemeMode(mode);
            },
            child: const Column(
              children: [
                RadioListTile(
                  value: ThemeMode.system,
                  title: Text('Follow system'),
                ),
                RadioListTile(value: ThemeMode.light, title: Text('Light')),
                RadioListTile(value: ThemeMode.dark, title: Text('Dark')),
              ],
            ),
          ),
          const _SectionHeader('Behavior'),
          ListTile(
            leading: const Icon(LucideIcons.listChecks),
            title: const Text('Open on launch'),
            subtitle: Text(
              settings.defaultListId == null
                  ? 'Home (all lists)'
                  : lists
                          .where((l) => l.id == settings.defaultListId)
                          .map((l) => l.name)
                          .firstOrNull ??
                      'Home (all lists)',
            ),
            onTap: () async {
              final choice = await showDialog<int?>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Open on launch'),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.of(context).pop(-1),
                      child: const Text('Home (all lists)'),
                    ),
                    for (final list in lists)
                      SimpleDialogOption(
                        onPressed: () => Navigator.of(context).pop(list.id),
                        child: Text(list.name),
                      ),
                  ],
                ),
              );
              if (choice != null) {
                await notifier.setDefaultListId(choice == -1 ? null : choice);
              }
            },
          ),
          ListTile(
            leading: const Icon(LucideIcons.ruler),
            title: const Text('Default unit'),
            trailing: DropdownButton<String>(
              value: settings.defaultUnit,
              underline: const SizedBox.shrink(),
              items: [
                for (final unit in kUnits)
                  DropdownMenuItem(value: unit, child: Text(unit)),
              ],
              onChanged: (unit) {
                if (unit != null) notifier.setDefaultUnit(unit);
              },
            ),
          ),
          ListTile(
            leading: const Icon(LucideIcons.banknote),
            title: const Text('Currency symbol'),
            subtitle: const Text('Display only — no conversion'),
            trailing: Text(
              settings.currencySymbol.trim(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final controller =
                  TextEditingController(text: settings.currencySymbol.trim());
              final value = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Currency symbol'),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 4,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text.trim()),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (value != null && value.isNotEmpty) {
                await notifier.setCurrencySymbol('$value ');
              }
            },
          ),
          SwitchListTile(
            secondary: const Icon(LucideIcons.languages),
            title: const Text('Urdu names on suggestions'),
            subtitle: const Text('Chips read "Milk · Doodh"'),
            value: settings.showUrduNames,
            onChanged: (on) => notifier.setShowUrduNames(enabled: on),
          ),
          SwitchListTile(
            secondary: const Icon(LucideIcons.vibrate),
            title: const Text('Haptics'),
            subtitle: const Text('Buzz on check-off'),
            value: settings.haptics,
            onChanged: (on) => notifier.setHaptics(enabled: on),
          ),
          SwitchListTile(
            secondary: const Icon(LucideIcons.monitorSmartphone),
            title: const Text('Keep screen on in shop mode'),
            value: settings.wakelockInShop,
            onChanged: (on) => notifier.setWakelockInShop(enabled: on),
          ),
          const _SectionHeader('Organize'),
          ListTile(
            leading: const Icon(LucideIcons.tags),
            title: const Text('Categories'),
            subtitle: const Text('Aisle order for shop mode'),
            onTap: () => context.push('/categories'),
          ),
          ListTile(
            leading: const Icon(LucideIcons.layoutTemplate),
            title: const Text('Templates'),
            onTap: () => context.push('/templates'),
          ),
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(LucideIcons.hardDriveDownload),
            title: const Text('Export backup'),
            subtitle: const Text('One JSON file with everything'),
            onTap: () => _exportBackup(context, ref),
          ),
          ListTile(
            leading: const Icon(LucideIcons.hardDriveUpload),
            title: const Text('Import backup'),
            subtitle: const Text('Replaces all current data'),
            onTap: () => _importBackup(context, ref),
          ),
          ListTile(
            leading: Icon(
              LucideIcons.trash2,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Clear all data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _clearData(context, ref),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, 0),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
