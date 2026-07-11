import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';
import 'package:tokri/features/lists/presentation/home_screen.dart';
import 'package:tokri/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget wrap() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: HomeScreen(),
        ),
      );

  testWidgets('boots to the empty home', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('My Lists'), findsOneWidget);
    expect(find.text('Your tokri is empty'), findsOneWidget);
  });

  testWidgets('shows lists pinned-first once they exist', (tester) async {
    await db.into(db.shoppingLists).insert(
          ShoppingListsCompanion.insert(
            name: 'Groceries',
            colorSeed: 0,
            icon: 'shopping-basket',
            position: 0,
          ),
        );
    await db.into(db.shoppingLists).insert(
          ShoppingListsCompanion.insert(
            name: 'Hardware',
            colorSeed: 1,
            icon: 'wrench',
            position: 1,
            pinned: const Value(true),
          ),
        );

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final groceries = tester.getTopLeft(find.text('Groceries'));
    final hardware = tester.getTopLeft(find.text('Hardware'));
    expect(hardware.dy, lessThan(groceries.dy),
        reason: 'pinned lists sort first');
  });
}
