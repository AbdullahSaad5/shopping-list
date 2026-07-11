import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tokri/core/settings/settings.dart';

Future<ProviderContainer> makeContainer() async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults are sensible on first run', () async {
    final container = await makeContainer();
    final settings = container.read(settingsProvider);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.defaultUnit, 'pcs');
    expect(settings.currencySymbol, 'Rs ');
    expect(settings.haptics, isTrue);
    expect(settings.wakelockInShop, isTrue);
    expect(settings.defaultListId, isNull);
  });

  test('writes persist and update state immutably', () async {
    final container = await makeContainer();
    final notifier = container.read(settingsProvider.notifier);
    final before = container.read(settingsProvider);

    await notifier.setThemeMode(ThemeMode.dark);
    await notifier.setDefaultUnit('kg');
    await notifier.setCurrencySymbol('₨ ');
    await notifier.setHaptics(enabled: false);
    await notifier.setWakelockInShop(enabled: false);
    await notifier.setDefaultListId(7);

    final after = container.read(settingsProvider);
    expect(before.themeMode, ThemeMode.system, reason: 'no mutation');
    expect(after.themeMode, ThemeMode.dark);
    expect(after.defaultUnit, 'kg');
    expect(after.currencySymbol, '₨ ');
    expect(after.haptics, isFalse);
    expect(after.wakelockInShop, isFalse);
    expect(after.defaultListId, 7);

    // A fresh container over the same prefs sees the persisted values.
    final reloaded = await makeContainer();
    expect(reloaded.read(settingsProvider).themeMode, ThemeMode.dark);
    expect(reloaded.read(settingsProvider).defaultListId, 7);
  });

  test('clearing the default list falls back to home', () async {
    final container = await makeContainer();
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setDefaultListId(3);
    await notifier.setDefaultListId(null);
    expect(container.read(settingsProvider).defaultListId, isNull);
  });
}
