import 'package:flutter/material.dart';

/// Visual identity: deep night background, glowing accent gradients,
/// rounded geometric type (Outfit) and a readable body face (Inter).
class AppColors {
  static const bgDark = Color(0xFF0B0C14);
  static const surfaceDark = Color(0xFF14162A);
  static const surface2Dark = Color(0xFF1C1F38);
  static const outlineDark = Color(0xFF2A2E4E);

  static const bgLight = Color(0xFFF6F5FB);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surface2Light = Color(0xFFEFEDF8);
  static const outlineLight = Color(0xFFE2DFF0);

  static const success = Color(0xFF34D399);
  static const flame = Color(0xFFFF8A3D);
  static const ice = Color(0xFF7DD3FC);
  static const gold = Color(0xFFFFC94D);
  static const danger = Color(0xFFFF5C7A);

  static const accents = <int>[
    0xFF7C5CFF, // violet
    0xFFFF5C8A, // pink
    0xFF22C3A6, // teal
    0xFF3D8BFF, // blue
    0xFFFF8A3D, // orange
    0xFFFFC94D, // gold
  ];

  /// Habit palette (vivid, readable on both themes).
  static const habitColors = <int>[
    0xFF7C5CFF,
    0xFF9D6BFF,
    0xFFFF5C8A,
    0xFFFF6B6B,
    0xFFFF8A3D,
    0xFFFFC94D,
    0xFFA3E635,
    0xFF34D399,
    0xFF22C3A6,
    0xFF38BDF8,
    0xFF3D8BFF,
    0xFF6366F1,
    0xFFE879F9,
    0xFFF472B6,
    0xFF94A3B8,
    0xFFB08968,
  ];
}

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get surface2 => isDark ? AppColors.surface2Dark : AppColors.surface2Light;
  Color get subtle => cs.onSurface.withValues(alpha: 0.6);
  Color get faint => cs.onSurface.withValues(alpha: 0.35);
}

LinearGradient accentGradient(Color c) => LinearGradient(
      colors: [c, Color.lerp(c, const Color(0xFFFF5C8A), 0.55)!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

LinearGradient habitGradient(Color c) => LinearGradient(
      colors: [c, Color.lerp(c, Colors.white, 0.18)!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

ThemeData buildTheme(Brightness b, Color accent) {
  final dark = b == Brightness.dark;
  final bg = dark ? AppColors.bgDark : AppColors.bgLight;
  final surface = dark ? AppColors.surfaceDark : AppColors.surfaceLight;
  final outline = dark ? AppColors.outlineDark : AppColors.outlineLight;
  final onSurface = dark ? const Color(0xFFF2F1FA) : const Color(0xFF15142B);

  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b).copyWith(
    primary: accent,
    onPrimary: Colors.white,
    secondary: const Color(0xFFFF5C8A),
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: dark ? AppColors.surface2Dark : AppColors.surface2Light,
    outline: outline,
    outlineVariant: outline,
    error: AppColors.danger,
  );

  const display = 'Outfit';
  const body = 'Inter';
  final base = ThemeData(brightness: b, useMaterial3: true).textTheme;
  final text = base
      .copyWith(
        displayLarge: base.displayLarge?.copyWith(fontFamily: display, fontWeight: FontWeight.w800, letterSpacing: -1.5),
        displayMedium: base.displayMedium?.copyWith(fontFamily: display, fontWeight: FontWeight.w800, letterSpacing: -1),
        displaySmall: base.displaySmall?.copyWith(fontFamily: display, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineLarge: base.headlineLarge?.copyWith(fontFamily: display, fontWeight: FontWeight.w700),
        headlineMedium: base.headlineMedium?.copyWith(fontFamily: display, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineSmall: base.headlineSmall?.copyWith(fontFamily: display, fontWeight: FontWeight.w700),
        titleLarge: base.titleLarge?.copyWith(fontFamily: display, fontWeight: FontWeight.w700),
        titleMedium: base.titleMedium?.copyWith(fontFamily: display, fontWeight: FontWeight.w600, fontSize: 17),
        titleSmall: base.titleSmall?.copyWith(fontFamily: display, fontWeight: FontWeight.w600),
        bodyLarge: base.bodyLarge?.copyWith(fontFamily: body),
        bodyMedium: base.bodyMedium?.copyWith(fontFamily: body),
        bodySmall: base.bodySmall?.copyWith(fontFamily: body),
        labelLarge: base.labelLarge?.copyWith(fontFamily: body, fontWeight: FontWeight.w600),
        labelMedium: base.labelMedium?.copyWith(fontFamily: body, fontWeight: FontWeight.w600),
        labelSmall: base.labelSmall?.copyWith(fontFamily: body, fontWeight: FontWeight.w600),
      )
      .apply(bodyColor: onSurface, displayColor: onSurface);

  final radius = BorderRadius.circular(18);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    canvasColor: bg,
    fontFamily: body,
    textTheme: text,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: outline)),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.surface2Dark : AppColors.surface2Light,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: accent, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.35)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: display, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: outline),
        textStyle: const TextStyle(fontFamily: display, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: const TextStyle(fontFamily: display, fontWeight: FontWeight.w600)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: outline),
      labelStyle: TextStyle(fontFamily: body, fontWeight: FontWeight.w600, color: onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: accent.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: body, fontSize: 12, fontWeight: FontWeight.w600, color: onSurface),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: accent.withValues(alpha: 0.18),
      selectedLabelTextStyle: TextStyle(fontFamily: body, fontWeight: FontWeight.w700, color: onSurface),
      unselectedLabelTextStyle: TextStyle(fontFamily: body, color: onSurface.withValues(alpha: 0.6)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? AppColors.surface2Dark : const Color(0xFF15142B),
      contentTextStyle: const TextStyle(fontFamily: body, color: Colors.white, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : null),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: accent, thumbColor: accent, inactiveTrackColor: outline),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
