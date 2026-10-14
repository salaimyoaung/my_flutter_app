import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/app_responsive.dart';

/// ─── AdaptiveScaffold ────────────────────────────────────────────────────────
/// Phone   (< 600)  : BottomNavigationBar
/// Tablet  (600–1023): NavigationRail (left, compact)
/// Desktop (≥ 1024) : Permanent NavigationDrawer (left, extended)
class AdaptiveScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveDestination> destinations;
  final Widget body;

  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final w = context.screenWidth;

    if (w >= AppBreakpoints.lg) {
      return _DesktopLayout(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
        body: body,
      );
    } else if (w >= AppBreakpoints.md) {
      return _TabletLayout(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
        body: body,
      );
    } else {
      return _MobileLayout(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
        body: body,
      );
    }
  }
}

/// ─── Data class ─────────────────────────────────────────────────────────────
class AdaptiveDestination {
  final Widget icon;
  final Widget selectedIcon;
  final String label;

  const AdaptiveDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

// ─── Mobile ──────────────────────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveDestination> destinations;
  final Widget body;

  const _MobileLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations
            .map((d) => NavigationDestination(
                  icon: d.icon,
                  selectedIcon: d.selectedIcon,
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

// ─── Tablet ───────────────────────────────────────────────────────────────────
class _TabletLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveDestination> destinations;
  final Widget body;

  const _TabletLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.brandGradientDark.colors.first
          : AppColors.brandGradientLight.colors.first,
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                right: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              extended: false,
              minWidth: 72,
              backgroundColor: Colors.transparent,
              useIndicator: true,
              indicatorColor: scheme.primary.withValues(alpha: 0.18),
              selectedIconTheme: IconThemeData(color: scheme.primary),
              unselectedIconTheme: IconThemeData(
                color: scheme.onSurfaceVariant,
              ),
              labelType: NavigationRailLabelType.selected,
              selectedLabelTextStyle: TextStyle(
                color: scheme.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
              ),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: _BrandMark(isDark: isDark),
              ),
              destinations: destinations
                  .map((d) => NavigationRailDestination(
                        icon: d.icon,
                        selectedIcon: d.selectedIcon,
                        label: Text(d.label),
                      ))
                  .toList(),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ─── Desktop ──────────────────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveDestination> destinations;
  final Widget body;

  const _DesktopLayout({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 220,
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppColors.brandGradientDark
                  : AppColors.brandGradientLight,
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: Row(
                      children: [
                        _BrandMark(isDark: isDark, size: 36),
                        const SizedBox(width: 10),
                        const Text(
                          'PhoneMarket',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...destinations.asMap().entries.map((e) {
                    final i = e.key;
                    final d = e.value;
                    final isSelected = i == selectedIndex;

                    return _DrawerItem(
                      icon: isSelected ? d.selectedIcon : d.icon,
                      label: d.label,
                      isSelected: isSelected,
                      onTap: () => onDestinationSelected(i),
                    );
                  }),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ─── Drawer item ─────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            IconTheme(
              data: const IconThemeData(color: Colors.white, size: 22),
              child: icon,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Brand mark (circle logo) ─────────────────────────────────────────────────
class _BrandMark extends StatelessWidget {
  final bool isDark;
  final double size;

  const _BrandMark({required this.isDark, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isDark ? null : AppColors.brandGradientLight,
        color: isDark ? Colors.white.withValues(alpha: 0.22) : null,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.phone_android_rounded,
        color: Colors.white,
        size: size * 0.62,
      ),
    );
  }
}
