import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/router.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/widgets/app_icons.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/core/widgets/menu_sheet.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

final _templatesProvider = StreamProvider<List<ShoppingList>>(
  (ref) => ref.watch(listRepositoryProvider).watchTemplates(),
);

/// Saved templates (PLAN §6.5): tap to spin up a fresh list, long-press to
/// manage. Templates are created from a list's menu ("Save as template").
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  Future<void> _instantiate(
    BuildContext context,
    WidgetRef ref,
    ShoppingList template,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: template.name),
    );
    if (name == null) return;
    final id = await ref
        .read(listRepositoryProvider)
        .instantiateTemplate(template.id, name: name);
    if (context.mounted) {
      context.pushReplacementNamed(
        AppRoute.listDetail.name,
        pathParameters: {'id': '$id'},
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(_templatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Templates')),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.layoutTemplate,
              title: 'No templates yet',
              message:
                  'Open a list and choose "Save as template" to reuse it '
                  'every week.',
            );
          }
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final template = rows[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gaps.page,
                  vertical: Gaps.xs,
                ),
                leading: Icon(resolveIcon(template.icon)),
                title: Text(template.name),
                subtitle: const Text('Tap to start a new list'),
                onTap: () => _instantiate(context, ref, template),
                onLongPress: () => MenuSheet.show(
                  context,
                  title: template.name,
                  items: [
                    MenuSheetItem(
                      icon: LucideIcons.pencil,
                      label: 'Edit items',
                      subtitle: 'Change what this template contains',
                      onTap: () => context.pushNamed(
                        AppRoute.listDetail.name,
                        pathParameters: {'id': '${template.id}'},
                      ),
                    ),
                    MenuSheetItem(
                      icon: LucideIcons.trash2,
                      label: 'Delete template',
                      onTap: () =>
                          ref.read(listRepositoryProvider).delete(template.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New list from template'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'List name'),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Create list'),
        ),
      ],
    );
  }
}
