import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/flags.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';

/// The always-visible entry bar at the bottom of a list: type, see catalog
/// suggestions inline above the field, enter to add (keyboard stays up for
/// repeated adds). Multi-entry strings ("milk, 2x eggs") and multiline
/// pastes bulk-add; an empty focused field shows the user's top items (M2).
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
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocusChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus && _controller.text.trim().isEmpty) {
      _loadIdleSuggestions();
    } else if (!_focus.hasFocus && mounted) {
      setState(() => _suggestions = const []);
    }
  }

  /// Top items from the user's history, minus what's already on the list.
  Future<void> _loadIdleSuggestions() async {
    final hits =
        await ref.read(itemRepositoryProvider).topSuggestions(widget.listId);
    if (mounted && _controller.text.trim().isEmpty) {
      setState(() => _suggestions = hits);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () async {
      // The field may have been submitted/cleared while we waited.
      if (!mounted || _controller.text != value) return;
      // Suggest on the segment being typed, not the whole paste.
      final segment = value.split(RegExp(r'[,\n]')).last.trim();
      if (segment.isEmpty) {
        await _loadIdleSuggestions();
        return;
      }
      final hits =
          await ref.read(itemRepositoryProvider).suggest(segment);
      if (mounted && _controller.text == value) {
        setState(() => _suggestions = hits);
      }
    });
  }

  Future<void> _submit([String? overrideText]) async {
    _debounce?.cancel();
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
    // Field is empty again — offer the next round of top items.
    await _loadIdleSuggestions();
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
                      // Multiline so pasted "milk\n2x eggs" keeps its
                      // newlines for the parser; done still submits.
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
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
                  // Voice add ships flag-off (core/flags.dart): no mic, no
                  // RECORD_AUDIO permission — quietly keyboard-only.
                  if (kVoiceAddEnabled) ...[
                    IconButton.filledTonal(
                      tooltip: 'Voice add',
                      onPressed: () => ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Voice add is not wired up yet — flag is on '
                            'for development only.',
                          ),
                        ),
                      ),
                      icon: const Icon(LucideIcons.mic, size: 20),
                    ),
                    const SizedBox(width: Gaps.sm),
                  ],
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
