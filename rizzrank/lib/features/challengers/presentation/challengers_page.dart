import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/data/ai_characters.dart';
import '../../../core/providers/app_state_providers.dart';
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
                child: ListView.separated(
                  itemCount: kAICharacters.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final char = kAICharacters[index];
                    final isSelected = selectedId == char.id;
                    return _ChallengerCard(
                      character: char,
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(selectedChallengerIdProvider.notifier).state = char.id;
                        context.go('/matchmaking');
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Tap a challenger to start a match, or select one on the Home tab and use Find Match.',
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
    required this.character,
    required this.isSelected,
    required this.onTap,
  });

  final AICharacter character;
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
            color: isSelected ? AppTheme.primary : Colors.white.withOpacity(0.1),
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
                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                  image: DecorationImage(
                    image: NetworkImage(character.avatarUrl),
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
                      character.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      character.role,
                      style: TextStyle(
                        color: AppTheme.primary.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      character.description,
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
                child: const Icon(LucideIcons.chevronRight, color: AppTheme.primary, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
