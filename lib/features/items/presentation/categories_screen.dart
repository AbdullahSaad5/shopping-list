import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/widgets/app_icons.dart';
import 'package:tokri/core/widgets/menu_sheet.dart';
import 'package:tokri/core/widgets/sheet_insets.dart';
import 'package:tokri/features/items/data/category_repository.dart';

/// Manage aisle categories: rename, recolor, reorder (drag = aisle order in
/// shop mode), add, delete.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final repo = ref.read(categoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _CategoryFormSheet.show(context),
        child: const Icon(LucideIcons.plus),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (categories) => ReorderableListView.builder(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 88,
          ),
          itemCount: categories.length,
          // onReorderItem pre-adjusts newIndex for the removed slot.
          onReorderItem: (oldIndex, newIndex) {
            final ids = categories.map((c) => c.id).toList();
            ids.insert(newIndex, ids.removeAt(oldIndex));
            repo.reorder(ids);
          },
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              key: ValueKey(category.id),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Color(category.color).withValues(alpha: 0.15),
                ),
                child: Icon(
                  resolveIcon(category.icon),
                  size: 18,
                  color: Color(category.color),
                ),
              ),
              title: Text(category.name),
              trailing: IconButton(
                icon: const Icon(LucideIcons.moreVertical, size: 18),
                visualDensity: VisualDensity.compact,
                onPressed: () => MenuSheet.show(
                  context,
                  title: category.name,
                  items: [
                    MenuSheetItem(
                      icon: LucideIcons.pencil,
                      label: 'Edit',
                      onTap: () =>
                          _CategoryFormSheet.show(context, category: category),
                    ),
                    MenuSheetItem(
                      icon: LucideIcons.trash2,
                      label: 'Delete',
                      subtitle: 'Items keep their names, lose this aisle',
                      destructive: true,
                      onTap: () => repo.delete(category.id),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryFormSheet extends ConsumerStatefulWidget {
  const _CategoryFormSheet({this.category});

  final Category? category;

  static Future<void> show(BuildContext context, {Category? category}) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _CategoryFormSheet(category: category),
    );
  }

  @override
  ConsumerState<_CategoryFormSheet> createState() =>
      _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<_CategoryFormSheet> {
  static const _palette = <int>[
    0xFF43A047,
    0xFF1E88E5,
    0xFFE53935,
    0xFFF9A825,
    0xFF8E24AA,
    0xFF00897B,
    0xFFE64A19,
    0xFF5E35B1,
  ];

  late final _name = TextEditingController(text: widget.category?.name ?? '');
  late int _color = widget.category?.color ?? _palette.first;
  late String _icon = widget.category?.icon ?? 'shopping-basket';

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(categoryRepositoryProvider);
    if (_isEditing) {
      await repo.update(
        widget.category!.id,
        name: name,
        icon: _icon,
        color: _color,
      );
    } else {
      await repo.create(name: name, icon: _icon, color: _color);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
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
          TextField(
            controller: _name,
            autofocus: !_isEditing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Category name'),
          ),
          const SizedBox(height: Gaps.md),
          Wrap(
            spacing: Gaps.sm,
            children: [
              for (final color in _palette)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _color = color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(color),
                      border: _color == color
                          ? Border.all(color: scheme.onSurface, width: 2.5)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gaps.md),
          Wrap(
            spacing: Gaps.xs,
            runSpacing: Gaps.xs,
            children: [
              for (final name in kListIcons)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _icon = name),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: _icon == name
                          ? Color(_color).withValues(alpha: 0.2)
                          : scheme.surfaceContainer,
                    ),
                    child: Icon(
                      resolveIcon(name),
                      size: 17,
                      color: _icon == name
                          ? Color(_color)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gaps.lg),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save' : 'Add category'),
            ),
          ),
        ],
      ),
    );
  }
}
