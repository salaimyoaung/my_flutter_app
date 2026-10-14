  import 'package:flutter/material.dart';

  class AppColors {
    static const Color brandSeed =  Color(0xFF22C55E);
    static const Color success = Color(0xFF20C997);
    static const Color warning = Color(0xFFFFB020);
    static const Color error = Color(0xFFFF3B30);
    static const Color info = Color(0xFF2F80ED);
    static const LinearGradient brandGradientLight = LinearGradient(
      colors: [
        Color(0xFF22C55E),
        Color(0xFF4ADE80),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    static const LinearGradient brandGradientDark = LinearGradient(
      colors: [
        Color(0xFF14532D),
        Color(0xFF0F172A),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    static const Color darkTextPrimary = Color(0xFFFFFFFF);
    static const Color darkTextSecondary = Color(0xFFB3B8C5);
    static const Color lightBackground = Color(0xFFF3F5F7);
    static const Color lightSurface = Color(0xFFFFFFFF);
    static const Color lightSurfaceVariant = Color(0xFFF1F1F6);
    static const Color lightOutline = Color(0xFFE2E3E8);
    static const Color lightShadow = Color(0xFF0E0F14);


    static const Color darkBackground = Color(0xFF0E0F14);
    static const Color darkSurface = Color(0xFF17181D);
    static const Color darkSurfaceVariant = Color(0xFF1F2027);
    static const Color darkOutline = Color(0xFF2A2B33);
    static const Color darkShadow = Color(0xFF0E0F14);
    static const Color lightTextPrimary = Color(0xFF111827);
    static const Color lightTextSecondary = Color(0xFF6B7280);
  }
