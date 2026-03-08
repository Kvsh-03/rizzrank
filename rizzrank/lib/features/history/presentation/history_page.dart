import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/models/firestore_match_model.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(matchHistoryProvider);
    final currentUser = ref.watch(currentUserProvider).value;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Match History',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: matchesAsync.when(
                  data: (matches) {
                    if (matches.isEmpty) {
                      return const Center(
                        child: Text(
                          'No matches played yet.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        return _MatchCard(
                          match: match,
                          currentUserId: currentUser?.uid ?? '',
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  ),
                  error: (e, st) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.currentUserId});

  final FirestoreMatch match;
  final String currentUserId;

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    // If it was a solo vs AI, pull info from aiTraits or use fallback.
    // If it was a multiplayer match, we could fetch opponent's profile, but for now fallback is fine.
    final opponentName = match.aiTraits['name'] ?? 'Opponent';
    final isWin = match.winnerId == currentUserId;
    final isLoss = match.winnerId != null && match.winnerId != currentUserId;

    final resultStr = isWin
        ? 'WIN'
        : isLoss
        ? 'LOSS'
        : 'TIE';
    final resultColor = isWin
        ? Colors.greenAccent
        : isLoss
        ? Colors.redAccent
        : Colors.grey;
    final resultIcon = isWin
        ? LucideIcons.trophy
        : isLoss
        ? LucideIcons.xCircle
        : LucideIcons.minusCircle;

    final myEloChange = match.eloChange[currentUserId] ?? 0;
    final eloStr = myEloChange > 0 ? '+$myEloChange' : '$myEloChange';
    final eloColor = myEloChange > 0
        ? Colors.greenAccent
        : myEloChange < 0
        ? Colors.redAccent
        : Colors.grey;

    final dateStr = match.createdAt != null
        ? _formatDate(match.createdAt!)
        : 'Unknown Date';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Avatar with result overlay
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.grey[800],
                    child: const Center(
                      child: Icon(
                        LucideIcons.user,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(resultIcon, color: resultColor, size: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        opponentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      resultStr,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: resultColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$eloStr ELO',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: eloColor,
            ),
          ),
        ],
      ),
    );
  }
}
