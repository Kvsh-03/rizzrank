import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class _LeaderboardPlayer {
  final String username;
  final int elo;
  final int wins;
  final String avatarSeed;

  const _LeaderboardPlayer({
    required this.username,
    required this.elo,
    required this.wins,
    required this.avatarSeed,
  });

  String get avatarUrl =>
      'https://api.dicebear.com/7.x/avataaars/png?seed=$avatarSeed';
}

const _mockPlayers = [
  _LeaderboardPlayer(
    username: 'ViperKing',
    elo: 2140,
    wins: 89,
    avatarSeed: 'Viper',
  ),
  _LeaderboardPlayer(
    username: 'NeonQueen',
    elo: 2012,
    wins: 76,
    avatarSeed: 'Neon',
  ),
  _LeaderboardPlayer(
    username: 'RizzLord99',
    elo: 1950,
    wins: 71,
    avatarSeed: 'Rizz',
  ),
  _LeaderboardPlayer(
    username: 'CharmMaster',
    elo: 1890,
    wins: 65,
    avatarSeed: 'Charm',
  ),
  _LeaderboardPlayer(
    username: 'SilverTongue',
    elo: 1820,
    wins: 58,
    avatarSeed: 'Silver',
  ),
  _LeaderboardPlayer(
    username: 'ShadowByte',
    elo: 1780,
    wins: 52,
    avatarSeed: 'Shadow',
  ),
  _LeaderboardPlayer(
    username: 'FlirtBot',
    elo: 1720,
    wins: 47,
    avatarSeed: 'Flirt',
  ),
  _LeaderboardPlayer(
    username: 'DigitalDon',
    elo: 1680,
    wins: 43,
    avatarSeed: 'Digital',
  ),
];

class LeaderboardPage extends ConsumerWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.trophy,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'RizzRank',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Title section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Global Leaderboard',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Competing for the title of the ultimate Rizz Master.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),

          // Top 3 Podium
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Row(
                children: List.generate(
                  3.clamp(0, _mockPlayers.length),
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _PodiumCard(player: _mockPlayers[i], rank: i + 1),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Remaining players list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    // Table header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 32,
                            child: Text('RANK', style: _headerStyle),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text('USERNAME', style: _headerStyle),
                          ),
                          const SizedBox(
                            width: 80,
                            child: Text(
                              'RATING',
                              style: _headerStyle,
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(
                            width: 60,
                            child: Text(
                              'WINS',
                              style: _headerStyle,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    ...List.generate(_mockPlayers.length - 3, (i) {
                      final player = _mockPlayers[i + 3];
                      final rank = i + 4;
                      return _RankRow(player: player, rank: rank);
                    }),
                    // View full rankings
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'View Full Rankings',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            LucideIcons.arrowRight,
                            color: AppTheme.primary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.bold,
  letterSpacing: 2,
  color: Colors.white38,
);

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({required this.player, required this.rank});

  final _LeaderboardPlayer player;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final colors = [
      (
        border: const Color(0xFFEAB308),
        bg: const Color(0xFFEAB308).withOpacity(0.1),
      ),
      (
        border: const Color(0xFF94A3B8),
        bg: const Color(0xFF94A3B8).withOpacity(0.1),
      ),
      (
        border: const Color(0xFF92400E),
        bg: const Color(0xFF92400E).withOpacity(0.1),
      ),
    ];
    final c = colors[rank - 1];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        // Top colored border
      ),
      child: Column(
        children: [
          // Rank badge
          Transform.translate(
            offset: const Offset(0, -8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                rank == 1 ? '#1 CHAMPION' : '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.border, width: 3),
            ),
            child: ClipOval(
              child: Image.network(
                player.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[800],
                  child: const Icon(LucideIcons.user, color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            player.username,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${player.elo} ELO',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Wins: ${player.wins}',
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.5,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.player, required this.rank});

  final _LeaderboardPlayer player;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[800],
            backgroundImage: NetworkImage(player.avatarUrl),
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player.username,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${player.elo}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${player.wins}',
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
