import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive_scaffold.dart';
import '../../profile/pages/favorites_page.dart';
import '../../profile/pages/profile_page.dart';
import 'products_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const _destinations = [
    AdaptiveDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    AdaptiveDestination(
      icon: Icon(Icons.favorite_border),
      selectedIcon: Icon(Icons.favorite),
      label: 'Favorites',
    ),
    AdaptiveDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      selectedIndex: _index,
      onDestinationSelected: (i) {
        setState(() => _index = i);
        _pageController.animateToPage(
          i,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      destinations: _destinations,
      // ✅ PageView — allows horizontal swiping between tabs
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _index = i),
        children: const [
          ProductsPage(),
          FavoritesPage(),
          ProfilePage(),
        ],
      ),
    );
  }
}
