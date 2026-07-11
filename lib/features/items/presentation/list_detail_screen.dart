import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tokri/app/router.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/core/utils/budget_math.dart';
import 'package:tokri/core/utils/money_format.dart';
import 'package:tokri/core/utils/share_codec.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/core/widgets/menu_sheet.dart';
import 'package:tokri/core/widgets/toast.dart';
import 'package:tokri/features/items/data/category_repository.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/items/presentation/item_edit_sheet.dart';
import 'package:tokri/features/items/presentation/quick_add_bar.dart';
import 'package:tokri/features/items/presentation/widgets/item_tile.dart';
import 'package:tokri/features/lists/data/list_repository.dart';
import 'package:tokri/features/lists/presentation/list_form_screen.dart';

/// Which sort mode a list uses — kept on the list row so it persists.
final _sortProvider =
    StreamProvider.family<ListSortMode, int>((ref, listId) async* {
  await for (final list
      in ref.watch(listRepositoryProvider).watchById(listId)) {
    if (list != null) yield list.sortMode;
  }
});

/// List detail (PLAN.md §6.2): items grouped by category, quick-add bar
/// pinned to the bottom, done section collapsible.
class ListDetailScreen extends ConsumerStatefulWidget {
  const ListDetailScreen({required this.listId, super.key});

  final int listId;

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  bool _doneCollapsed = false;

  Future<void> _sortMenu(ListSortMode current) {
    const labels = {
      ListSortMode.manual: 'Manual (drag)',
      ListSortMode.category: 'By category',
      ListSortMode.alpha: 'Alphabetical',
      ListSortMode.recent: 'Recently added',
    };
    return MenuSheet.show(
      context,
      title: 'Sort items',
      items: [
        for (final mode in [
          ListSortMode.category,
          ListSortMode.manual,
          ListSortMode.alpha,
          ListSortMode.recent,
        ])
          MenuSheetItem(
            icon: mode == current
                ? LucideIcons.circleCheck
                : LucideIcons.circle,
            label: labels[mode]!,
            onTap: () => ref
                .read(listRepositoryProvider)
                .setSortMode(widget.listId, mode),
          ),
      ],
    );
  }

  /// Current rows as the share codec's shape, open before done.
  List<ShareItem> _shareItems(ListItems rows, Map<int, Category> categories) =>
      [
        for (final item in [...rows.open, ...rows.done])
          ShareItem(
            name: item.name,
            quantity: item.quantity,
            unit: item.unit,
            category: item.categoryId == null
                ? null
                : categories[item.categoryId]?.name,
            checked: item.checked,
          ),
      ];

  void _listMenu(ShoppingList list) {
    final itemsRepo = ref.read(itemRepositoryProvider);
    final listsRepo = ref.read(listRepositoryProvider);
    final rows = ref.read(
      listItemsProvider((
        listId: widget.listId,
        sort: ListSortMode.category,
      )),
    );
    final categories = ref.read(categoryMapProvider);
    final items = rows.valueOrNull == null
        ? const <ShareItem>[]
        : _shareItems(rows.valueOrNull!, categories);

    MenuSheet.show(
      context,
      title: list.name,
      items: [
        MenuSheetItem(
          icon: LucideIcons.pencil,
          label: 'Edit list',
          onTap: () => ListFormScreen.show(context, list: list),
        ),
        MenuSheetItem(
          icon: LucideIcons.eraser,
          label: 'Clear checked',
          onTap: () async {
            final cleared = await itemsRepo.clearChecked(widget.listId);
            if (mounted && cleared.isNotEmpty) {
              showToast(
                context,
                '${cleared.length} cleared',
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () => itemsRepo.restoreMany(cleared),
                ),
              );
            }
          },
        ),
        MenuSheetItem(
          icon: LucideIcons.layoutTemplate,
          label: 'Save as template',
          subtitle: 'Reuse this list from Templates',
          onTap: () async {
            await listsRepo.saveAsTemplate(widget.listId);
            if (mounted) showToast(context, 'Saved to Templates.');
          },
        ),
        if (items.isNotEmpty) ...[
          MenuSheetItem(
            icon: LucideIcons.copy,
            label: 'Copy as text',
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(text: shareText(list.name, items)),
              );
              if (mounted) showToast(context, 'Copied.');
            },
          ),
          MenuSheetItem(
            icon: LucideIcons.share2,
            label: 'Share…',
            onTap: () => SharePlus.instance.share(
              ShareParams(text: shareText(list.name, items)),
            ),
          ),
          MenuSheetItem(
            icon: LucideIcons.qrCode,
            label: 'QR code',
            subtitle: 'Scan with another phone running Tokri',
            onTap: () => _showQr(list.name, items),
          ),
        ],
      ],
    );
  }

  void _showQr(String name, List<ShareItem> items) {
    final String data;
    try {
      data = buildImportUri(name, items).toString();
    } on ImportException catch (e) {
      showToast(context, e.message);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(Gaps.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Gaps.md),
              // QR must stay scannable in dark mode: pin a light tile.
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(Gaps.md),
                    child: QrImageView(data: data, size: 240),
                  ),
                ),
              ),
              const SizedBox(height: Gaps.sm),
              Text(
                'Scanning opens an import preview in Tokri.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(listByIdProvider(widget.listId));
    final sort =
        ref.watch(_sortProvider(widget.listId)).valueOrNull ??
            ListSortMode.category;
    final itemsAsync =
        ref.watch(listItemsProvider((listId: widget.listId, sort: sort)));
    final categories = ref.watch(categoryMapProvider);

    final list = listAsync.valueOrNull;

    final hasOpenItems = itemsAsync.valueOrNull?.open.isNotEmpty ?? false;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(list?.name ?? ''),
        actions: [
          if (hasOpenItems)
            IconButton.filledTonal(
              tooltip: 'Shop mode',
              icon: const Icon(LucideIcons.shoppingCart, size: 19),
              onPressed: () => context.pushNamed(
                AppRoute.shopMode.name,
                pathParameters: {'id': '${widget.listId}'},
              ),
            ),
          IconButton(
            tooltip: 'Sort',
            icon: const Icon(LucideIcons.arrowUpDown, size: 19),
            onPressed: () => _sortMenu(sort),
          ),
          IconButton(
            tooltip: 'More',
            icon: const Icon(LucideIcons.moreVertical, size: 20),
            onPressed: list == null ? null : () => _listMenu(list),
          ),
          const SizedBox(width: Gaps.sm),
        ],
      ),
      body: Column(
        children: [
          if (list != null)
            _EstBar(
              list: list,
              items: itemsAsync.valueOrNull,
              symbol: ref.watch(
                settingsProvider.select((s) => s.currencySymbol),
              ),
            ),
          Expanded(
            child: itemsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                if (items.open.isEmpty && items.done.isEmpty) {
                  return const EmptyState(
                    icon: LucideIcons.listPlus,
                    title: 'Nothing here yet',
                    message:
                        'Type below to add items — try "2x eggs, milk".',
                  );
                }
                return _ItemsList(
                  listId: widget.listId,
                  items: items,
                  sort: sort,
                  categories: categories,
                  doneCollapsed: _doneCollapsed,
                  onToggleDone: () =>
                      setState(() => _doneCollapsed = !_doneCollapsed),
                );
              },
            ),
          ),
          QuickAddBar(listId: widget.listId),
        ],
      ),
    );
  }
}

/// Estimated total + budget line under the app bar (PLAN §3 "Budget &
/// prices"): sum of known prices × qty, count of unpriced items, and the
/// budget comparison colored amber at 80% / red when over.
class _EstBar extends StatelessWidget {
  const _EstBar({
    required this.list,
    required this.items,
    required this.symbol,
  });

  final ShoppingList list;
  final ListItems? items;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final rows = items;
    if (rows == null || (rows.open.isEmpty && rows.done.isEmpty)) {
      return const SizedBox.shrink();
    }
    final est = estimateTotal([
      for (final i in [...rows.open, ...rows.done])
        (priceMinor: i.priceMinor, quantity: i.quantity),
    ]);
    final budget = list.budgetMinor;
    // No prices and no budget = no estimate worth showing; "Est. Rs 0"
    // would just be noise.
    if (est.estMinor == 0 && (budget == null || budget <= 0)) {
      return const SizedBox.shrink();
    }
    final status = budgetStatus(estMinor: est.estMinor, budgetMinor: budget);

    final scheme = Theme.of(context).colorScheme;
    // Fallback for hosts without the app theme (plain-theme widget tests).
    final tokri = Theme.of(context).extension<TokriColors>();
    final statusColor = switch (status) {
      BudgetStatus.over => scheme.error,
      BudgetStatus.warn => tokri?.warning ?? scheme.tertiary,
      BudgetStatus.under || BudgetStatus.none => scheme.onSurfaceVariant,
    };

    final parts = [
      'Est. ${formatMinor(est.estMinor, symbol: symbol)}',
      if (budget != null && budget > 0)
        'of ${formatMinor(budget, symbol: symbol)}',
      if (est.missingPrices > 0) '· ${est.missingPrices} without prices',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            parts.join(' '),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (budget != null && budget > 0) ...[
            const SizedBox(height: Gaps.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: (est.estMinor / budget).clamp(0.0, 1.0),
                color: status == BudgetStatus.under
                    ? scheme.primary
                    : statusColor,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsList extends ConsumerWidget {
  const _ItemsList({
    required this.listId,
    required this.items,
    required this.sort,
    required this.categories,
    required this.doneCollapsed,
    required this.onToggleDone,
  });

  final int listId;
  final ListItems items;
  final ListSortMode sort;
  final Map<int, Category> categories;
  final bool doneCollapsed;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final repo = ref.read(itemRepositoryProvider);

    // Category sort groups under aisle headers, aisle position order.
    final children = <Widget>[];
    if (sort == ListSortMode.category) {
      final groups = <int?, List<Item>>{};
      for (final item in items.open) {
        groups.putIfAbsent(item.categoryId, () => []).add(item);
      }
      final orderedKeys = groups.keys.toList()
        ..sort((a, b) {
          final pa = a == null ? 1 << 20 : categories[a]?.position ?? 1 << 19;
          final pb = b == null ? 1 << 20 : categories[b]?.position ?? 1 << 19;
          return pa.compareTo(pb);
        });
      for (final key in orderedKeys) {
        final category = key == null ? null : categories[key];
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gaps.page,
              Gaps.lg,
              Gaps.page,
              Gaps.xs,
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: category == null
                        ? scheme.outline
                        : Color(category.color),
                  ),
                ),
                const SizedBox(width: Gaps.sm),
                Expanded(
                  child: Text(
                    category?.name ?? 'Uncategorized',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        for (final item in groups[key]!) {
          children.add(_tile(context, repo, item));
        }
      }
    } else {
      for (final item in items.open) {
        children.add(_tile(context, repo, item));
      }
    }

    if (items.done.isNotEmpty) {
      children.add(
        InkWell(
          onTap: onToggleDone,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Gaps.page,
              Gaps.xl,
              Gaps.page,
              Gaps.xs,
            ),
            child: Row(
              children: [
                Icon(
                  doneCollapsed
                      ? LucideIcons.chevronRight
                      : LucideIcons.chevronDown,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: Gaps.sm),
                Text(
                  'In cart · ${items.done.length}',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (!doneCollapsed) {
        for (final item in items.done) {
          children.add(_tile(context, repo, item));
        }
      }
    }

    return ListView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.paddingOf(context).bottom + Gaps.xl,
      ),
      children: children,
    );
  }

  Widget _tile(BuildContext context, ItemRepository repo, Item item) {
    return ItemTile(
      key: ValueKey(item.id),
      item: item,
      category:
          item.categoryId == null ? null : categories[item.categoryId],
      onCheck: (checked) => repo.setChecked(item.id, checked: checked),
      onTap: () => ItemEditSheet.show(context, item: item),
      onDelete: () async {
        await repo.delete(item.id);
        if (context.mounted) {
          showToast(
            context,
            '${item.name} removed',
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => repo.restore(item.id),
            ),
          );
        }
      },
    );
  }
}
