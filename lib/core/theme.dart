import 'package:flutter/material.dart';

/// Pluck design language: ink-dark surfaces, one electric-lime accent,
/// generous radii, tight type. Part of the AlphaOmega Studio family.
class Brand {
  static const lime = Color(0xFFC6F135);
  static const ink = Color(0xFF0E1013);
  static const surface = Color(0xFF16191E);
  static const surfaceHigh = Color(0xFF1E2229);
  static const outline = Color(0xFF2B313A);
  static const ok = Color(0xFF4ADE80);
  static const warn = Color(0xFFFBBF24);
  static const bad = Color(0xFFF87171);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.lime,
    brightness: b,
  ).copyWith(
    primary: dark ? Brand.lime : const Color(0xFF4D6A00),
    onPrimary: dark ? const Color(0xFF1B2600) : Colors.white,
    surface: dark ? Brand.ink : const Color(0xFFF7F8F4),
    surfaceContainerLow: dark ? Brand.surface : const Color(0xFFFFFFFF),
    surfaceContainer: dark ? Brand.surface : const Color(0xFFFFFFFF),
    surfaceContainerHigh: dark ? Brand.surfaceHigh : const Color(0xFFEFF1EA),
    outlineVariant: dark ? Brand.outline : const Color(0xFFDDE1D6),
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final t = base.textTheme;

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: t.copyWith(
      headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primary.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.outlineVariant,
      linearMinHeight: 6,
    ),
  );
}
