import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/features/lists/data/list_repository.dart';
import 'package:tokri/l10n/generated/app_localizations.dart';

/// Home: the lists overview (PLAN.md §6.1). M0 ships the shell + empty state;
/// list CRUD lands in M1.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final listsAsync = ref.watch(activeListsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (lists) {
          if (lists.isEmpty) {
            return EmptyState(
              icon: LucideIcons.shoppingBasket,
              title: l10n.homeEmptyTitle,
              message: l10n.homeEmptyMessage,
            );
          }
          return ListView(
            children: [
              for (final l in lists) ListTile(title: Text(l.name)),
            ],
          );
        },
      ),
    );
  }
}
