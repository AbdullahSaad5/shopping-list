import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/db/seed.dart';
import 'package:tokri/core/widgets/app_icons.dart';
import 'package:tokri/core/widgets/sheet_insets.dart';
import 'package:tokri/features/items/data/category_repository.dart';
import 'package:tokri/features/items/data/item_repository.dart';

/// Edit an item's details — a quick-pick sheet (name, quantity/unit, price,
/// note, category, priority).
class ItemEditSheet extends ConsumerStatefulWidget {
  const ItemEditSheet({required this.item, super.key});

  final Item item;

  static Future<void> show(BuildContext context, {required Item item}) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ItemEditSheet(item: item),
    );
  }

  @override
  ConsumerState<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends ConsumerState<ItemEditSheet> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _qty = TextEditingController(
    text: widget.item.quantity == widget.item.quantity.roundToDouble()
        ? widget.item.quantity.toInt().toString()
        : widget.item.quantity.toString(),
  );
  late final _price = TextEditingController(
    text: widget.item.priceMinor == null
        ? ''
        : (widget.item.priceMinor! ~/ 100).toString(),
  );
  late final _note = TextEditingController(text: widget.item.note ?? '');
  late String _unit = widget.item.unit;
  late int? _categoryId = widget.item.categoryId;
  late bool _priority = widget.item.priority;

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final quantity =
        double.tryParse(_qty.text.trim().replaceAll(',', '.')) ?? 1;
    final priceRupees = int.tryParse(_price.text.trim());
    final note = _note.text.trim();

    await ref.read(itemRepositoryProvider).update(
          widget.item.id,
          name: name,
          quantity: quantity <= 0 ? 1 : quantity,
          unit: _unit,
          priceMinor: priceRupees == null ? null : priceRupees * 100,
          clearPrice: priceRupees == null,
          note: note.isEmpty ? null : note,
          clearNote: note.isEmpty,
          categoryId: _categoryId,
          clearCategory: _categoryId == null,
          priority: _priority,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Gaps.page,
        0,
        Gaps.page,
        sheetBottomInset(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Item name'),
                ),
              ),
              const SizedBox(width: Gaps.sm),
              IconButton(
                tooltip: 'Priority',
                isSelected: _priority,
                onPressed: () => setState(() => _priority = !_priority),
                icon: Icon(
                  _priority ? LucideIcons.flag : LucideIcons.flagOff,
                  size: 20,
                  color: _priority ? scheme.error : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          Row(
            children: [
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: 'Qty'),
                ),
              ),
              const SizedBox(width: Gaps.sm),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kUnits.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: Gaps.xs),
                    itemBuilder: (context, i) {
                      final unit = kUnits[i];
                      return ChoiceChip(
                        label: Text(unit),
                        selected: _unit == unit,
                        onSelected: (_) => setState(() => _unit = unit),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Price per unit (Rs, optional)',
              prefixIcon: Icon(LucideIcons.banknote, size: 18),
            ),
          ),
          const SizedBox(height: Gaps.md),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Note (optional)',
              prefixIcon: Icon(LucideIcons.notebookPen, size: 18),
            ),
          ),
          const SizedBox(height: Gaps.md),
          Text(
            'Category',
            style: text.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gaps.sm),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: Gaps.xs),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return ChoiceChip(
                    label: const Text('None'),
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  );
                }
                final category = categories[i - 1];
                return ChoiceChip(
                  avatar: Icon(
                    resolveIcon(category.icon),
                    size: 15,
                    color: Color(category.color),
                  ),
                  label: Text(category.name),
                  selected: _categoryId == category.id,
                  onSelected: (_) =>
                      setState(() => _categoryId = category.id),
                );
              },
            ),
          ),
          const SizedBox(height: Gaps.lg),
          SizedBox(
            width: double.infinity,
            height: 50,
            // Disabled until there's a name — no silent no-op saves.
            child: ValueListenableBuilder(
              valueListenable: _name,
              builder: (context, value, _) => FilledButton(
                onPressed: value.text.trim().isEmpty ? null : _save,
                child: const Text('Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
