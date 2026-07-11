import 'package:flutter/material.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/widgets/sheet_insets.dart';

/// One action row in a [MenuSheet].
class MenuSheetItem {
  const MenuSheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool destructive;
  final VoidCallback onTap;
}

/// Bottom-sheet action menu — Tokri never uses popup menus (ledgr taste).
/// Always opens on the root navigator so it can't render under overlays.
class MenuSheet extends StatelessWidget {
  const MenuSheet({required this.items, this.title, super.key});

  final List<MenuSheetItem> items;
  final String? title;

  static Future<void> show(
    BuildContext context, {
    required List<MenuSheetItem> items,
    String? title,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MenuSheet(items: items, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: sheetBottomInset(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gaps.xl,
                0,
                Gaps.xl,
                Gaps.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title!,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          for (final item in items)
            ListTile(
              leading: Icon(
                item.icon,
                size: 20,
                color: item.destructive ? scheme.error : scheme.primary,
              ),
              title: Text(
                item.label,
                style: item.destructive
                    ? TextStyle(color: scheme.error)
                    : null,
              ),
              subtitle: item.subtitle == null ? null : Text(item.subtitle!),
              onTap: () {
                Navigator.of(context).pop();
                item.onTap();
              },
            ),
        ],
      ),
    );
  }
}
