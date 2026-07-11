import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/core/utils/budget_math.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/core/utils/money_format.dart';
import 'package:tokri/core/utils/urdu_aliases.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/core/widgets/toast.dart';
import 'package:tokri/features/items/data/category_repository.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';
import 'package:tokri/features/trips/data/trip_repository.dart';
import 'package:tokri/features/trips/presentation/price_pad_sheet.dart';
import 'package:tokri/features/trips/presentation/trip_summary_sheet.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Shop mode (PLAN §6.4): one-handed, big targets, aisle order, screen kept
/// awake. Only unchecked items show; the running total tracks what's been
/// checked against the list budget.
class ShopModeScreen extends ConsumerStatefulWidget {
  const ShopModeScreen({required this.listId, super.key});

  final int listId;

  @override
  ConsumerState<ShopModeScreen> createState() => _ShopModeScreenState();
}

class _ShopModeScreenState extends ConsumerState<ShopModeScreen> {
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    if (ref.read(settingsProvider).wakelockInShop) {
      // Best-effort: hosts without the plugin (widget tests) just skip it.
      unawaited(WakelockPlus.enable().catchError((_) {}));
    }
  }

  Future<void> _check(Item item) async {
    if (ref.read(settingsProvider).haptics) {
      unawaited(HapticFeedback.selectionClick());
    }
    final repo = ref.read(itemRepositoryProvider);
    await repo.setChecked(item.id, checked: true);
    if (!mounted) return;
    // Fat-finger insurance: one tap undoes a wrong check mid-shop.
    showToast(
      context,
      '${item.name} in cart',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => repo.setChecked(item.id, checked: false),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable().catchError((_) {}));
    super.dispose();
  }

  Future<void> _finish() async {
    final trip = await ref.read(tripRepositoryProvider).completeTrip(
          widget.listId,
          startedAt: _startedAt,
        );
    if (!mounted) return;
    await TripSummarySheet.show(context, trip: trip);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(listByIdProvider(widget.listId)).valueOrNull;
    final itemsAsync = ref.watch(
      listItemsProvider((listId: widget.listId, sort: ListSortMode.category)),
    );
    final categories = ref.watch(categoryMapProvider);
    final items = itemsAsync.valueOrNull;

    final spent = items == null
        ? (estMinor: 0, missingPrices: 0)
        : estimateTotal([
            for (final i in items.done)
              (priceMinor: i.priceMinor, quantity: i.quantity),
          ]);
    final budget = list?.budgetMinor;
    final status = budgetStatus(
      estMinor: spent.estMinor,
      budgetMinor: budget,
    );
    final symbol =
        ref.watch(settingsProvider.select((s) => s.currencySymbol));
    final scheme = Theme.of(context).colorScheme;
    final tokri = Theme.of(context).extension<TokriColors>();
    final totalColor = switch (status) {
      BudgetStatus.over => scheme.error,
      BudgetStatus.warn => tokri?.warning ?? scheme.tertiary,
      BudgetStatus.under || BudgetStatus.none => scheme.onSurface,
    };

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(list?.name ?? '', style: const TextStyle(fontSize: 18)),
            Text(
              budget != null && budget > 0
                  ? '${formatMinor(spent.estMinor, symbol: symbol)} / ${formatMinor(budget, symbol: symbol)}'
                  : formatMinor(spent.estMinor, symbol: symbol),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: totalColor, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        // The fullscreen-dialog route already provides the leading close.
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.open.isEmpty
              ? EmptyState(
                  icon: LucideIcons.partyPopper,
                  title: 'All done',
                  message: items.done.isEmpty
                      ? 'This list is empty.'
                      : 'Everything is in the cart. Finish the trip below.',
                )
              : _ShopList(
                  items: items,
                  categories: categories,
                  onCheck: _check,
                  onPrice: (item) =>
                      PricePadSheet.show(context, item: item),
                ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          Gaps.page,
          Gaps.sm,
          Gaps.page,
          Gaps.md,
        ),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: items == null || items.done.isEmpty ? null : _finish,
          icon: const Icon(LucideIcons.flagTriangleRight, size: 20),
          label: Text('Finish trip · ${items?.done.length ?? 0} in cart'),
        ),
      ),
    );
  }
}

class _ShopList extends StatelessWidget {
  const _ShopList({
    required this.items,
    required this.categories,
    required this.onCheck,
    required this.onPrice,
  });

  final ListItems items;
  final Map<int, Category> categories;
  final ValueChanged<Item> onCheck;
  final ValueChanged<Item> onPrice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final groups = <int?, List<Item>>{};
    for (final item in items.open) {
      groups.putIfAbsent(item.categoryId, () => []).add(item);
    }
    // PLAN §6.4: checked count shown per group header.
    final doneCounts = <int?, int>{};
    for (final item in items.done) {
      doneCounts.update(item.categoryId, (n) => n + 1, ifAbsent: () => 1);
    }
    final orderedKeys = groups.keys.toList()
      ..sort((a, b) {
        final pa = a == null ? 1 << 20 : categories[a]?.position ?? 1 << 19;
        final pb = b == null ? 1 << 20 : categories[b]?.position ?? 1 << 19;
        return pa.compareTo(pb);
      });

    final children = <Widget>[];
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
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: category == null
                      ? scheme.outline
                      : Color(category.color),
                ),
              ),
              const SizedBox(width: Gaps.sm),
              Text(
                category?.name ?? 'Uncategorized',
                style: text.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((doneCounts[key] ?? 0) > 0) ...[
                const SizedBox(width: Gaps.sm),
                Text(
                  '· ${doneCounts[key]} in cart',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      for (final item in groups[key]!) {
        children.add(
          _ShopTile(item: item, onCheck: onCheck, onPrice: onPrice),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: Gaps.xl),
      children: children,
    );
  }
}

class _ShopTile extends ConsumerWidget {
  const _ShopTile({
    required this.item,
    required this.onCheck,
    required this.onPrice,
  });

  final Item item;
  final ValueChanged<Item> onCheck;
  final ValueChanged<Item> onPrice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final counterpart = ref.watch(
      settingsProvider.select((s) => s.showUrduNames),
    )
        ? counterpartLabel(normalizeItemName(item.name))
        : null;
    final qty = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.round().toString()
        : item.quantity.toString();
    final showQty = item.quantity != 1 || item.unit != 'pcs';

    return InkWell(
      onTap: () => onCheck(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gaps.page,
          vertical: Gaps.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Checkbox(
                value: false,
                onChanged: (_) => onCheck(item),
              ),
            ),
            const SizedBox(width: Gaps.sm),
            Expanded(
              child: Text(
                [
                  item.name,
                  if (counterpart != null) counterpart,
                  if (showQty) '$qty ${item.unit}',
                ].join(' \u00b7 '),
                style: text.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ActionChip(
              avatar: const Icon(LucideIcons.banknote, size: 16),
              label: Text(
                item.priceMinor == null
                    ? 'Price'
                    : formatMinor(item.priceMinor!),
              ),
              onPressed: () => onPrice(item),
            ),
          ],
        ),
      ),
    );
  }
}
