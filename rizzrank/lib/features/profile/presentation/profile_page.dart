import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Not signed in'));

          final winRate = user.totalGames > 0
              ? (user.wins / user.totalGames * 100).toStringAsFixed(1)
              : '0.0';

          return CustomScrollView(
            slivers: [
              // Sticky header
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => context.go('/dashboard'),
                          icon: const Icon(LucideIcons.arrowLeft, size: 24),
                        ),
                        Text(
                          'Player Profile',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: () => context.push('/preferences'),
                          icon: const Icon(LucideIcons.settings, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Avatar with gradient ring
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 128,
                            height: 128,
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppTheme.primary, Color(0xFFA78BFA)],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.backgroundDark,
                              ),
                              padding: const EdgeInsets.all(4),
                              child: CircleAvatar(
                                radius: 56,
                                backgroundColor: Colors.grey[800],
                                child: Icon(
                                  LucideIcons.user,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user.rizzTitle,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: const BoxDecoration(
                              color: Colors.white38,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            'ELO Rating: ${user.eloRating}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Stats grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatBox(label: 'Wins', value: '${user.wins}'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatBox(label: 'Win Rate', value: '$winRate%'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatBox(
                          label: 'Peak',
                          value: '${user.eloRating}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Match History Preview
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              'MATCH HISTORY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _HistoryRow(
                        win: true,
                        name: 'Seraphina AI',
                        elo: '+24',
                        time: '2 hours ago',
                      ),
                      const SizedBox(height: 8),
                      _HistoryRow(
                        win: false,
                        name: 'Rogue-Bot',
                        elo: '-18',
                        time: '5 hours ago',
                      ),
                      const SizedBox(height: 8),
                      _HistoryRow(
                        win: true,
                        name: 'Nexus Unit',
                        elo: '+12',
                        time: 'Yesterday',
                      ),
                    ],
                  ),
                ),
              ),

              // Logout button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1634),
                            title: const Text(
                              'Log Out',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Are you sure you want to log out?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text(
                                  'Log Out',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(authServiceProvider).signOut();
                        }
                      },
                      icon: const Icon(LucideIcons.logOut, size: 18),
                      label: const Text(
                        'LOG OUT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.win,
    required this.name,
    required this.elo,
    required this.time,
  });

  final bool win;
  final String name;
  final String elo;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: win
                  ? Colors.greenAccent.withOpacity(0.2)
                  : Colors.redAccent.withOpacity(0.2),
            ),
            child: Icon(
              win ? LucideIcons.check : LucideIcons.x,
              size: 16,
              color: win ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${win ? 'Win' : 'Loss'} vs. $name',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$time \u2022 $elo ELO',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ],
            ),
          ),
          Text(
            win ? 'VICTORY' : 'DEFEAT',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: win ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}
