/// App settings (PLAN §3 "Settings"), persisted in SharedPreferences.
/// M4 note: dynamic color + global accent seed are deliberately deferred —
/// the warm-bazaar theme IS the brand; revisit at M5 with Saad.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the real instance; tests inject a mock.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override in main()'),
);

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.defaultUnit = 'pcs',
    this.currencySymbol = 'Rs ',
    this.haptics = true,
    this.wakelockInShop = true,
    this.defaultListId,
  });

  final ThemeMode themeMode;
  final String defaultUnit;

  /// Display only — no FX anywhere (PLAN §3).
  final String currencySymbol;
  final bool haptics;
  final bool wakelockInShop;

  /// Opens this list on launch instead of home when set.
  final int? defaultListId;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? defaultUnit,
    String? currencySymbol,
    bool? haptics,
    bool? wakelockInShop,
    int? Function()? defaultListId,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        defaultUnit: defaultUnit ?? this.defaultUnit,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        haptics: haptics ?? this.haptics,
        wakelockInShop: wakelockInShop ?? this.wakelockInShop,
        defaultListId:
            defaultListId == null ? this.defaultListId : defaultListId(),
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._prefs)
      : super(_prefs == null ? const AppSettings() : _load(_prefs));

  /// Null in hosts without a prefs override (widget tests): settings work
  /// in-memory for the session and simply don't persist.
  final SharedPreferences? _prefs;

  static const _kTheme = 'themeMode';
  static const _kUnit = 'defaultUnit';
  static const _kSymbol = 'currencySymbol';
  static const _kHaptics = 'haptics';
  static const _kWakelock = 'wakelockInShop';
  static const _kDefaultList = 'defaultListId';

  static AppSettings _load(SharedPreferences prefs) => AppSettings(
        themeMode: ThemeMode.values.asNameMap()[prefs.getString(_kTheme)] ??
            ThemeMode.system,
        defaultUnit: prefs.getString(_kUnit) ?? 'pcs',
        currencySymbol: prefs.getString(_kSymbol) ?? 'Rs ',
        haptics: prefs.getBool(_kHaptics) ?? true,
        wakelockInShop: prefs.getBool(_kWakelock) ?? true,
        defaultListId: prefs.getInt(_kDefaultList),
      );

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs?.setString(_kTheme, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setDefaultUnit(String unit) async {
    await _prefs?.setString(_kUnit, unit);
    state = state.copyWith(defaultUnit: unit);
  }

  Future<void> setCurrencySymbol(String symbol) async {
    await _prefs?.setString(_kSymbol, symbol);
    state = state.copyWith(currencySymbol: symbol);
  }

  Future<void> setHaptics({required bool enabled}) async {
    await _prefs?.setBool(_kHaptics, enabled);
    state = state.copyWith(haptics: enabled);
  }

  Future<void> setWakelockInShop({required bool enabled}) async {
    await _prefs?.setBool(_kWakelock, enabled);
    state = state.copyWith(wakelockInShop: enabled);
  }

  Future<void> setDefaultListId(int? id) async {
    if (id == null) {
      await _prefs?.remove(_kDefaultList);
    } else {
      await _prefs?.setInt(_kDefaultList, id);
    }
    state = state.copyWith(defaultListId: () => id);
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } on Object {
    prefs = null; // test host without an override — in-memory settings
  }
  return SettingsNotifier(prefs);
});
