import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/widgets/sheet_insets.dart';
import 'package:tokri/features/trips/data/trip_repository.dart';

/// Shop-mode quick price entry (PLAN §6.4): numeric pad sheet; the entered
/// price lands on the item now and in the catalog for next time.
class PricePadSheet extends ConsumerStatefulWidget {
  const PricePadSheet({required this.item, super.key});

  final Item item;

  static Future<void> show(BuildContext context, {required Item item}) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => PricePadSheet(item: item),
      );

  @override
  ConsumerState<PricePadSheet> createState() => _PricePadSheetState();
}

class _PricePadSheetState extends ConsumerState<PricePadSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final minor = widget.item.priceMinor;
    _controller = TextEditingController(
      text: minor == null ? '' : (minor / 100).round().toString(),
    );
    // Typing should replace the old price, not append to it.
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final rupees = int.tryParse(_controller.text.trim());
    if (rupees == null || rupees < 0) return;
    await ref
        .read(tripRepositoryProvider)
        .setPrice(widget.item.id, priceMinor: rupees * 100);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gaps.page,
        0,
        Gaps.page,
        sheetBottomInset(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Gaps.md),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              hintText: 'Price per unit',
              prefixText: 'Rs ',
              prefixIcon: Icon(LucideIcons.banknote, size: 18),
            ),
          ),
          const SizedBox(height: Gaps.md),
          FilledButton(onPressed: _save, child: const Text('Save price')),
        ],
      ),
    );
  }
}
