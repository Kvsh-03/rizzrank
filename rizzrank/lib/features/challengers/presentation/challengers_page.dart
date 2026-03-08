import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/providers/app_state_providers.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';

class ChallengersPage extends ConsumerWidget {
  const ChallengersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedChallengerIdProvider);

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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose an opponent to test your rizz',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ref
                    .watch(aiModelsProvider)
                    .when(
                      data: (models) {
                        if (models.isEmpty) {
                          return const Center(
                            child: Text(
                              'No challengers available.',
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: models.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final char = models[index];
                            final id = char['id'] as String;
                            final name =
                                char['name'] as String? ?? 'AI Opponent';
                            final role =
                                char['role'] as String? ?? 'Challenger';
                            final description =
                                char['description'] as String? ?? '';
                            final avatarUrl =
                                char['avatar_url'] as String? ??
                                char['avatarUrl'] as String? ??
                                '';

                            final isSelected = selectedId == id;

                            return _ChallengerCard(
                              name: name,
                              role: role,
                              description: description,
                              avatarUrl: avatarUrl,
                              isSelected: isSelected,
                              onTap: () {
                                ref
                                        .read(
                                          selectedChallengerIdProvider.notifier,
                                        )
                                        .state =
                                    id;
                                context.go('/matchmaking');
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primary,
                        ),
                      ),
                      error: (e, st) => Center(child: Text('Error: $e')),
                    ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Tap a challenger to start a match, or select one on the Home tab and use Find Match.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                    ),
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
    required this.name,
    required this.role,
    required this.description,
    required this.avatarUrl,
    required this.isSelected,
    required this.onTap,
  });

  final String name;
  final String role;
  final String description;
  final String avatarUrl;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : Colors.white.withOpacity(0.1),
            width: 2,
          ),
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 2,
                  ),
                  image: DecorationImage(
                    image: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : const NetworkImage('https://via.placeholder.com/150'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: TextStyle(
                        color: AppTheme.primary.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                child: const Icon(
                  LucideIcons.chevronRight,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
