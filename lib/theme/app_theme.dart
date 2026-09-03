import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFFF5F5F5);
  static const background = Color(0xFF09090B);

  // Intentionally equal to the page background: layout hierarchy comes from
  // spacing and typography, not nested cards and artificial depth.
  static const surface = background;
  static const surfaceRaised = Color(0xFF17171A);
  static const border = Colors.transparent;
  static const hairline = Color(0xFF2A2A2E);
  static const muted = Color(0xFFA7A7B0);

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: seed,
      onPrimary: background,
      secondary: Color(0xFFD4D4D8),
      onSecondary: background,
      surface: background,
      onSurface: Color(0xFFF7F7F8),
      error: Color(0xFFFF7474),
      onError: Colors.black,
    );

    const underline = UnderlineInputBorder(
      borderSide: BorderSide(color: hairline),
    );
    const focusedUnderline = UnderlineInputBorder(
      borderSide: BorderSide(color: Color(0xFFF5F5F5), width: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: hairline,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        displaySmall: TextStyle(letterSpacing: -1.4, fontWeight: FontWeight.w800),
        headlineLarge: TextStyle(letterSpacing: -1, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(letterSpacing: -.7, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(letterSpacing: -.4, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: Color(0xFFD0D0D5), height: 1.4),
        labelLarge: TextStyle(fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFFF7F7F8),
        titleTextStyle: TextStyle(
          color: Color(0xFFF7F7F8),
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
        ),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: const Color(0xFF0D0D0F),
        indicatorColor: Colors.white.withValues(alpha: .10),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? const Color(0xFFF7F7F8)
                : muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: seed,
        foregroundColor: background,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        hintStyle: TextStyle(color: Color(0xFF777780)),
        labelStyle: TextStyle(color: muted),
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 13),
        border: underline,
        enabledBorder: underline,
        focusedBorder: focusedUnderline,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: seed,
          foregroundColor: background,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: const Color(0xFFF4F4F5),
          side: BorderSide.none,
          backgroundColor: Colors.white.withValues(alpha: .06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: const Color(0xFFF4F4F5),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: Colors.white.withValues(alpha: .10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: const WidgetStatePropertyAll(BorderSide.none),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white.withValues(alpha: .12)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFFF7F7F8)
                : muted,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF121214),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF121214),
        modalBackgroundColor: Color(0xFF121214),
        showDragHandle: true,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: seed,
        linearTrackColor: Color(0xFF25252A),
        circularTrackColor: Color(0xFF25252A),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      }),
    );
  }
}
