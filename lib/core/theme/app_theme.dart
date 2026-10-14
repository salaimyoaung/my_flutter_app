import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandSeed,
      brightness: brightness,
    );

    final scheme = baseScheme.copyWith(
      surface: isLight ? AppColors.lightSurface : AppColors.darkSurface,
      surfaceContainerHighest: isLight
          ? AppColors.lightSurfaceVariant
          : AppColors.darkSurfaceVariant,
      outline: isLight ? AppColors.lightOutline : AppColors.darkOutline,
      error: AppColors.error,
      shadow: isLight ? AppColors.lightShadow : AppColors.darkShadow,
      onSurface:
      isLight ? AppColors.lightTextPrimary : AppColors.darkTextPrimary,
      onSurfaceVariant: isLight
          ? AppColors.lightTextSecondary
          : AppColors.darkTextSecondary,
    );

    final textTheme = AppTextStyles.textTheme(scheme);

    // ✅ AppBar uses BrandAppBar gradient — theme sets transparent so
    //    BrandAppBar's flexibleSpace gradient shows through cleanly.
    //    Regular AppBar (non-BrandAppBar) falls back to surface color.
    final appBarTheme = AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: AppTextStyles.textTheme(scheme).titleLarge?.copyWith(
        color: Colors.white,
      ),
      // ✅ Status bar icons white on all BrandAppBar screens
      systemOverlayStyle: isLight
          ? SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      )
          : SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: appBarTheme,

      // ── Card ────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        shadowColor: scheme.shadow.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? scheme.primary.withValues(alpha: 0.18)
                : scheme.primary.withValues(alpha: 0.14),
          ),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
      ),

      // ── Input ───────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      // ── Elevated Button ─────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),

      // ── Outlined Button ─────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── Text Button ─────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),

      // ── Navigation Bar ──────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.26),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.all(textTheme.labelSmall),
      ),

      // ── Progress ────────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
    );
  }

  static final light = _buildTheme(Brightness.light);
  static final dark = _buildTheme(Brightness.dark);
}