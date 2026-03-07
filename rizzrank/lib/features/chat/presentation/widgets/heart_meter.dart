import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/glass_card.dart';

class HeartMeter extends StatelessWidget {
  const HeartMeter({super.key, required this.score});

  final int score;

  String _getLabel() {
    if (score < 25) return 'Stranger';
    if (score < 50) return 'Intrigued';
    if (score < 75) return 'Charmed';
    if (score < 100) return 'Smitten';
    return 'In Love';
  }

  @override
  Widget build(BuildContext context) {
    // Cap visual display at 100%, though actual score can exceed
    final percentage = (score / 100).clamp(0.0, 1.0);

    return GlassCard(
      isPrimary: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.heart, color: Colors.pinkAccent, size: 16),
                  const SizedBox(width: 8),
                  const Text('Affection Level', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
                ),
                child: Text('$score%', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 12,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(6),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: percentage),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Container(
                          width: constraints.maxWidth * value,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, Colors.pinkAccent],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.5),
                                blurRadius: 8,
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Stranger', style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              Text(_getLabel().toUpperCase(), style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const Text('Obsessed', style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ],
          ),
        ],
      ),
    );
  }
}
