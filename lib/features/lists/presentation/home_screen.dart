import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/core/utils/money_format.dart';
import 'package:tokri/core/widgets/app_icons.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/core/widgets/menu_sheet.dart';
import 'package:tokri/core/widgets/toast.dart';
import 'package:tokri/features/lists/data/list_repository.dart';
import 'package:tokri/features/lists/presentation/list_form_screen.dart';
import 'package:tokri/l10n/generated/app_localizations.dart';

/// Home: the lists overview (PLAN.md §6.1). Cards with progress, drag to
/// reorder, overflow menu per list.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final listsAsync = ref.watch(activeListsWithStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(LucideIcons.search, size: 20),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            tooltip: 'More',
            icon: const Icon(LucideIcons.moreVertical, size: 20),
            onPressed: () => MenuSheet.show(
              context,
              items: [
                MenuSheetItem(
                  icon: LucideIcons.layoutTemplate,
                  label: 'Templates',
                  subtitle: 'Start a list from a saved one',
                  onTap: () => context.push('/templates'),
                ),
                MenuSheetItem(
                  icon: LucideIcons.tags,
                  label: 'Categories',
                  subtitle: 'Aisle order for shop mode',
                  onTap: () => context.push('/categories'),
                ),
                MenuSheetItem(
                  icon: LucideIcons.footprints,
                  label: 'Trips',
                  subtitle: 'Past shopping sessions',
                  onTap: () => context.push('/trips'),
                ),
                MenuSheetItem(
                  icon: LucideIcons.archive,
                  label: 'Archived lists',
                  onTap: () => context.push('/archived'),
                ),
                MenuSheetItem(
                  icon: LucideIcons.settings,
                  label: 'Settings',
                  onTap: () => context.push('/settings'),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gaps.sm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ListFormScreen.show(context),
        icon: const Icon(LucideIcons.plus),
        label: Text(l10n.newList),
      ),
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
          return ReorderableListView.builder(
            padding: EdgeInsets.fromLTRB(
              Gaps.page,
              Gaps.xs,
              Gaps.page,
              // Clears the FAB and the system bar.
              MediaQuery.paddingOf(context).bottom + 88,
            ),
            itemCount: lists.length,
            // onReorderItem pre-adjusts newIndex for the removed slot.
            onReorderItem: (oldIndex, newIndex) {
              final ids = lists.map((s) => s.list.id).toList();
              ids.insert(newIndex, ids.removeAt(oldIndex));
              ref.read(listRepositoryProvider).reorder(ids);
            },
            itemBuilder: (context, index) {
              final stats = lists[index];
              return Padding(
                key: ValueKey(stats.list.id),
                padding: const EdgeInsets.only(bottom: Gaps.md),
                child: _ListCard(stats: stats),
              );
            },
          );
        },
      ),
    );
  }
}

class _ListCard extends ConsumerWidget {
  const _ListCard({required this.stats});

  final ListWithStats stats;

  void _menu(BuildContext context, WidgetRef ref) {
    final repo = ref.read(listRepositoryProvider);
    final list = stats.list;
    MenuSheet.show(
      context,
      title: list.name,
      items: [
        MenuSheetItem(
          icon: list.pinned ? LucideIcons.pinOff : LucideIcons.pin,
          label: list.pinned ? 'Unpin' : 'Pin to top',
          onTap: () => repo.setPinned(list.id, pinned: !list.pinned),
        ),
        MenuSheetItem(
          icon: LucideIcons.pencil,
          label: 'Edit',
          onTap: () => ListFormScreen.show(context, list: list),
        ),
        MenuSheetItem(
          icon: LucideIcons.archive,
          label: 'Archive',
          subtitle: 'Hidden from home, kept forever',
          onTap: () => repo.setArchived(list.id, archived: true),
        ),
        MenuSheetItem(
          icon: LucideIcons.trash2,
          label: 'Delete',
          destructive: true,
          onTap: () async {
            await repo.delete(list.id);
            if (context.mounted) {
              showToast(
                context,
                '${list.name} deleted',
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => repo.restore(list.id),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final list = stats.list;
    final accent = kListAccents[list.colorSeed % kListAccents.length];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/list/${list.id}'),
        onLongPress: () => _menu(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(Gaps.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: accent.withValues(alpha: 0.15),
                ),
                child: Icon(resolveIcon(list.icon), color: accent, size: 22),
              ),
              const SizedBox(width: Gaps.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (list.pinned) ...[
                          Icon(
                            LucideIcons.pin,
                            size: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: Gaps.xs),
                        ],
                        Expanded(
                          child: Text(
                            list.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gaps.xs),
                    Text(
                      stats.totalItems == 0
                          ? 'Empty'
                          : [
                              '${stats.checkedItems}/${stats.totalItems} done',
                              if (stats.estimatedTotalMinor != null)
                                '~${formatMinor(
                                  stats.estimatedTotalMinor!,
                                  symbol: ref.watch(
                                    settingsProvider
                                        .select((s) => s.currencySymbol),
                                  ),
                                )}',
                            ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (stats.totalItems > 0) ...[
                      const SizedBox(height: Gaps.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: stats.progress,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gaps.sm),
              IconButton(
                icon: const Icon(LucideIcons.moreVertical, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => _menu(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
