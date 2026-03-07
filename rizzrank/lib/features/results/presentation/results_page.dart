import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key, required this.matchId, required this.outcome});

  final String matchId;
  final String outcome; // "victory" or "defeat"

  @override
  Widget build(BuildContext context) {
    final isVictory = outcome == 'victory';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.go('/dashboard'),
        ),
        title: Text(
          'MATCH SUMMARY',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontStyle: FontStyle.italic,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Victory/Defeat Hero Card with trophy decoration
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.2),
                          blurRadius: 24,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            'AI VERDICT',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: -1,
                                  color: Colors.white,
                                ),
                            children: [
                              TextSpan(text: isVictory ? 'AI CHOSE ' : 'NOT THIS '),
                              TextSpan(
                                text: isVictory ? 'YOU!' : 'TIME',
                                style: TextStyle(color: isVictory ? AppTheme.primary : Colors.white38),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isVictory ? 'VICTORY' : 'DEFEAT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: isVictory ? AppTheme.primary : Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isVictory
                                ? Colors.greenAccent.withOpacity(0.2)
                                : Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isVictory
                                  ? Colors.greenAccent.withOpacity(0.3)
                                  : Colors.redAccent.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVictory ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                                color: isVictory ? Colors.greenAccent : Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isVictory ? '+25 ELO RATING' : '-12 ELO RATING',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isVictory ? Colors.greenAccent : Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Trophy decoration
                  if (isVictory)
                    Positioned(
                      top: -16,
                      right: -8,
                      child: Transform.rotate(
                        angle: 0.2,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: AppTheme.glowPrimary,
                          ),
                          child: const Icon(LucideIcons.trophy, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Affection Scores
              Text(
                'AFFECTION SCORES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ScoreCard(label: 'You', score: 85, trend: '+13%', isActive: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ScoreCard(label: 'Opponent', score: 72, trend: '-15%', isActive: false),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    _StatRow(
                      icon: LucideIcons.sparkles,
                      label: 'Rizz Accuracy',
                      sublabel: 'AI confidence score',
                      value: '98.2%',
                    ),
                    Divider(height: 24, color: AppTheme.primary.withOpacity(0.1)),
                    _StatRow(
                      icon: LucideIcons.timer,
                      label: 'Match Duration',
                      sublabel: 'Response speed avg',
                      value: '4m 12s',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/matchmaking'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 6,
                    shadowColor: AppTheme.primary.withOpacity(0.3),
                  ),
                  child: const Text(
                    'PLAY AGAIN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[850] ?? Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'BACK TO DASHBOARD',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.score,
    required this.trend,
    required this.isActive,
  });

  final String label;
  final int score;
  final String trend;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primary.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppTheme.primary.withOpacity(0.4) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$score',
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 6),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: trend.startsWith('+') ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: Colors.grey[800],
              valueColor: AlwaysStoppedAnimation(
                isActive ? AppTheme.primary : Colors.grey[600]!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.primary.withOpacity(0.2),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(sublabel, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4))),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }
}
