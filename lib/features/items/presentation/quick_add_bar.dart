import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';

/// The always-visible entry bar at the bottom of a list: type, see catalog
/// suggestions inline above the field, enter to add (keyboard stays up for
/// repeated adds). Multi-entry strings ("milk, 2x eggs") bulk-add.
class QuickAddBar extends ConsumerStatefulWidget {
  const QuickAddBar({required this.listId, super.key});

  final int listId;

  @override
  ConsumerState<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends ConsumerState<QuickAddBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<CatalogEntry> _suggestions = const [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      // Suggest on the segment being typed, not the whole paste.
      final segment = value.split(RegExp(r'[,\n]')).last.trim();
      final hits =
          await ref.read(itemRepositoryProvider).suggest(segment);
      if (mounted) setState(() => _suggestions = hits);
    });
  }

  Future<void> _submit([String? overrideText]) async {
    final raw = overrideText ?? _controller.text;
    final parsed = parseItems(raw);
    if (parsed.isEmpty) return;
    final repo = ref.read(itemRepositoryProvider);
    for (final item in parsed) {
      await repo.add(widget.listId, item);
    }
    _controller.clear();
    setState(() => _suggestions = const []);
    // Keep the keyboard up: repeated adds are the whole point.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Gaps.page,
            Gaps.sm,
            Gaps.page,
            // Keyboard handled by resizeToAvoidBottomInset; SafeArea above
            // keeps the bar clear of the 3-button system bar when it's down.
            Gaps.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_suggestions.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: Gaps.sm),
                    itemBuilder: (context, i) {
                      final entry = _suggestions[i];
                      return ActionChip(
                        label: Text(entry.displayName),
                        onPressed: () => _submit(entry.displayName),
                      );
                    },
                  ),
                ),
              if (_suggestions.isNotEmpty) const SizedBox(height: Gaps.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'Add items — "2x eggs, milk"',
                        prefixIcon: Icon(LucideIcons.plus, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: Gaps.sm),
                  IconButton.filled(
                    tooltip: 'Add',
                    onPressed: _submit,
                    icon: const Icon(LucideIcons.arrowUp, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
