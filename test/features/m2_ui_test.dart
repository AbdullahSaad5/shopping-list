import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/items/presentation/list_detail_screen.dart';
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

  Future<int> makeList(WidgetTester tester, {int? budgetMinor}) =>
      real(
        tester,
        () async {
          final id = await db.into(db.shoppingLists).insert(
                ShoppingListsCompanion.insert(
                  name: 'Groceries',
                  colorSeed: 0,
                  icon: 'shopping-basket',
                  position: 0,
                  budgetMinor: Value(budgetMinor),
                ),
              );
          return id;
        },
      );

  group('idle suggestions', () {
    testWidgets('focused empty quick-add shows top history chips',
        (tester) async {
      final listId = await makeList(tester);
      // History: learned on another list, so it is suggestable here.
      await real(tester, () async {
        final other = await db.into(db.shoppingLists).insert(
              ShoppingListsCompanion.insert(
                name: 'Other',
                colorSeed: 1,
                icon: 'gift',
                position: 1,
              ),
            );
        await ItemRepository(db)
            .add(other, const ParsedItem(name: 'Choco spread'));
      });

      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ActionChip, 'Choco spread'),
        findsOneWidget,
        reason: 'learned history shows as an idle chip',
      );
      // Untouched seed rows stay out of idle chips.
      expect(find.widgetWithText(ActionChip, 'Milk'), findsNothing);
      await unmount(tester);
    });

    testWidgets('idle chips refresh after a submit consumes one',
        (tester) async {
      final listId = await makeList(tester);
      await real(tester, () async {
        final other = await db.into(db.shoppingLists).insert(
              ShoppingListsCompanion.insert(
                name: 'Other',
                colorSeed: 1,
                icon: 'gift',
                position: 1,
              ),
            );
        final repo = ItemRepository(db);
        await repo.add(other, const ParsedItem(name: 'Choco spread'));
        await repo.add(other, const ParsedItem(name: 'Paper cups'));
      });

      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ActionChip, 'Paper cups'));
      await tester.pumpAndSettle();

      // Added to the list → no longer suggested; the other survives.
      expect(find.widgetWithText(ActionChip, 'Paper cups'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Choco spread'), findsOneWidget);
      expect(find.text('Paper cups'), findsOneWidget); // the item tile
      await unmount(tester);
    });
  });

  group('bilingual chips', () {
    testWidgets('suggestion chips read "English · Urdu"', (tester) async {
      final listId = await makeList(tester);
      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'doodh');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ActionChip, 'Milk \u00b7 Doodh'),
          findsOneWidget);
      await unmount(tester);
    });
  });

  group('bulk paste', () {
    testWidgets('multiline text parses into one item per line',
        (tester) async {
      final listId = await makeList(tester);
      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'milk\n2x eggs\nbread',
      );
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();

      expect(find.text('milk'), findsOneWidget);
      expect(find.text('eggs'), findsOneWidget);
      expect(find.text('bread'), findsOneWidget);
      expect(find.text('2 pcs'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('voice flag', () {
    testWidgets('mic button absent when the flag is off (default)',
        (tester) async {
      final listId = await makeList(tester);
      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Voice add'), findsNothing);
      await unmount(tester);
    });
  });

  group('budget & estimate', () {
    testWidgets('est bar shows total, budget, and missing-price count',
        (tester) async {
      final listId = await makeList(tester, budgetMinor: 500000); // Rs 5,000
      await real(tester, () async {
        final repo = ItemRepository(db);
        await repo.add(
          listId,
          const ParsedItem(name: 'Chicken', quantity: 2, unit: 'kg'),
          priceMinor: 120000, // Rs 1,200 × 2
        );
        await repo.add(listId, const ParsedItem(name: 'Bread'));
      });

      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      expect(
        find.text('Est. Rs 2,400 of Rs 5,000 · 1 without prices'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('no est bar when nothing is priced and no budget set',
        (tester) async {
      final listId = await makeList(tester);
      await real(
        tester,
        () => ItemRepository(db).add(listId, const ParsedItem(name: 'Milk')),
      );

      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Est.'), findsNothing);
      await unmount(tester);
    });
  });
}
