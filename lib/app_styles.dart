import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color background(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color text(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color secondaryText(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static const Color priceColor = Colors.redAccent;
}

class AppTextStyles {
  static TextStyle heading(BuildContext context) => GoogleFonts.notoSansMyanmar(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.text(context),
  );

  static TextStyle main(BuildContext context) => GoogleFonts.notoSansMyanmar(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.text(context),
  );

  static TextStyle category(BuildContext context) => GoogleFonts.notoSansMyanmar(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.text(context),
  );

  static TextStyle price() => GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.priceColor,
  );

  static TextStyle small(BuildContext context) => GoogleFonts.notoSansMyanmar(
    fontSize: 11,
    color: AppColors.secondaryText(context),
  );
}