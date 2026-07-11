import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/router.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/widgets/app_icons.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/features/lists/data/search_repository.dart';

/// Global search (PLAN §6.6): item names across lists + list names.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  SearchResults _results = (items: const [], lists: const []);
  Timer? _debounce;
  bool _searched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      final results = await ref.read(searchRepositoryProvider).search(value);
      if (mounted && _controller.text == value) {
        setState(() {
          _results = results;
          _searched = value.trim().isNotEmpty;
        });
      }
    });
  }

  void _openList(BuildContext context, int listId) => context.pushNamed(
        AppRoute.listDetail.name,
        pathParameters: {'id': '$listId'},
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = _results.items.isEmpty && _results.lists.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search items and lists',
            border: InputBorder.none,
          ),
        ),
      ),
      body: empty
          ? EmptyState(
              icon: LucideIcons.search,
              title: _searched ? 'Nothing found' : 'Search everything',
              message: _searched
                  ? 'No items or lists match that.'
                  : 'Find an item on any list, or jump to a list by name.',
            )
          : ListView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + Gaps.xl,
              ),
              children: [
                for (final list in _results.lists)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Gaps.page,
                    ),
                    leading: Icon(resolveIcon(list.icon)),
                    title: Text(list.name),
                    subtitle: const Text('List'),
                    onTap: () => _openList(context, list.id),
                  ),
                for (final hit in _results.items)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Gaps.page,
                    ),
                    leading: Icon(
                      hit.item.checked
                          ? LucideIcons.circleCheck
                          : LucideIcons.circle,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: Text(hit.item.name),
                    subtitle: Text(hit.list.name),
                    onTap: () => _openList(context, hit.list.id),
                  ),
              ],
            ),
    );
  }
}
