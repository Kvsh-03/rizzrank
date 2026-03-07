import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index, BuildContext context) {
    if (index == 2) {
      // The center FAB handles Matchmaking. Don't change nav shell branch.
      context.go('/matchmaking');
      return;
    }
    
    // Map bottom nav items to branches:
    // 0: Home (branch 0)
    // 1: Rank (branch 1)
    // 2: Matchmaking (FAB - skipped above)
    // 3: History (branch 2)
    // 4: Profile (branch 3)
    final branchIndex = index > 2 ? index - 1 : index;
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current index calculation mapping branch back to bottom nav index
    final branchIndex = navigationShell.currentIndex;
    final currentIndex = branchIndex >= 2 ? branchIndex + 1 : branchIndex;

    return Scaffold(
      body: navigationShell,
      extendBody: true, // Needed for transparent/floating BottomAppBar
      bottomNavigationBar: BottomAppBar(
        color: AppTheme.backgroundDark.withOpacity(0.8),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBarItem(
              icon: LucideIcons.home,
              label: 'HOME',
              isSelected: currentIndex == 0,
              onTap: () => _onTap(0, context),
            ),
            _NavBarItem(
              icon: LucideIcons.trophy,
              label: 'RANK',
              isSelected: currentIndex == 1,
              onTap: () => _onTap(1, context),
            ),
            const SizedBox(width: 48), // Space for FAB
            _NavBarItem(
              icon: LucideIcons.messageSquare,
              label: 'HISTORY',
              isSelected: currentIndex == 3,
              onTap: () => _onTap(3, context),
            ),
            _NavBarItem(
              icon: LucideIcons.user,
              label: 'PROFILE',
              isSelected: currentIndex == 4,
              onTap: () => _onTap(4, context),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onTap(2, context),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(LucideIcons.plus, size: 32),
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
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
