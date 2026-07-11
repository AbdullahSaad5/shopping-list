import 'package:flutter/material.dart';

/// Spacing constants — the only spacing values used in layouts.
abstract final class Gaps {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double page = 16;
}

/// The six accent seeds a list can pick from (`ShoppingLists.colorSeed` is an
/// index into this). Indexed access must stay stable across releases.
const kListAccents = <Color>[
  Color(0xFFB8551F), // clay
  Color(0xFFC99A2E), // saffron
  Color(0xFF5B8C5A), // leaf
  Color(0xFF2A7F7F), // teal
  Color(0xFF7D5BA6), // plum
  Color(0xFF5C6B73), // slate
];

/// Tokri-specific tokens on top of the Material scheme.
@immutable
class TokriColors extends ThemeExtension<TokriColors> {
  const TokriColors({
    required this.success,
    required this.warning,
    required this.heroGradient,
  });

  final Color success;
  final Color warning;
  final List<Color> heroGradient;

  @override
  TokriColors copyWith({
    Color? success,
    Color? warning,
    List<Color>? heroGradient,
  }) =>
      TokriColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        heroGradient: heroGradient ?? this.heroGradient,
      );

  @override
  TokriColors lerp(TokriColors? other, double t) => other ?? this;
}

extension TokriColorsX on ColorScheme {
  TokriColors get tokri => brightness == Brightness.dark
      ? const TokriColors(
          success: Color(0xFF8BC98A),
          warning: Color(0xFFE5B95C),
          heroGradient: [Color(0xFFE58A55), Color(0xFFB8551F)],
        )
      : const TokriColors(
          success: Color(0xFF3E7C3D),
          warning: Color(0xFFA97B13),
          heroGradient: [Color(0xFFD97B45), Color(0xFFB8551F)],
        );
}

/// Warm "bazaar basket" palette: clay + wheat on cream; espresso dark.
/// (Design-identity ticket #3 may refine hues; tokens stay the same.)
ThemeData tokriTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final scheme = isDark
      ? const ColorScheme.dark(
          primary: Color(0xFFE58A55),
          onPrimary: Color(0xFF2B1608),
          primaryContainer: Color(0xFF7A3A16),
          onPrimaryContainer: Color(0xFFFFDBC7),
          secondary: Color(0xFFE3B04B),
          onSecondary: Color(0xFF2B2008),
          tertiary: Color(0xFF8BC98A),
          onTertiary: Color(0xFF10290F),
          surface: Color(0xFF191210),
          onSurface: Color(0xFFF0E4DA),
          onSurfaceVariant: Color(0xFFB5A295),
          surfaceContainerLowest: Color(0xFF140E0C),
          surfaceContainerLow: Color(0xFF201714),
          surfaceContainer: Color(0xFF261C18),
          surfaceContainerHigh: Color(0xFF2D221D),
          surfaceContainerHighest: Color(0xFF352A24),
          outline: Color(0xFF6B5B50),
          outlineVariant: Color(0xFF3C2F28),
          error: Color(0xFFE57373),
          onError: Color(0xFF330B0B),
        )
      : const ColorScheme.light(
          primary: Color(0xFFB8551F),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFFFDBC7),
          onPrimaryContainer: Color(0xFF3A1A07),
          secondary: Color(0xFFA97B13),
          onSecondary: Colors.white,
          tertiary: Color(0xFF3E7C3D),
          onTertiary: Colors.white,
          surface: Color(0xFFFBF7F1),
          onSurface: Color(0xFF241A12),
          onSurfaceVariant: Color(0xFF6F6156),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Color(0xFFFFFCF8),
          surfaceContainer: Color(0xFFF3ECE3),
          surfaceContainerHigh: Color(0xFFEDE4D8),
          surfaceContainerHighest: Color(0xFFE6DACB),
          outline: Color(0xFF83756A),
          outlineVariant: Color(0xFFD8CCBE),
          error: Color(0xFFB3261E),
          onError: Colors.white,
        );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
  );
  final textTheme = base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    // M5 polish: fade-forwards route transitions app-wide + predictive back.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      centerTitle: false,
      // Ledgr lesson: default 56 leaves the title hugging the status bar.
      toolbarHeight: 72,
      titleTextStyle: textTheme.headlineSmall?.copyWith(
        fontFamily: 'Manrope',
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: textTheme.labelLarge?.copyWith(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      // Ledgr lesson: no notched floating labels — labels live above fields.
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
