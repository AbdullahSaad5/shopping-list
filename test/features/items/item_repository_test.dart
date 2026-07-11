import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/core/db/database.dart';
import 'package:tokri/core/utils/item_parser.dart';
import 'package:tokri/features/items/data/category_repository.dart';
import 'package:tokri/features/items/data/item_repository.dart';
import 'package:tokri/features/lists/data/list_repository.dart';

void main() {
  late AppDatabase db;
  late ItemRepository repo;
  late int listId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ItemRepository(db);
    listId = await ListRepository(db)
        .create(name: 'G', colorSeed: 0, icon: 'basket');
  });
  tearDown(() => db.close());

  test('add stores the parsed fields and appends position', () async {
    await repo.add(listId, const ParsedItem(name: 'Milk'));
    await repo.add(
      listId,
      const ParsedItem(name: 'Flour', quantity: 500, unit: 'g'),
    );

    final rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.open.map((i) => i.name), ['Milk', 'Flour']);
    expect(rows.open.last.unit, 'g');
    expect(rows.open.last.quantity, 500);
  });

  test('dedupe-on-add bumps quantity for same open item + unit', () async {
    await repo.add(listId, const ParsedItem(name: 'Milk', quantity: 1));
    await repo.add(listId, const ParsedItem(name: 'milk ', quantity: 2));

    final rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.open, hasLength(1));
    expect(rows.open.single.quantity, 3);
  });

  test('different unit does not dedupe', () async {
    await repo.add(listId, const ParsedItem(name: 'Milk'));
    await repo.add(
      listId,
      const ParsedItem(name: 'Milk', quantity: 500, unit: 'ml'),
    );
    final rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.open, hasLength(2));
  });

  test('a checked twin does not absorb a fresh add', () async {
    final id = await repo.add(listId, const ParsedItem(name: 'Milk'));
    await repo.setChecked(id, checked: true);
    await repo.add(listId, const ParsedItem(name: 'Milk'));

    final rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.open, hasLength(1));
    expect(rows.done, hasLength(1));
  });

  test('add teaches the catalog; suggest prefix-matches', () async {
    await repo.add(
      listId,
      const ParsedItem(name: 'Brown Bread'),
    );
    // The starter catalog also matches 'bro' (Brown sugar), so assert on
    // the learned entry rather than a single hit.
    final hits = await repo.suggest('bro');
    final bread = hits.singleWhere((h) => h.displayName == 'Brown Bread');
    expect(bread.defaultUnit, 'pcs');
    // 'zz' would substring-match seeded 'pizza base' (M2 ranking), so the
    // no-match probe uses a bigram absent from the whole catalog.
    expect(await repo.suggest('xq'), isEmpty);
    expect(await repo.suggest('  '), isEmpty);
  });

  test('re-adding a catalog item reuses its learned category', () async {
    final categories = CategoryRepository(db);
    final produce = (await categories.watchAll().first).first;
    final id = await repo.add(
      listId,
      const ParsedItem(name: 'Apples'),
      categoryId: produce.id,
    );
    await repo.delete(id);

    final again = await repo.add(listId, const ParsedItem(name: 'apples'));
    final rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(
      rows.open.singleWhere((i) => i.id == again).categoryId,
      produce.id,
    );
  });

  test('check moves to done with checkedAt; uncheck returns', () async {
    final id = await repo.add(listId, const ParsedItem(name: 'Milk'));
    await repo.setChecked(id, checked: true);
    var rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.done.single.checkedAt, isNotNull);

    await repo.setChecked(id, checked: false);
    rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.open, hasLength(1));
    expect(rows.open.single.checkedAt, isNull);
  });

  test('delete tombstones; restore brings it back (undo)', () async {
    final id = await repo.add(listId, const ParsedItem(name: 'Milk'));
    await repo.delete(id);
    expect(
      (await repo.watchForList(listId, ListSortMode.manual).first).open,
      isEmpty,
    );
    await repo.restore(id);
    expect(
      (await repo.watchForList(listId, ListSortMode.manual).first).open,
      hasLength(1),
    );
  });

  test('clearChecked tombstones only the done section', () async {
    final a = await repo.add(listId, const ParsedItem(name: 'A'));
    await repo.add(listId, const ParsedItem(name: 'B'));
    await repo.setChecked(a, checked: true);
    await repo.clearChecked(listId);

    final rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.done, isEmpty);
    expect(rows.open.single.name, 'B');
  });

  test('alpha and recent sort modes order the open section', () async {
    await repo.add(listId, const ParsedItem(name: 'zucchini'));
    await repo.add(listId, const ParsedItem(name: 'Apples'));

    final alpha = await repo.watchForList(listId, ListSortMode.alpha).first;
    expect(alpha.open.map((i) => i.name), ['Apples', 'zucchini']);

    final recent = await repo.watchForList(listId, ListSortMode.recent).first;
    expect(recent.open.first.name, 'Apples', reason: 'newest first');
  });

  test('moveToList reparents the item and appends at the end', () async {
    final other = await ListRepository(db)
        .create(name: 'Other', colorSeed: 1, icon: 'gift');
    await repo.add(other, const ParsedItem(name: 'Existing'));
    final milk = await repo.add(listId, const ParsedItem(name: 'Milk'));

    await repo.moveToList(milk, other);

    final source = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(source.open, isEmpty);
    final target = await repo.watchForList(other, ListSortMode.manual).first;
    expect(target.open.map((i) => i.name), ['Existing', 'Milk']);
  });

  test('clearChecked returns the ids so it can be undone', () async {
    final a = await repo.add(listId, const ParsedItem(name: 'A'));
    await repo.add(listId, const ParsedItem(name: 'B'));
    await repo.setChecked(a, checked: true);

    final cleared = await repo.clearChecked(listId);
    expect(cleared, [a]);
    var rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.done, isEmpty);

    await repo.restoreMany(cleared);
    rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.done, hasLength(1));
  });

  test('forgetSuggestion tombstones the catalog row; re-adding revives it',
      () async {
    await repo.add(listId, const ParsedItem(name: 'Mlik'));
    var hits = await repo.suggest('mlik');
    expect(hits.map((h) => h.displayName), contains('Mlik'));

    final entry = hits.singleWhere((h) => h.displayName == 'Mlik');
    await repo.forgetSuggestion(entry.id);
    hits = await repo.suggest('mlik');
    expect(hits.map((h) => h.displayName), isNot(contains('Mlik')));

    // Adding it again teaches the catalog again (tombstone cleared).
    await repo.add(listId, const ParsedItem(name: 'Mlik'));
    hits = await repo.suggest('mlik');
    expect(hits.map((h) => h.displayName), contains('Mlik'));
  });

  test('bulk ops: deleteMany, moveMany, setCategoryMany', () async {
    final other = await ListRepository(db)
        .create(name: 'Other', colorSeed: 1, icon: 'gift');
    final a = await repo.add(listId, const ParsedItem(name: 'A'));
    final b = await repo.add(listId, const ParsedItem(name: 'B'));
    final c = await repo.add(listId, const ParsedItem(name: 'C'));

    await repo.deleteMany([a, b]);
    var rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.open.map((i) => i.id), [c]);
    await repo.restoreMany([a, b]);

    await repo.moveMany([a, b], other);
    rows = await repo.watchForList(other, ListSortMode.manual).first;
    expect(rows.open.map((i) => i.name), ['A', 'B']);

    final produce = (await CategoryRepository(db).watchAll().first).first;
    await repo.setCategoryMany([c], produce.id);
    rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.open.single.categoryId, produce.id);
  });

  test('reorder persists manual positions', () async {
    final a = await repo.add(listId, const ParsedItem(name: 'A'));
    final b = await repo.add(listId, const ParsedItem(name: 'B'));
    await repo.reorder([b, a]);
    final rows = await repo.watchForList(listId, ListSortMode.manual).first;
    expect(rows.open.map((i) => i.id), [b, a]);
  });

  test('update edits fields and clears explicitly', () async {
    final id = await repo.add(listId, const ParsedItem(name: 'Milk'));
    await repo.update(
      id,
      name: 'Full-cream milk',
      priceMinor: 45000,
      note: 'the blue carton',
      priority: true,
    );
    var item = (await repo.watchForList(listId, ListSortMode.manual).first)
        .open
        .single;
    expect(item.name, 'Full-cream milk');
    expect(item.priceMinor, 45000);
    expect(item.note, 'the blue carton');
    expect(item.priority, isTrue);

    await repo.update(id, clearPrice: true, clearNote: true);
    item = (await repo.watchForList(listId, ListSortMode.manual).first)
        .open
        .single;
    expect(item.priceMinor, isNull);
    expect(item.note, isNull);
  });

  group('CategoryRepository', () {
    test('delete detaches items and catalog entries atomically', () async {
      final categories = CategoryRepository(db);
      final target = (await categories.watchAll().first).first;
      await repo.add(
        listId,
        const ParsedItem(name: 'Apples'),
        categoryId: target.id,
      );

      await categories.delete(target.id);

      final all = await categories.watchAll().first;
      expect(all.map((c) => c.id), isNot(contains(target.id)));
      final item = (await repo.watchForList(listId, ListSortMode.manual).first)
          .open
          .single;
      expect(item.categoryId, isNull);
      // The starter catalog fills this table, so assert nothing still
      // references the deleted category (seeded rows detach too).
      final catalog = await db.select(db.catalogEntries).get();
      expect(
        catalog.singleWhere((c) => c.nameNormalized == 'apples').categoryId,
        isNull,
      );
      expect(catalog.map((c) => c.categoryId), isNot(contains(target.id)));
    });

    test('create appends after seeds; reorder rewrites aisle order',
        () async {
      final categories = CategoryRepository(db);
      final before = await categories.watchAll().first;
      final id = await categories.create(
        name: 'Pet supplies',
        icon: 'dog',
        color: 0xFF888888,
      );
      final after = await categories.watchAll().first;
      expect(after.length, before.length + 1);
      expect(after.last.id, id);

      await categories.reorder(after.reversed.map((c) => c.id).toList());
      final reordered = await categories.watchAll().first;
      expect(reordered.first.id, id);
    });
  });
}
