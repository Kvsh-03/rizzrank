import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/models/ai_model.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/theme/app_theme.dart';

class ChallengersPage extends ConsumerWidget {
  const ChallengersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiModelsAsync = ref.watch(aiModelsProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'AI Challengers',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an opponent to test your rizz',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: aiModelsAsync.when(
                  data: (models) {
                    if (models.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.bot, size: 64, color: Colors.white.withOpacity(0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'No AI agents configured yet.',
                              style: TextStyle(color: Colors.white.withOpacity(0.5)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add agents to the ai_models collection in Firestore.',
                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: models.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final agent = models[index];
                        return _ChallengerCard(
                          agent: agent,
                          onTap: () => context.go('/matchmaking'),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Tap a challenger to start a match.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
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

class _ChallengerCard extends StatelessWidget {
  const _ChallengerCard({
    required this.agent,
    required this.onTap,
  });

  final AIModel agent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.3),
            width: 2,
          ),
          color: AppTheme.primary.withOpacity(0.05),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      agent.role,
                      style: TextStyle(
                        color: AppTheme.primary.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (agent.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        agent.description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.2),
                ),
                child: const Icon(LucideIcons.chevronRight, color: AppTheme.primary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (agent.avatarUrl.isNotEmpty) {
      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
          image: DecorationImage(
            image: NetworkImage(agent.avatarUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppTheme.primary.withOpacity(0.2),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
      ),
      child: Icon(LucideIcons.bot, color: AppTheme.primary.withOpacity(0.6), size: 32),
    );
  }
}
