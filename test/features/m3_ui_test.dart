import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/trips/presentation/shop_mode_screen.dart';
import 'package:tokri/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget wrap(Widget child) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: child,
        ),
      );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  Future<int> seedList(
    WidgetTester tester, {
    int? budgetMinor,
  }) =>
      real(
        tester,
        () => db.into(db.shoppingLists).insert(
              ShoppingListsCompanion.insert(
                name: 'Weekly shop',
                colorSeed: 0,
                icon: 'shopping-basket',
                position: 0,
                budgetMinor: Value(budgetMinor),
              ),
            ),
      );

  testWidgets('shop mode lists open items in aisle groups with big targets',
      (tester) async {
    final listId = await seedList(tester);
    await real(tester, () async {
      final repo = ItemRepository(db);
      await repo.add(listId, const ParsedItem(name: 'Milk')); // Dairy & Eggs
      await repo.add(listId, const ParsedItem(name: 'Apples')); // Fruits & Veg
    });

    await tester.pumpWidget(wrap(ShopModeScreen(listId: listId)));
    await tester.pumpAndSettle();

    expect(find.text('Fruits & Vegetables'), findsOneWidget);
    expect(find.text('Dairy & Eggs'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
    // Finish disabled until something is in the cart.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(
            FilledButton,
            'Finish trip · 0 in cart',
          ))
          .onPressed,
      isNull,
    );
    await unmount(tester);
  });

  testWidgets('checking updates the running total against the budget',
      (tester) async {
    final listId = await seedList(tester, budgetMinor: 100000); // Rs 1,000
    await real(tester, () async {
      await ItemRepository(db).add(
        listId,
        const ParsedItem(name: 'Milk'),
        priceMinor: 45000,
      );
    });

    await tester.pumpWidget(wrap(ShopModeScreen(listId: listId)));
    await tester.pumpAndSettle();
    expect(find.text('Rs 0 / Rs 1,000'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('Rs 450 / Rs 1,000'), findsOneWidget);
    // Milk left the open list → all done state.
    expect(find.text('All done'), findsOneWidget);
    expect(find.text('Finish trip · 1 in cart'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('price pad saves to the item and price memory', (tester) async {
    final listId = await seedList(tester);
    await real(
      tester,
      () => ItemRepository(db).add(listId, const ParsedItem(name: 'Milk')),
    );

    await tester.pumpWidget(wrap(ShopModeScreen(listId: listId)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Price'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '450');
    await tester.tap(find.text('Save price'));
    await tester.pumpAndSettle();

    expect(find.text('Rs 450'), findsOneWidget, reason: 'chip shows price');
    final entry = await real(
      tester,
      () => (db.select(db.catalogEntries)
            ..where((c) => c.nameNormalized.equals('milk')))
          .getSingle(),
    );
    expect(entry.lastPriceMinor, 45000);
    await unmount(tester);
  });

  testWidgets('finishing writes the trip and can clear bought items',
      (tester) async {
    final listId = await seedList(tester);
    await real(tester, () async {
      final repo = ItemRepository(db);
      final milk = await repo.add(
        listId,
        const ParsedItem(name: 'Milk'),
        priceMinor: 45000,
      );
      await repo.add(listId, const ParsedItem(name: 'Bread'));
      await repo.setChecked(milk, checked: true);
    });

    await tester.pumpWidget(wrap(ShopModeScreen(listId: listId)));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Finish trip'));
    await tester.pumpAndSettle();

    expect(find.text('Trip done 🎉'), findsOneWidget);
    expect(find.text('1 items bought'), findsOneWidget);
    expect(find.text('Rs 450 spent'), findsOneWidget);

    await tester.tap(find.text('Clear bought items'));
    await tester.pumpAndSettle();

    final trips = await real(tester, () => db.select(db.trips).get());
    expect(trips, hasLength(1));
    expect(trips.single.listName, 'Weekly shop');
    expect(trips.single.totalSpentMinor, 45000);

    final rows = await real(
      tester,
      () => ItemRepository(db)
          .watchForList(listId, ListSortMode.manual)
          .first,
    );
    expect(rows.done, isEmpty, reason: 'cleared after archive');
    expect(rows.open, hasLength(1));

    final milkEntry = await real(
      tester,
      () => (db.select(db.catalogEntries)
            ..where((c) => c.nameNormalized.equals('milk')))
          .getSingle(),
    );
    expect(milkEntry.timesPurchased, 1, reason: 'counter feeds ranking');
    await unmount(tester);
  });
}
