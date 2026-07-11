import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/router.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/core/utils/share_codec.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/features/items/data/category_repository.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

/// Import preview (PLAN §6.7): decodes a `tokri://import?d=` payload, shows
/// what's inside, and only writes when the user confirms.
class ImportPreviewScreen extends ConsumerWidget {
  const ImportPreviewScreen({required this.payload, super.key});

  final String payload;

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    ImportedList decoded,
  ) async {
    final lists = ref.read(listRepositoryProvider);
    final items = ref.read(itemRepositoryProvider);
    final categories = await ref.read(categoryRepositoryProvider).all();
    final byName = {for (final c in categories) c.name.toLowerCase(): c.id};

    final listId = await lists.create(
      name: decoded.name,
      colorSeed: 0,
      icon: 'shopping-basket',
    );
    for (final item in decoded.items) {
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
                  subtitle: item.category == null ? null : Text(item.category!),
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
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.goNamed(AppRoute.home.name),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: Gaps.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _accept(context, ref, decoded),
                    child: const Text('Add as new list'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
