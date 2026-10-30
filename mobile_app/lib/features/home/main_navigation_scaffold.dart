import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../artifacts/artifact.dart';
import '../artifacts/artifact_list_page.dart';
import 'favorites_page.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'profile_page.dart';

class MainNavigationScaffold extends StatefulWidget {
  const MainNavigationScaffold({
    super.key,
    required this.onLocaleChanged,
    this.onLogout,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback? onLogout;

  @override
  State<MainNavigationScaffold> createState() => _MainNavigationScaffoldState();
}

class _MainNavigationScaffoldState extends State<MainNavigationScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final colorScheme = Theme.of(context).colorScheme;

    final List<Widget> pages = [
      const HomePage(),
      const MapPage(),
      ArtifactListPage(
        catalog: ArtifactCatalog(),
        onLocaleChanged: widget.onLocaleChanged,
      ),
      const FavoritesPage(),
      ProfilePage(
        onLocaleChanged: widget.onLocaleChanged,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: colorScheme.surface,
        indicatorColor: HeritagePalette.primaryNavy.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: HeritagePalette.primaryNavy),
            label: isEn ? 'Home' : 'Trang chủ',
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: HeritagePalette.primaryNavy),
            label: isEn ? 'Map' : 'Bản đồ',
          ),
          NavigationDestination(
            icon: const Icon(Icons.museum_outlined),
            selectedIcon: Icon(
              Icons.museum,
              color: HeritagePalette.primaryNavy,
            ),
            label: isEn ? 'Artifacts' : 'Hiện vật',
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            selectedIcon: Icon(
              Icons.favorite,
              color: HeritagePalette.primaryNavy,
            ),
            label: isEn ? 'Favorites' : 'Yêu thích',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: Icon(
              Icons.person,
              color: HeritagePalette.primaryNavy,
            ),
            label: isEn ? 'Profile' : 'Cá nhân',
          ),
        ],
      ),
    );
  }
}
