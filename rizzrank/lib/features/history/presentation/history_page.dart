import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/models/ai_model.dart';
import '../../../core/models/firestore_match_model.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/match_providers.dart';
import '../../../core/theme/app_theme.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) {
      return const Scaffold(
        body: Center(child: Text('Not signed in', style: TextStyle(color: Colors.white54))),
      );
    }

    final historyAsync = ref.watch(
      matchHistoryStreamProvider(authUser.uid),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Match History',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: historyAsync.when(
                  data: (matches) {
                    if (matches.isEmpty) {
                      return const Center(
                        child: Text('No matches played yet.', style: TextStyle(color: Colors.white54)),
                      );
                    }
                    return ListView.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        final isWin = match.winnerId == authUser.uid;
                        final eloChange = match.eloChange[authUser.uid] ?? 0;
                        final eloStr = eloChange >= 0 ? '+$eloChange' : '$eloChange';
                        return _MatchCard(
                          match: match,
                          isWin: isWin,
                          eloChange: eloStr,
                          authUid: authUser.uid,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatchCard extends ConsumerWidget {
  const _MatchCard({
    required this.match,
    required this.isWin,
    required this.eloChange,
    required this.authUid,
  });

  final FirestoreMatch match;
  final bool isWin;
  final String eloChange;
  final String authUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiModelAsync = ref.watch(
      aiModelByIdProvider(match.aiCharacterId ?? 'unknown'),
    );

    return aiModelAsync.when(
      data: (agent) => _buildCard(context, agent),
      loading: () => _buildCard(context, AIModel.placeholder(match.aiCharacterId ?? 'unknown')),
      error: (_, __) => _buildCard(context, AIModel.placeholder(match.aiCharacterId ?? 'unknown')),
    );
  }

  Widget _buildCard(BuildContext context, AIModel character) {
    final dateStr = match.createdAt != null
        ? _formatDate(match.createdAt!)
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              children: [
                character.avatarUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          character.avatarUrl,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                        ),
                      )
                    : _avatarPlaceholder(),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Icon(
                        isWin ? LucideIcons.trophy : LucideIcons.xCircle,
                        color: isWin ? Colors.greenAccent : Colors.redAccent,
                        size: 24,
                      ),
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
                    Text(
                      character.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      isWin ? 'WIN' : 'LOSS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isWin ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 12, color: Colors.white.withOpacity(0.4)),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '$eloChange ELO',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
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
            '$eloChange ELO',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isWin ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Icon(LucideIcons.user, color: Colors.white54),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
