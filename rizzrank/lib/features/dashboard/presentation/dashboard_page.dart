import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../auth/data/auth_service.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            // No profile found — sign out the stale session and go to login
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            });
            return const Center(child: CircularProgressIndicator());
          }

          final winRate = user.totalGames > 0
              ? (user.wins / user.totalGames * 100).toStringAsFixed(1)
              : '0.0';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primary, width: 2),
                          color: Colors.grey[800],
                        ),
                        child: const Icon(
                          LucideIcons.user,
                          size: 20,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'RizzRank',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Profile & Rank Hero
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withOpacity(0.15),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 128,
                        height: 128,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.primary, width: 4),
                          color: AppTheme.backgroundDark,
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, Color(0xFF60A5FA)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.diamond,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ELO: ${user.eloRating}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          user.rizzTitle.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Top 2% Worldwide',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'WINS',
                          value: '${user.wins}',
                          trend: '+5.2%',
                          trendColor: Colors.greenAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          label: 'LOSSES',
                          value: '${user.losses}',
                          trend: '-1.2%',
                          trendColor: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _WinRateCard(winRate: winRate)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Find Match Button
                  _FindMatchButton(),
                  const SizedBox(height: 24),

                  // Local Leaderboard Preview
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Local Leaderboard',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        _LeaderboardRow(
                          rank: 1,
                          name: 'ViperKing',
                          role: 'Grandmaster',
                          score: '2,140',
                          avatarSeed: 'Viper',
                        ),
                        Divider(
                          height: 1,
                          color: AppTheme.primary.withOpacity(0.1),
                        ),
                        _LeaderboardRow(
                          rank: 12,
                          name: user.displayName.isNotEmpty
                              ? user.displayName
                              : 'You',
                          role: user.rizzTitle,
                          score: '${user.eloRating}',
                          avatarSeed: 'You',
                          isActive: true,
                        ),
                        Divider(
                          height: 1,
                          color: AppTheme.primary.withOpacity(0.1),
                        ),
                        _LeaderboardRow(
                          rank: 13,
                          name: 'ShadowByte',
                          role: 'Diamond',
                          score: '1,432',
                          avatarSeed: 'Shadow',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  LucideIcons.alertTriangle,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading profile',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString().contains('permission-denied')
                      ? 'You don\'t have permission to access this profile. Try signing in again.'
                      : '$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.6)),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Sign Out & Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.trend,
    this.trendColor,
  });

  final String label;
  final String value;
  final String? trend;
  final Color? trendColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Text(
              trend!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: trendColor ?? Colors.white54,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WinRateCard extends StatelessWidget {
  const _WinRateCard({required this.winRate});
  final String winRate;

  @override
  Widget build(BuildContext context) {
    final rate = double.tryParse(winRate) ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WIN RATE',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$winRate%',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 4,
              backgroundColor: Colors.grey[700],
              valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindMatchButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/matchmaking'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppTheme.primary.withOpacity(0.4),
          border: Border.all(color: AppTheme.primary.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.2),
              blurRadius: 24,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.play, size: 32, color: Colors.white),
            const SizedBox(width: 16),
            Text(
              'FIND MATCH',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.role,
    required this.score,
    required this.avatarSeed,
    this.isActive = false,
  });

  final int rank;
  final String name;
  final String role;
  final String score;
  final String avatarSeed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: isActive
          ? BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              border: const Border(
                left: BorderSide(color: AppTheme.primary, width: 4),
                right: BorderSide(color: AppTheme.primary, width: 4),
              ),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: isActive ? Colors.white : AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[800],
            backgroundImage: NetworkImage(
              'https://api.dicebear.com/7.x/avataaars/png?seed=$avatarSeed',
            ),
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
          Text(
            score,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
