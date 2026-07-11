import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/router.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/core/utils/share_codec.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/core/widgets/menu_sheet.dart';
import 'package:tokri/features/items/data/category_repository.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

/// Import preview (PLAN §6.7): decodes a `tokri://import?d=` payload, shows
/// what's inside, and only writes when the user confirms.
class ImportPreviewScreen extends ConsumerWidget {
  const ImportPreviewScreen({required this.payload, super.key});

  final String payload;

  Future<void> _writeInto(
    BuildContext context,
    WidgetRef ref,
    ImportedList decoded,
    int listId,
  ) async {
    final items = ref.read(itemRepositoryProvider);
    final categories = await ref.read(categoryRepositoryProvider).all();
    final byName = {for (final c in categories) c.name.toLowerCase(): c.id};
    for (final item in decoded.items) {
      // Dedupe-on-add makes this a real merge for existing lists.
      await items.add(
        listId,
        ParsedItem(
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
        ),
        categoryId: byName[item.category?.toLowerCase()],
      );
    }
    if (context.mounted) {
      context.pushReplacementNamed(
        AppRoute.listDetail.name,
        pathParameters: {'id': '$listId'},
      );
    }
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    ImportedList decoded,
  ) async {
    final listId = await ref.read(listRepositoryProvider).create(
          name: decoded.name,
          colorSeed: 0,
          icon: 'shopping-basket',
        );
    if (context.mounted) await _writeInto(context, ref, decoded, listId);
  }

  void _merge(BuildContext context, WidgetRef ref, ImportedList decoded) {
    final lists =
        ref.read(activeListsProvider).valueOrNull ?? const <ShoppingList>[];
    MenuSheet.show(
      context,
      title: 'Merge into',
      items: [
        for (final list in lists)
          MenuSheetItem(
            icon: LucideIcons.list,
            label: list.name,
            onTap: () => _writeInto(context, ref, decoded, list.id),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ImportedList decoded;
    try {
      decoded = decodeListPayload(payload);
    } on ImportException catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('Import list')),
        body: EmptyState(
          icon: LucideIcons.triangleAlert,
          title: "Can't import this",
          message: e.message,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Import list')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gaps.page,
              Gaps.md,
              Gaps.page,
              Gaps.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${decoded.name} · ${decoded.items.length} items',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: decoded.items.length,
              itemBuilder: (context, i) {
                final item = decoded.items[i];
                final showQty = item.quantity != 1 || item.unit != 'pcs';
                final qty = item.quantity == item.quantity.roundToDouble()
                    ? item.quantity.round().toString()
                    : item.quantity.toString();
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Gaps.page,
                  ),
                  leading: const Icon(LucideIcons.circle, size: 18),
                  title: Text(item.name),
                  subtitle:
                      item.category == null ? null : Text(item.category!),
                  trailing: showQty ? Text('$qty ${item.unit}') : null,
                );
              },
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              Gaps.page,
              Gaps.sm,
              Gaps.page,
              Gaps.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => _accept(context, ref, decoded),
                  child: const Text('Add as new list'),
                ),
                const SizedBox(height: Gaps.sm),
                OutlinedButton(
                  onPressed: () => _merge(context, ref, decoded),
                  child: const Text('Merge into an existing list…'),
                ),
                TextButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.goNamed(AppRoute.home.name),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
