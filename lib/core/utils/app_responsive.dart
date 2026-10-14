import 'package:flutter/material.dart';

/// ─── Breakpoints ────────────────────────────────────────────────────────────
/// small phone  : < 360
/// phone        : 360 – 599
/// tablet       : 600 – 1023
/// desktop/web  : ≥ 1024
class AppBreakpoints {
  AppBreakpoints._();

  static const double sm = 360.0;    // small phone
  static const double md = 600.0;    // tablet start
  static const double lg = 1024.0;   // desktop / web start

  /// Max readable content width on large screens
  static const double maxContent = 1200.0;

  /// Max form / auth page width (login, signup, etc.)
  static const double maxForm = 480.0;
}

/// ─── BuildContext extension ─────────────────────────────────────────────────
extension AppResponsive on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  bool get isSmallPhone => screenWidth < AppBreakpoints.sm;
  bool get isMobile     => screenWidth < AppBreakpoints.md;
  bool get isTablet     => screenWidth >= AppBreakpoints.md && screenWidth < AppBreakpoints.lg;
  bool get isDesktop    => screenWidth >= AppBreakpoints.lg;

  // ── Grid columns for brand/product grids ──────────────────────────────────
  // small phone: 2, phone: 2, tablet: 3, desktop: 4
  int get brandGridColumns {
    final w = screenWidth;
    if (w >= AppBreakpoints.lg) return 4;
    if (w >= AppBreakpoints.md) return 3;
    return 2;
  }

  // ── Horizontal page padding ──────────────────────────────────────────────
  double get hPadding {
    final w = screenWidth;
    if (w >= AppBreakpoints.lg) return 32.0;
    if (w >= AppBreakpoints.md) return 24.0;
    if (w >= AppBreakpoints.sm) return 16.0;
    return 12.0;
  }

  // ── Adaptive spacing ────────────────────────────────────────────────────
  double get spacingMd {
    if (isDesktop) return 20.0;
    if (isTablet)  return 16.0;
    return 12.0;
  }

  // ── Font scale for hero text ─────────────────────────────────────────────
  double get fontScale {
    if (isDesktop) return 1.15;
    if (isTablet)  return 1.05;
    return 1.0;
  }

  // ── T helper: pick value based on screen size ──────────────────────────
  T responsive<T>({required T mobile, T? tablet, T? desktop}) {
    if (isDesktop && desktop != null) return desktop;
    if (isTablet  && tablet  != null) return tablet;
    return mobile;
  }
}

/// ─── MaxWidthBox ─────────────────────────────────────────────────────────────
/// Constrains child to maxWidth and centers it — use on all page bodies
/// so content doesn't stretch unbounded on wide screens.
class MaxWidthBox extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const MaxWidthBox({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContent,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget w = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    );
    if (padding != null) w = Padding(padding: padding!, child: w);
    return Align(alignment: Alignment.topCenter, child: w);
  }
}
