import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/widgets/app_icons.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

final _archivedListsProvider = StreamProvider(
  (ref) => ref.watch(listRepositoryProvider).watchArchived(),
);

/// Archived lists: restore or delete.
class ArchivedScreen extends ConsumerWidget {
  const ArchivedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(_archivedListsProvider);
    final repo = ref.read(listRepositoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Archived')),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (lists) {
          if (lists.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.archive,
              title: 'Nothing archived',
              message: 'Archived lists land here, ready to bring back.',
            );
          }
          return ListView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + Gaps.xl,
            ),
            children: [
              for (final list in lists)
                ListTile(
                  leading: Icon(
                    resolveIcon(list.icon),
                    color:
                        kListAccents[list.colorSeed % kListAccents.length],
                  ),
                  title: Text(list.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Restore',
                        icon: const Icon(LucideIcons.archiveRestore,
                            size: 19),
                        onPressed: () =>
                            repo.setArchived(list.id, archived: false),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(
                          LucideIcons.trash2,
                          size: 19,
                          color: scheme.error,
                        ),
                        onPressed: () => repo.delete(list.id),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
