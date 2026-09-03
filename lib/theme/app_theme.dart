import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFFF4F4F5);
  static const background = Color(0xFF09090B);
  static const surface = Color(0xFF111113);
  static const surfaceRaised = Color(0xFF18181B);
  static const border = Color(0xFF29292E);
  static const muted = Color(0xFFA1A1AA);

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: seed,
      onPrimary: Color(0xFF09090B),
      secondary: Color(0xFFB7B7C0),
      onSecondary: Color(0xFF09090B),
      surface: surface,
      onSurface: Color(0xFFF7F7F8),
      error: Color(0xFFFF6B6B),
      onError: Colors.black,
    );

    OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: color),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        displaySmall: TextStyle(letterSpacing: -1.4, fontWeight: FontWeight.w800),
        headlineLarge: TextStyle(letterSpacing: -1.0, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(letterSpacing: -.7, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(letterSpacing: -.4, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: Color(0xFFC7C7CE), height: 1.35),
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
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
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
        foregroundColor: Color(0xFF09090B),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        hintStyle: const TextStyle(color: Color(0xFF777780)),
        labelStyle: const TextStyle(color: muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(const Color(0xFF6B6B73)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          backgroundColor: seed,
          foregroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          foregroundColor: const Color(0xFFF4F4F5),
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceRaised,
        selectedColor: Colors.white.withValues(alpha: .12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF121214),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF121214),
        modalBackgroundColor: Color(0xFF121214),
        showDragHandle: true,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: seed,
        linearTrackColor: Color(0xFF26262B),
        circularTrackColor: Color(0xFF26262B),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      }),
    );
  }
}
