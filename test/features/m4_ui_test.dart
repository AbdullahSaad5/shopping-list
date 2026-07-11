import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/app/router.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/providers/database_provider.dart';
import 'package:tokri/core/settings/settings.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/core/utils/share_codec.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';
import 'package:tokri/l10n/generated/app_localizations.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget appAt(String location) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          routerConfig: createRouter(initialLocation: location),
        ),
      );

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async =>
      (await tester.runAsync(body)) as T;

  testWidgets('templates: instantiate spins up a fresh list', (tester) async {
    await real(tester, () async {
      final lists = ListRepository(db);
      final listId = await lists.create(
        name: 'Weekly',
        colorSeed: 0,
        icon: 'shopping-basket',
      );
      await ItemRepository(db).add(listId, const ParsedItem(name: 'Milk'));
      await lists.saveAsTemplate(listId);
    });

    await tester.pumpWidget(appAt('/templates'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly'), findsOneWidget);

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Week 29');
    await tester.pump();
    await tester.tap(find.text('Create list'));
    await tester.pumpAndSettle();

    // Landed on the new list's detail screen with the template's item.
    expect(find.text('Week 29'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('search finds items across lists and jumps to the list',
      (tester) async {
    await real(tester, () async {
      final lists = ListRepository(db);
      final groceries = await lists.create(
        name: 'Groceries',
        colorSeed: 0,
        icon: 'shopping-basket',
      );
      await ItemRepository(db)
          .add(groceries, const ParsedItem(name: 'Wall paint'));
    });

    await tester.pumpWidget(appAt('/search'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'paint');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Wall paint'), findsOneWidget);
    await tester.tap(find.text('Wall paint'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('import preview shows the payload and commits on confirm',
      (tester) async {
    const items = [
      ShareItem(
        name: 'Milk',
        quantity: 2,
        unit: 'pcs',
        category: 'Dairy & Eggs',
      ),
      ShareItem(name: 'Flour', quantity: 500, unit: 'g'),
    ];
    final payload = encodeListPayload('From QR', items);

    await tester.pumpWidget(appAt('/import?d=$payload'));
    await tester.pumpAndSettle();

    expect(find.text('From QR · 2 items'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    // Nothing written until confirmed.
    expect(
      await real(tester, () => ListRepository(db).watchActive().first),
      isEmpty,
    );

    await tester.tap(find.text('Add as new list'));
    await tester.pumpAndSettle();

    final lists = await real(
      tester,
      () => ListRepository(db).watchActive().first,
    );
    expect(lists.single.name, 'From QR');
    // Category resolved by name from the seeded set.
    final rows = await real(
      tester,
      () => ItemRepository(db)
          .watchForList(lists.single.id, ListSortMode.manual)
          .first,
    );
    final milk = rows.open.singleWhere((i) => i.name == 'Milk');
    expect(milk.categoryId, isNotNull);
    await unmount(tester);
  });

  testWidgets('hostile import payload shows the friendly error',
      (tester) async {
    await tester.pumpWidget(appAt('/import?d=garbage!!'));
    await tester.pumpAndSettle();
    expect(find.text("Can't import this"), findsOneWidget);
    expect(find.text('Add as new list'), findsNothing);
    await unmount(tester);
  });

  testWidgets('settings screen switches theme mode and toggles',
      (tester) async {
    await tester.pumpWidget(appAt('/settings'));
    await tester.pumpAndSettle();

    final element = tester.element(find.text('Appearance'));
    final container = ProviderScope.containerOf(element, listen: false);
    expect(container.read(settingsProvider).themeMode, ThemeMode.system);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);

    await tester.tap(find.text('Haptics'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).haptics, isFalse);
    await unmount(tester);
  });
}
