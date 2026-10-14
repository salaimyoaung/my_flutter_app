import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

/// App-wide branded AppBar with gradient background.
/// Use this instead of plain AppBar on every page for visual consistency.
///
/// - [title] — plain string title (most pages)
/// - [titleWidget] — custom widget title (e.g. chat page with avatar + online dot)
///   When both are given, [titleWidget] takes priority.
/// Tablet/large screen: automatically taller (56 → 64px) via [preferredSize].
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget; // ✅ optional — overrides [title] when provided
  final Widget? leading;
  final double? leadingWidth; // ✅ widen leading area (e.g. for brand name)
  final double? titleSpacing; // ✅ override default 16dp spacing around title
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom; // e.g. TabBar

  const BrandAppBar({
    super.key,
    this.title = '',
    this.titleWidget,
    this.leading,
    this.leadingWidth,
    this.titleSpacing,
    this.actions,
    this.bottom,
  });

  // ✅ Responsive height — taller on tablets for better touch targets
  static double _barHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 ? 64.0 : kToolbarHeight; // 56px phone, 64px tablet+
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final barHeight = _barHeight(context);

    // ✅ Auto back button — Builder ဖြင့် GoRouter state ကို reactively ဖတ်
    // (build() မှာ တစ်ကြိမ်တည်း calculate လုပ်ရင် route stack ပြောင်းမှ stale ဖြစ်)
    final effectiveLeading = leading ??
        Builder(builder: (ctx) {
          if (!ctx.canPop()) return const SizedBox.shrink();
          return IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (ctx.canPop()) ctx.pop();
            },
          );
        });

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,

      // ✅ White icons + transparent status bar on all screens
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // iOS
      ),

      // ✅ Gradient background — same on every page
      flexibleSpace: _GradientBackground(isDark: isDark),

      toolbarHeight: barHeight,

      centerTitle: false,

      // ✅ titleWidget takes priority over string title
      title: titleWidget ??
          (title.isEmpty
              ? null
              : Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize:
                        MediaQuery.of(context).size.width >= 600 ? 22 : 20,
                  ),
                )),

      titleSpacing: titleSpacing,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      leading: effectiveLeading,
      leadingWidth: leadingWidth,
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize {
    // preferredSize is called before build so we can't access context here.
    // We return a fixed size; the actual toolbarHeight override in build()
    // handles the responsive height visually.
    final tabBarHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + tabBarHeight);
  }
}

/// Gradient background shared across all BrandAppBar instances.
/// Extracted so it's easy to update the brand gradient in one place.
class _GradientBackground extends StatelessWidget {
  final bool isDark;

  const _GradientBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? AppColors.brandGradientDark
            : AppColors.brandGradientLight,
      ),
      // ✅ Subtle top-to-transparent overlay for depth
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: isDark ? 0.12 : 0.0),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}