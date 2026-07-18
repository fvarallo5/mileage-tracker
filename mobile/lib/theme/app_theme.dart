import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF0A0E14);
  static const bgElevated = Color(0xFF0F1419);
  static const surface = Color(0xFF151D2B);
  static const surface2 = Color(0xFF1C2738);
  static const surface3 = Color(0xFF243044);
  static const border = Color(0xFF2A3A52);
  static const text = Color(0xFFEEF2F7);
  static const textMuted = Color(0xFF8B9CB3);
  static const accent = Color(0xFF3B9EFF);
  static const accentDark = Color(0xFF2563A8);
  static const green = Color(0xFF34D399);
  static const greenDark = Color(0xFF065F46);
  static const amber = Color(0xFFFBBF24);
  static const red = Color(0xFFF87171);

  // Light mode: white cards, navy text (readable contrast)
  static const lightBg = Color(0xFFEEF2F7);
  static const lightBgElevated = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFFFFFFF);
  static const lightSurface3 = Color(0xFFF1F5F9);
  static const lightBorder = Color(0xFFCBD5E1);
  static const lightText = Color(0xFF0F172A); // navy
  static const lightTextMuted = Color(0xFF475569);

  static const uber = Color(0xFF000000);
  static const doordash = Color(0xFFFF3008);
  static const lyft = Color(0xFFFF00BF);
  static const instacart = Color(0xFF43B02A);

  static Color sourceColor(String source) => switch (source) {
        'uber' => const Color(0xFF5E5E5E),
        'doordash' => doordash,
        'lyft' => lyft,
        'instacart' => instacart,
        'gps' => accent,
        'autodetect' => amber,
        _ => surface3,
      };
}

class AppSpacing {
  static const page = 20.0;
  static const card = 16.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 24.0;
}

class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
}

/// Semantic surfaces that flip with light/dark so widgets stay readable.
class ThemePalette {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surface3;
  final Color border;
  final Color text;
  final Color textMuted;
  final bool isLight;

  const ThemePalette({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.isLight,
  });

  static const dark = ThemePalette(
    bg: AppColors.bg,
    surface: AppColors.surface,
    surface2: AppColors.surface2,
    surface3: AppColors.surface3,
    border: AppColors.border,
    text: AppColors.text,
    textMuted: AppColors.textMuted,
    isLight: false,
  );

  static const light = ThemePalette(
    bg: AppColors.lightBg,
    surface: AppColors.lightSurface,
    surface2: AppColors.lightSurface2,
    surface3: AppColors.lightSurface3,
    border: AppColors.lightBorder,
    text: AppColors.lightText,
    textMuted: AppColors.lightTextMuted,
    isLight: true,
  );

  static ThemePalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light ? light : dark;
  }
}

extension ThemePaletteX on BuildContext {
  ThemePalette get palette => ThemePalette.of(this);
}

TextTheme _buildTextTheme({
  required Brightness brightness,
  required Color text,
  required Color textMuted,
}) {
  final base = GoogleFonts.dmSansTextTheme(
    brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme,
  );
  return base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: text,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: text,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: text,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: text,
    ),
    bodyMedium: base.bodyMedium?.copyWith(color: textMuted),
    bodyLarge: base.bodyLarge?.copyWith(color: text),
    labelSmall: base.labelSmall?.copyWith(
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
      color: textMuted,
    ),
  );
}

/// Dark theme (default / legacy).
ThemeData buildAppTheme() => buildDarkAppTheme();

ThemeData buildDarkAppTheme() {
  return _buildTheme(
    brightness: Brightness.dark,
    bg: AppColors.bg,
    bgElevated: AppColors.bgElevated,
    surface: AppColors.surface,
    surface2: AppColors.surface2,
    surface3: AppColors.surface3,
    border: AppColors.border,
    text: AppColors.text,
    textMuted: AppColors.textMuted,
    systemOverlay: SystemUiOverlayStyle.light,
  );
}

ThemeData buildLightAppTheme() {
  return _buildTheme(
    brightness: Brightness.light,
    bg: AppColors.lightBg,
    bgElevated: AppColors.lightBgElevated,
    surface: AppColors.lightSurface,
    surface2: AppColors.lightSurface2,
    surface3: AppColors.lightSurface3,
    border: AppColors.lightBorder,
    text: AppColors.lightText,
    textMuted: AppColors.lightTextMuted,
    systemOverlay: SystemUiOverlayStyle.dark,
  );
}

ThemeData _buildTheme({
  required Brightness brightness,
  required Color bg,
  required Color bgElevated,
  required Color surface,
  required Color surface2,
  required Color surface3,
  required Color border,
  required Color text,
  required Color textMuted,
  required SystemUiOverlayStyle systemOverlay,
}) {
  final textTheme = _buildTextTheme(
    brightness: brightness,
    text: text,
    textMuted: textMuted,
  );
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: bg,
    textTheme: textTheme,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.green,
      onSecondary: Colors.white,
      error: AppColors.red,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      outline: border,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
      systemOverlayStyle: systemOverlay,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bgElevated,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.accent : textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.accent : textMuted,
          size: 22,
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      // Light: pure white fields; dark: elevated navy.
      fillColor: isDark ? surface2 : surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      labelStyle: TextStyle(color: textMuted),
      hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? surface3 : const Color(0xFF1E293B),
      contentTextStyle: const TextStyle(color: AppColors.text),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accent;
        return textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.accent.withValues(alpha: 0.4);
        }
        return surface3;
      }),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: textMuted,
      textColor: text,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface2,
      selectedColor: AppColors.accent.withValues(alpha: 0.2),
      labelStyle: const TextStyle(fontSize: 13),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent.withValues(alpha: 0.2);
          }
          return surface2;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return textMuted;
        }),
        side: WidgetStateProperty.all(BorderSide(color: border)),
      ),
    ),
  );
}
