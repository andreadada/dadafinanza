import 'package:flutter/material.dart';

@immutable
class FinanceColors extends ThemeExtension<FinanceColors> {
  const FinanceColors({
    required this.positive,
    required this.negative,
    required this.warning,
    required this.neutral,
  });

  final Color positive;
  final Color negative;
  final Color warning;
  final Color neutral;

  @override
  FinanceColors copyWith({
    Color? positive,
    Color? negative,
    Color? warning,
    Color? neutral,
  }) =>
      FinanceColors(
        positive: positive ?? this.positive,
        negative: negative ?? this.negative,
        warning: warning ?? this.warning,
        neutral: neutral ?? this.neutral,
      );

  @override
  FinanceColors lerp(covariant FinanceColors? other, double t) {
    if (other == null) return this;
    return FinanceColors(
      positive: Color.lerp(positive, other.positive, t)!,
      negative: Color.lerp(negative, other.negative, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

class AppTheme {
  static const muted = Color(0xFF71717A);
  static const surface = Colors.transparent;
  static const border = Colors.transparent;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF09090B) : const Color(0xFFFAFAFA);
    final raised = dark ? const Color(0xFF17171A) : const Color(0xFFF0F0F2);
    final hairline = dark ? const Color(0xFF2A2A2E) : const Color(0xFFE4E4E7);
    final onSurface = dark ? const Color(0xFFF7F7F8) : const Color(0xFF18181B);
    final secondaryText = dark ? const Color(0xFFA7A7B0) : const Color(0xFF65656F);

    final scheme = ColorScheme.fromSeed(
      seedColor: dark ? const Color(0xFFF5F5F5) : const Color(0xFF27272A),
      brightness: brightness,
      surface: background,
      error: dark ? const Color(0xFFFF7474) : const Color(0xFFB42318),
    ).copyWith(
      primary: dark ? const Color(0xFFF5F5F5) : const Color(0xFF27272A),
      onPrimary: dark ? const Color(0xFF09090B) : Colors.white,
      surface: background,
      surfaceContainer: raised,
      surfaceContainerHighest:
          dark ? const Color(0xFF222226) : const Color(0xFFE8E8EB),
      onSurface: onSurface,
      outlineVariant: hairline,
    );

    final underline = UnderlineInputBorder(
      borderSide: BorderSide(color: hairline),
    );
    final focusedUnderline = UnderlineInputBorder(
      borderSide: BorderSide(color: scheme.primary, width: 1.5),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      dividerColor: hairline,
      visualDensity: VisualDensity.standard,
      extensions: [
        FinanceColors(
          positive: dark ? const Color(0xFF82AFFF) : const Color(0xFF2C63B7),
          negative: dark ? const Color(0xFFFF8585) : const Color(0xFFB42318),
          warning: dark ? const Color(0xFFFFC96B) : const Color(0xFF9A6700),
          neutral: secondaryText,
        ),
      ],
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: onSurface,
          letterSpacing: -1.4,
          fontWeight: FontWeight.w800,
        ),
        headlineLarge: TextStyle(
          color: onSurface,
          letterSpacing: -1,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: TextStyle(
          color: onSurface,
          letterSpacing: -.7,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: onSurface,
          letterSpacing: -.4,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        bodyMedium: TextStyle(color: secondaryText, height: 1.4),
        labelLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        titleTextStyle: TextStyle(
          color: onSurface,
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
        backgroundColor: background,
        indicatorColor: scheme.primary.withValues(alpha: .09),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? onSurface : secondaryText,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        hintStyle: TextStyle(color: secondaryText.withValues(alpha: .8)),
        labelStyle: TextStyle(color: secondaryText),
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 13),
        border: underline,
        enabledBorder: underline,
        focusedBorder: focusedUnderline,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          side: BorderSide.none,
          backgroundColor: scheme.primary.withValues(alpha: .06),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primary.withValues(alpha: .09),
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
                ? scheme.primary.withValues(alpha: .09)
                : Colors.transparent,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: raised,
        modalBackgroundColor: raised,
        showDragHandle: true,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: .09),
        circularTrackColor: scheme.primary.withValues(alpha: .09),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.android: PredictiveBackPageTransitionsBuilder()},
      ),
    );
  }
}

extension FinanceThemeContext on BuildContext {
  FinanceColors get financeColors =>
      Theme.of(this).extension<FinanceColors>()!;
}
