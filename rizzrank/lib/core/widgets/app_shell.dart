import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundDark.withOpacity(0.9),
          border: Border(
            top: BorderSide(color: AppTheme.primary.withOpacity(0.1)),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: LucideIcons.home,
                  label: 'HOME',
                  isSelected: currentIndex == 0,
                  onTap: () => _onTap(0),
                ),
                _NavBarItem(
                  icon: LucideIcons.trophy,
                  label: 'RANK',
                  isSelected: currentIndex == 1,
                  onTap: () => _onTap(1),
                ),
                _NavBarItem(
                  icon: LucideIcons.bot,
                  label: 'CHALLENGERS',
                  isSelected: currentIndex == 2,
                  onTap: () => _onTap(2),
                ),
                _NavBarItem(
                  icon: LucideIcons.history,
                  label: 'HISTORY',
                  isSelected: currentIndex == 3,
                  onTap: () => _onTap(3),
                ),
                _NavBarItem(
                  icon: LucideIcons.user,
                  label: 'PROFILE',
                  isSelected: currentIndex == 4,
                  onTap: () => _onTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.primary : Colors.white54;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
