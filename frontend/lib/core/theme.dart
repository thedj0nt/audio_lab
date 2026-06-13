import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

class AppThemeColors {
  final Color background;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const AppThemeColors({
    required this.background,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  static const dark = AppThemeColors(
    background: Color(0xFF0A0A0C),
    card: Color(0xFF121215),
    border: Color(0xFF1E1E22),
    textPrimary: Colors.white,
    textSecondary: Color(0xFF94A1B2),
    accent: Color(0xFFFF3E3E),
  );

  static const light = AppThemeColors(
    background: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE5E5EA),
    textPrimary: Color(0xFF1C1C1E),
    textSecondary: Color(0xFF636366),
    accent: Color(0xFFFF3E3E),
  );
}

final themeColorsProvider = Provider<AppThemeColors>((ref) {
  final mode = ref.watch(themeModeProvider);
  return mode == ThemeMode.light ? AppThemeColors.light : AppThemeColors.dark;
});

final darkThemeData = ThemeData.dark().copyWith(
  scaffoldBackgroundColor: AppThemeColors.dark.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppThemeColors.dark.accent,
    brightness: Brightness.dark,
    primary: AppThemeColors.dark.accent,
    secondary: AppThemeColors.dark.accent,
    surface: AppThemeColors.dark.card,
  ),
  cardTheme: CardThemeData(
    color: AppThemeColors.dark.card,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppThemeColors.dark.border),
    ),
  ),
);

final lightThemeData = ThemeData.light().copyWith(
  scaffoldBackgroundColor: AppThemeColors.light.background,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppThemeColors.light.accent,
    brightness: Brightness.light,
    primary: AppThemeColors.light.accent,
    secondary: AppThemeColors.light.accent,
    surface: AppThemeColors.light.card,
  ),
  cardTheme: CardThemeData(
    color: AppThemeColors.light.card,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(color: AppThemeColors.light.border),
    ),
  ),
);
