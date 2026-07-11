import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/ledgr_link.dart';
import 'package:tokri/core/utils/money_format.dart';
import 'package:tokri/core/widgets/sheet_insets.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// End-of-trip summary (PLAN §6.4): count, total, duration; archive the
/// trip & clear checked, or just close. Offers "Log in Ledgr" when the
/// ledgr:// scheme resolves on this device (ticket #14) — Ledgr prefills,
/// the user confirms there.
class TripSummarySheet extends ConsumerWidget {
  const TripSummarySheet({required this.trip, super.key});

  final Trip trip;

  static Future<void> show(BuildContext context, {required Trip trip}) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => TripSummarySheet(trip: trip),
      );

  String _duration() {
    final seconds = trip.durationSeconds ?? 0;
    final minutes = seconds ~/ 60;
    if (minutes < 1) return 'under a minute';
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final total = trip.totalSpentMinor;
    final ledgrUri = buildLedgrTxUri(
      amountMinor: total,
      payee: trip.listName,
      note: 'Trip from Tokri',
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gaps.page,
        0,
        Gaps.page,
        // Clears the system nav bar — the close button was getting clipped
        // behind 3-button navigation (ledgr lesson, applied late).
        sheetBottomInset(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Trip done 🎉', style: text.titleLarge),
          const SizedBox(height: Gaps.md),
          _Row(
            icon: LucideIcons.shoppingBasket,
            label: '${trip.itemCount} items bought',
          ),
          _Row(
            icon: LucideIcons.banknote,
            label: total == null
                ? 'No prices recorded'
                : '${formatMinor(total)} spent',
          ),
          _Row(icon: LucideIcons.timer, label: _duration()),
          const SizedBox(height: Gaps.lg),
          FutureBuilder<bool>(
            future: canLaunchUrl(ledgrUri),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: Gaps.sm),
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.arrowUpRight, size: 18),
                  label: const Text('Log in Ledgr'),
                  onPressed: () => launchUrl(
                    ledgrUri,
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              );
            },
          ),
          FilledButton(
            onPressed: () async {
              final listId = trip.listId;
              if (listId != null) {
                await ref.read(itemRepositoryProvider).clearChecked(listId);
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Clear bought items'),
          ),
          const SizedBox(height: Gaps.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep them on the list'),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: Gaps.sm),
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
