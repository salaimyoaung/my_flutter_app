import 'package:flutter/material.dart';

/// Breakpoints used throughout the app.
/// Adjust these values to match your design system.
class AppBreakpoints {
  /// Phone — up to 599px
  static const double phone = 600;

  /// Tablet — 600px to 1023px
  static const double tablet = 1024;

  /// Desktop — 1024px and above
  static const double desktop = 1024;
}

/// Screen type based on current width.
enum ScreenType { phone, tablet, desktop }

/// Responsive utility — access from anywhere with `context.responsive`.
extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  ScreenType get screenType {
    if (screenWidth >= AppBreakpoints.desktop) return ScreenType.desktop;
    if (screenWidth >= AppBreakpoints.phone) return ScreenType.tablet;
    return ScreenType.phone;
  }

  bool get isPhone => screenType == ScreenType.phone;
  bool get isTablet => screenType == ScreenType.tablet;
  bool get isDesktop => screenType == ScreenType.desktop;
  bool get isTabletOrDesktop => !isPhone;

  /// Returns a value based on screen type.
  /// Usage: `context.responsive(phone: 12.0, tablet: 16.0, desktop: 20.0)`
  T responsive<T>({
    required T phone,
    T? tablet,
    T? desktop,
  }) {
    switch (screenType) {
      case ScreenType.desktop:
        return desktop ?? tablet ?? phone;
      case ScreenType.tablet:
        return tablet ?? phone;
      case ScreenType.phone:
        return phone;
    }
  }
}

/// Responsive padding — more spacious on larger screens.
class AppPadding {
  static EdgeInsets page(BuildContext context) {
    return EdgeInsets.all(context.responsive(
      phone: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    ));
  }

  static EdgeInsets horizontal(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: context.responsive(
        phone: 16.0,
        tablet: 24.0,
        desktop: 32.0,
      ),
    );
  }

  static EdgeInsets card(BuildContext context) {
    return EdgeInsets.all(context.responsive(
      phone: 12.0,
      tablet: 16.0,
      desktop: 20.0,
    ));
  }
}

/// Responsive grid column count.
class AppGrid {
  /// Product grid columns
  static int productColumns(BuildContext context) {
    return context.responsive(phone: 2, tablet: 3, desktop: 4);
  }

  /// Form max width — constrain wide forms on tablets/desktops
  static double formMaxWidth(BuildContext context) {
    return context.responsive(
      phone: double.infinity,
      tablet: 600.0,
      desktop: 720.0,
    );
  }
}

/// Wraps content with a max-width constraint for tablet/desktop.
/// Use around form pages, dialogs, and detail pages.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 720,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? AppPadding.page(context),
          child: child,
        ),
      ),
    );
  }
}

/// Responsive layout builder — shows different widgets per screen type.
///
/// Usage:
/// ```dart
/// ResponsiveLayout(
///   phone: PhoneView(),
///   tablet: TabletView(),   // optional — falls back to phone
///   desktop: DesktopView(), // optional — falls back to tablet
/// )
/// ```
class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return context.responsive(
      phone: phone,
      tablet: tablet,
      desktop: desktop,
    );
  }
}

/// Responsive SliverGrid delegate — adjusts columns automatically.
SliverGridDelegate productGridDelegate(BuildContext context) {
  final columns = AppGrid.productColumns(context);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: context.responsive(phone: 12.0, tablet: 16.0),
    crossAxisSpacing: context.responsive(phone: 12.0, tablet: 16.0),
    childAspectRatio: context.responsive(
      phone: 0.65,
      tablet: 0.70,
      desktop: 0.72,
    ),
  );
}