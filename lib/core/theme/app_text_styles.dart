import 'package:flutter/material.dart';

class AppTextStyles {

  static TextTheme textTheme(ColorScheme scheme) {
    return TextTheme(

      // 🔥 Page Heading (Product name)
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
        letterSpacing: -0.3,
      ),

      // 🔥 Section Title
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),

      // 🔥 Card Title (Brand / Model)
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),

      // 🔥 Body text
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface.withOpacity(0.85),
      ),

      // 🔥 Secondary text
      bodySmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: scheme.onSurface.withOpacity(0.6),
      ),

      // 🔥 Price style (important)
      labelLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),

      // 🔥 Caption / Meta
      labelSmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface.withOpacity(0.5),
      ),
    );
  }
}