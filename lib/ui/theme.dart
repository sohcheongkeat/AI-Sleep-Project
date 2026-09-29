import 'package:flutter/material.dart';

/// Dark-only for v1: the app is used in a dark bedroom.
/// Chart colours come from a palette validated for this dark surface.
class AppColors {
  static const surface = Color(0xFF1A1A19);
  static const surfaceRaised = Color(0xFF252524);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFC3C2B7);
  static const textMuted = Color(0xFF8A897F);
  static const grid = Color(0xFF3A3A38);
  static const series = Color(0xFF3987E5);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.series,
    brightness: Brightness.dark,
  ).copyWith(surface: AppColors.surface, onSurface: AppColors.textPrimary);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surface,
    cardTheme: const CardThemeData(color: AppColors.surfaceRaised, margin: EdgeInsets.zero),
    useMaterial3: true,
  );
}
