import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/data/ai_characters.dart';
import '../../../core/theme/app_theme.dart';

class _MatchHistoryEntry {
  final int id;
  final String characterId;
  final String result;
  final String score;
  final String date;
  final String eloChange;

  const _MatchHistoryEntry({
    required this.id,
    required this.characterId,
    required this.result,
    required this.score,
    required this.date,
    required this.eloChange,
  });
}

const _mockHistory = [
  _MatchHistoryEntry(id: 1, characterId: 'luna', result: 'WIN', score: '2-1', date: '2 hours ago', eloChange: '+25'),
  _MatchHistoryEntry(id: 2, characterId: 'atlas', result: 'LOSS', score: '0-3', date: '1 day ago', eloChange: '-12'),
  _MatchHistoryEntry(id: 3, characterId: 'zephyr', result: 'WIN', score: '3-0', date: '2 days ago', eloChange: '+18'),
];

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.history, color: AppTheme.primary, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _mockHistory.isEmpty
                    ? const Center(
                        child: Text('No matches played yet.', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.separated(
                        itemCount: _mockHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final match = _mockHistory[index];
                          final char = getCharacterById(match.characterId);
                          final isWin = match.result == 'WIN';
                          return _MatchCard(match: match, character: char, isWin: isWin);
                        },
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
  const _MatchCard({
    required this.match,
    required this.character,
    required this.isWin,
  });

  final _MatchHistoryEntry match;
  final AICharacter character;
  final bool isWin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          // Character avatar with result overlay
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    character.avatarUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[800],
                      child: const Icon(LucideIcons.user, color: Colors.white54),
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
                      match.result,
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
                      match.date,
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Score: ${match.score}',
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
            '${match.eloChange} ELO',
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
}
