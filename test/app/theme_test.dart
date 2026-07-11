import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tokri/app/theme/app_theme.dart';

void main() {
  test('light theme carries the warm bazaar palette', () {
    final theme = tokriTheme(Brightness.light);
    final scheme = theme.colorScheme;

    expect(scheme.brightness, Brightness.light);
    expect(scheme.primary, const Color(0xFFB8551F));
    expect(theme.scaffoldBackgroundColor, scheme.surface);
    // Ledgr lesson encoded: titles must clear the status bar.
    expect(theme.appBarTheme.toolbarHeight, 72);
    // No notched floating labels.
    expect(
      theme.inputDecorationTheme.floatingLabelBehavior,
      FloatingLabelBehavior.never,
    );
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Manrope');
  });

  test('dark theme is warm espresso, not pitch black', () {
    final theme = tokriTheme(Brightness.dark);
    final scheme = theme.colorScheme;

    expect(scheme.brightness, Brightness.dark);
    expect(scheme.surface, isNot(Colors.black));
    expect(scheme.primary, const Color(0xFFE58A55));
  });

  test('tokri semantic tokens differ per brightness', () {
    final light = tokriTheme(Brightness.light).colorScheme.tokri;
    final dark = tokriTheme(Brightness.dark).colorScheme.tokri;
    expect(light.success, isNot(dark.success));
    expect(light.heroGradient, hasLength(2));
    expect(
      light.copyWith(success: Colors.red).success,
      Colors.red,
    );
    expect(light.lerp(dark, 0.5), dark);
  });

  test('list accent seeds are stable and indexable', () {
    expect(kListAccents, hasLength(6));
    expect(kListAccents.first, const Color(0xFFB8551F));
  });
}
