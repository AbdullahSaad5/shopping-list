import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/db/seed.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/core/widgets/app_icons.dart';
import 'package:tokri/core/widgets/sheet_insets.dart';
import 'package:tokri/features/items/data/category_repository.dart';
import 'package:tokri/features/items/data/item_repository.dart';

/// Edit an item's details (redesigned per Saad 2026-07-11): labeled
/// sections, a quantity stepper, wrapped chips so nothing scrolls out of
/// sight, and a labeled priority toggle.
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

  double get _currentQty =>
      double.tryParse(_qty.text.trim().replaceAll(',', '.')) ?? 1;

  void _stepQty(double delta) {
    final next = (_currentQty + delta).clamp(1, 9999).toDouble();
    setState(() {
      _qty.text = next == next.roundToDouble()
          ? next.toInt().toString()
          : next.toStringAsFixed(1);
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final quantity = _currentQty;
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

  Widget _label(String label) => Padding(
        padding: const EdgeInsets.only(top: Gaps.lg, bottom: Gaps.sm),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final symbol =
        ref.watch(settingsProvider.select((s) => s.currencySymbol)).trim();
    final categories =
        ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];

    // Fields scroll; Save stays pinned above the system nav bar.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Gaps.page,
                0,
                Gaps.page,
                Gaps.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Item name',
              prefixIcon: Icon(LucideIcons.shoppingBasket, size: 18),
            ),
          ),
          _label('Quantity'),
          // One calm row: stepper + unit dropdown (PLAN §6.3's "qty stepper
          // + unit dropdown", finally literally).
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Less',
                onPressed: () => _stepQty(-1),
                icon: const Icon(LucideIcons.minus, size: 18),
              ),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _qty,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: Gaps.sm,
                      vertical: Gaps.sm,
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'More',
                onPressed: () => _stepQty(1),
                icon: const Icon(LucideIcons.plus, size: 18),
              ),
              const SizedBox(width: Gaps.md),
              Expanded(
                child: DropdownMenu<String>(
                  initialSelection: _unit,
                  label: const Text('Unit'),
                  expandedInsets: EdgeInsets.zero,
                  requestFocusOnTap: false,
                  onSelected: (unit) {
                    if (unit != null) setState(() => _unit = unit);
                  },
                  dropdownMenuEntries: [
                    for (final unit in kUnits)
                      DropdownMenuEntry(value: unit, label: unit),
                  ],
                ),
              ),
            ],
          ),
          _label('Price'),
          TextField(
            controller: _price,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Price per unit (optional)',
              prefixText: '$symbol ',
              prefixIcon: const Icon(LucideIcons.banknote, size: 18),
            ),
          ),
          _label('Note'),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(LucideIcons.notebookPen, size: 18),
            ),
          ),
          const SizedBox(height: Gaps.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              LucideIcons.flag,
              size: 20,
              color: _priority ? scheme.error : scheme.onSurfaceVariant,
            ),
            title: const Text('Priority'),
            subtitle: const Text('Marked with a red dot on the list'),
            value: _priority,
            onChanged: (on) => setState(() => _priority = on),
          ),
          _label('Category'),
                  Wrap(
                    spacing: Gaps.xs,
                    runSpacing: Gaps.xs,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
                        selected: _categoryId == null,
                        onSelected: (_) =>
                            setState(() => _categoryId = null),
                      ),
                      for (final category in categories)
                        ChoiceChip(
                          avatar: Icon(
                            resolveIcon(category.icon),
                            size: 15,
                            color: Color(category.color),
                          ),
                          label: Text(category.name),
                          selected: _categoryId == category.id,
                          onSelected: (_) =>
                              setState(() => _categoryId = category.id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              Gaps.page,
              Gaps.sm,
              Gaps.page,
              sheetBottomInset(context) -
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SizedBox(
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
          ),
        ],
      ),
    );
  }
}
