import 'package:flutter/material.dart';
import 'package:tokri/app/theme/app_theme.dart';

/// Centered empty-state: icon badge, title, message, optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Gaps.xxl,
          Gaps.xxl,
          Gaps.xxl,
          // Clears the ambient bottom inset so the block reads centered.
          Gaps.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.10),
              ),
              child: Icon(icon, size: 32, color: scheme.primary),
            ),
            const SizedBox(height: Gaps.lg),
            Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gaps.xs),
            Text(
              message,
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: Gaps.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
