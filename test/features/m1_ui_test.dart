import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/items/presentation/categories_screen.dart';
import 'package:tokri/features/items/presentation/item_edit_sheet.dart';
import 'package:tokri/features/items/presentation/list_detail_screen.dart';
import 'package:tokri/features/lists/data/list_repository.dart';
import 'package:tokri/features/lists/presentation/archived_screen.dart';
import 'package:tokri/features/lists/presentation/home_screen.dart';
import 'package:tokri/features/lists/presentation/list_form_screen.dart';
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

  // Drift's first stream emission is scheduled on a zero-duration timer,
  // which never fires under the test binding's fake clock while awaited.
  // Run DB reads on the real event loop instead.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  group('home + list form', () {
    testWidgets('creating a list via the form shows its card', (tester) async {
      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New list'));
      await tester.pumpAndSettle();
      expect(find.text('Create list'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Groceries');
      // The button enables on the next frame (disabled while unnamed).
      await tester.pump();
      await tester.tap(find.text('Create list'));
      await tester.pumpAndSettle();

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Empty'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('card menu pins and archives', (tester) async {
      final lists = ListRepository(db);
      final id =
          await lists.create(name: 'Hardware', colorSeed: 1, icon: 'wrench');

      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Hardware'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin to top'));
      await tester.pumpAndSettle();
      expect(
        (await real(tester, () => lists.watchActive().first)).single.pinned,
        isTrue,
      );

      await tester.longPress(find.text('Hardware'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(await real(tester, () => lists.watchActive().first), isEmpty);
      expect(
        (await real(tester, () => lists.watchArchived().first)).single.id,
        id,
      );
      await unmount(tester);
    });

    testWidgets('archived screen restores a list', (tester) async {
      final lists = ListRepository(db);
      final id =
          await lists.create(name: 'Party', colorSeed: 2, icon: 'gift');
      await lists.setArchived(id, archived: true);

      await tester.pumpWidget(wrap(const ArchivedScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Party'), findsOneWidget);

      await tester.tap(find.byTooltip('Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing archived'), findsOneWidget);
      expect(
        (await real(tester, () => lists.watchActive().first)).single.id,
        id,
      );
      await unmount(tester);
    });

    testWidgets('edit form renames an existing list', (tester) async {
      final lists = ListRepository(db);
      final id =
          await lists.create(name: 'Old name', colorSeed: 0, icon: 'gift');
      final list =
          (await real(tester, () => lists.watchActive().first)).single;

      await tester.pumpWidget(wrap(ListFormScreen(list: list)));
      await tester.pumpAndSettle();
      expect(find.text('Edit list'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'New name');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated =
          (await real(tester, () => lists.watchActive().first)).single;
      expect(updated.id, id);
      expect(updated.name, 'New name');
      await unmount(tester);
    });
  });

  group('list detail', () {
    late int listId;

    setUp(() async {
      listId = await ListRepository(db)
          .create(name: 'Groceries', colorSeed: 0, icon: 'shopping-basket');
    });

    testWidgets('quick-add parses a multi-entry string', (tester) async {
      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        '2x eggs, 500g flour',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('eggs'), findsOneWidget);
      expect(find.text('flour'), findsOneWidget);
      expect(find.text('2 pcs'), findsOneWidget);
      expect(find.text('500 g'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('suggestion chip adds the catalog item', (tester) async {
      await ItemRepository(db)
          .add(listId, const ParsedItem(name: 'Brown Bread'));

      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'bro');
      // Suggestion lookup debounces 120ms.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      // Starter catalog matches 'bro' too (Brown sugar), so target the
      // learned entry's chip by label.
      final chip = find.widgetWithText(ActionChip, 'Brown Bread');
      expect(chip, findsOneWidget);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      // Dedupe-on-add bumped the existing open item instead of duplicating.
      final rows = await real(
        tester,
        () => ItemRepository(db)
            .watchForList(listId, ListSortMode.category)
            .first,
      );
      expect(rows.open.single.quantity, 2);
      await unmount(tester);
    });

    testWidgets('checking moves the item into a collapsible done section',
        (tester) async {
      final items = ItemRepository(db);
      await items.add(listId, const ParsedItem(name: 'Milk'));

      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.textContaining('In cart'), findsOneWidget);

      // Collapse hides the checked tile.
      await tester.tap(find.textContaining('In cart'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsNothing);
      await unmount(tester);
    });

    testWidgets('swipe-delete shows undo and restores', (tester) async {
      final items = ItemRepository(db);
      await items.add(listId, const ParsedItem(name: 'Milk'));

      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Milk'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Milk removed'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Milk'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('sort menu switches to alphabetical', (tester) async {
      final items = ItemRepository(db);
      await items.add(listId, const ParsedItem(name: 'zucchini'));
      await items.add(listId, const ParsedItem(name: 'apples'));

      await tester.pumpWidget(wrap(ListDetailScreen(listId: listId)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alphabetical'));
      await tester.pumpAndSettle();

      final zPos = tester.getTopLeft(find.text('zucchini'));
      final aPos = tester.getTopLeft(find.text('apples'));
      expect(aPos.dy, lessThan(zPos.dy));
      await unmount(tester);
    });

    testWidgets('edit sheet updates quantity, unit, and price',
        (tester) async {
      final items = ItemRepository(db);
      final id = await items.add(listId, const ParsedItem(name: 'Milk'));
      final item = (await real(
        tester,
        () => items.watchForList(listId, ListSortMode.manual).first,
      ))
          .open
          .single;

      await tester.pumpWidget(
        wrap(Scaffold(body: ItemEditSheet(item: item))),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '2');
      await tester.tap(find.text('L'));
      await tester.enterText(find.byType(TextField).at(2), '450');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final updated = (await real(
        tester,
        () => items.watchForList(listId, ListSortMode.manual).first,
      ))
          .open
          .single;
      expect(updated.id, id);
      expect(updated.quantity, 2);
      expect(updated.unit, 'L');
      expect(updated.priceMinor, 45000);
      await unmount(tester);
    });
  });

  group('categories screen', () {
    testWidgets('adds, edits, and deletes a category', (tester) async {
      await tester.pumpWidget(wrap(const CategoriesScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Fruits & Vegetables'), findsOneWidget);

      // Add.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Pet supplies');
      await tester.tap(find.text('Add category'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Pet supplies'), 200);
      expect(find.text('Pet supplies'), findsOneWidget);

      // Edit via the row menu.
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Pet supplies'),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Pets');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Pets'), 200);
      expect(find.text('Pets'), findsOneWidget);

      // Delete via the row menu.
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Pets'),
          matching: find.byType(IconButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Pets'), findsNothing);
      await unmount(tester);
    });
  });
}
