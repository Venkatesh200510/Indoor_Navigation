import 'package:flutter/material.dart';

/// Central design tokens for the app. Swapping the palette / theme here
/// changes the whole app's look without touching any screen logic.
class AppColors {
  AppColors._();

  // Base surfaces
  static const bg = Color(0xFF070B16);
  static const bgAlt = Color(0xFF0E1526);
  static const surface = Color(0xFF141C30);
  static const surfaceAlt = Color(0xFF1B2540);
  static const outline = Color(0xFF283654);

  // Brand accents — mint + violet instead of the old flat cyan/blue
  static const mint = Color(0xFF2BF0B0);
  static const mintDim = Color(0xFF17A579);
  static const violet = Color(0xFF8B5CF6);
  static const violetDim = Color(0xFF5B3FA8);
  static const amber = Color(0xFFFFB020);
  static const danger = Color(0xFFFF5470);

  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFAEB9D4);
  static const textFaint = Color(0xFF6C7896);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mint, violet],
  );

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgAlt, bg],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.mint,
        secondary: AppColors.violet,
        surface: AppColors.surface,
        error: AppColors.danger,
        onPrimary: Colors.black,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.2,
        ),
        iconTheme: IconThemeData(color: AppColors.mint),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.mint,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          animationDuration: const Duration(milliseconds: 160),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.mint,
          side: const BorderSide(color: AppColors.mint),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.mint,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
