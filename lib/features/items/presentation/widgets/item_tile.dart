import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/core/utils/money_format.dart';

/// One item row: animated checkbox, name + quantity/price chips, swipe left
/// to delete (undo handled by the caller), tap to edit.
class ItemTile extends ConsumerWidget {
  const ItemTile({
    required this.item,
    required this.onCheck,
    required this.onTap,
    required this.onDelete,
    this.category,
    super.key,
  });

  final Item item;
  final Category? category;
  final ValueChanged<bool> onCheck;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String get _qtyLabel {
    final qty = item.quantity;
    final rendered =
        qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();
    return '$rendered ${item.unit}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final showQty = item.quantity != 1 || item.unit != 'pcs';

    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Gaps.xl),
        child: Icon(Icons.delete_outline, color: scheme.onError),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gaps.page,
            vertical: 2,
          ),
          child: Row(
            children: [
              Checkbox(
                value: item.checked,
                shape: const CircleBorder(),
                onChanged: (v) => onCheck(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.priority && !item.checked) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.error,
                            ),
                          ),
                          const SizedBox(width: Gaps.xs),
                        ],
                        Flexible(
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(
                              decoration: item.checked
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item.checked
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (showQty) ...[
                          const SizedBox(width: Gaps.sm),
                          _Chip(label: _qtyLabel),
                        ],
                        if (item.priceMinor != null) ...[
                          const SizedBox(width: Gaps.xs),
                          _Chip(
                            label: formatMinor(
                              item.priceMinor!,
                              symbol: ref.watch(
                                settingsProvider
                                    .select((s) => s.currencySymbol),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.note != null && item.note!.isNotEmpty)
                      Text(
                        item.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: scheme.surfaceContainer,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
