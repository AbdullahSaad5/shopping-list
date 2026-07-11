import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:tokri/app/theme/app_theme.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/core/utils/money_format.dart';
import 'package:tokri/core/widgets/empty_state.dart';
import 'package:tokri/features/trips/data/trip_repository.dart';

final _tripsProvider = StreamProvider<List<Trip>>(
  (ref) => ref.watch(tripRepositoryProvider).watchRecent(),
);

/// Trip history (PLAN §3.1): every archived shop-mode session, newest
/// first. Stats/charts stay fenced for v1.1 — this is the plain ledger.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(_tripsProvider);
    final symbol =
        ref.watch(settingsProvider.select((s) => s.currencySymbol));
    final dateFormat = DateFormat('EEE, d MMM · h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.footprints,
              title: 'No trips yet',
              message:
                  'Finish a shop-mode session and it lands here — items, '
                  'total, and how long it took.',
            );
          }
          return ListView.builder(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + Gaps.xl,
            ),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final trip = rows[i];
              final total = trip.totalSpentMinor;
              final minutes = (trip.durationSeconds ?? 0) ~/ 60;
              final parts = [
                '${trip.itemCount} items',
                if (total != null) formatMinor(total, symbol: symbol),
                if (minutes >= 1) '$minutes min',
              ];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Gaps.page,
                  vertical: Gaps.xs,
                ),
                leading: const Icon(LucideIcons.shoppingBasket),
                title: Text(trip.listName),
                subtitle: Text(dateFormat.format(trip.completedAt)),
                trailing: Text(
                  parts.join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
