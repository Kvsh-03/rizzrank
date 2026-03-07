import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/data/ai_characters.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/matchmaking_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';

final matchmakingServiceProvider = Provider<MatchmakingService>((ref) {
  return MatchmakingService(firestore: ref.watch(firestoreProvider));
});

class MatchmakingPage extends ConsumerStatefulWidget {
  const MatchmakingPage({super.key});

  @override
  ConsumerState<MatchmakingPage> createState() => _MatchmakingPageState();
}

class _MatchmakingPageState extends ConsumerState<MatchmakingPage> with TickerProviderStateMixin {
  late AnimationController _spinnerController;
  late AnimationController _pulseController;
  int _waitTimer = 12;
  Timer? _timer;
  bool _isMatched = false;
  String? _opponentName;

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _waitTimer > 0) {
        setState(() => _waitTimer--);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _joinQueue();
    });
  }

  Future<void> _joinQueue() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final service = ref.read(matchmakingServiceProvider);
    
    // First, try to find a match or join queue
    final match = await service.findMatch(user);
    if (match != null) {
      _handleMatchFound(match.matchId, 'Challenger');
    }
  }

  void _handleMatchFound(String matchId, String opponentName) {
    if (!mounted || _isMatched) return;
    setState(() {
      _isMatched = true;
      _opponentName = opponentName;
    });

    // Pause for dramatic effect, then navigate to chat
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go('/chat/$matchId');
    });
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Listen to matches collection for our match
    ref.listen(matchmakingServiceProvider.select((s) => s.watchForMatch(user.uid)), (prev, next) {
      next.listen((match) {
        if (match != null && mounted && !_isMatched) {
          _handleMatchFound(match.matchId, 'Challenger');
        }
      });
    });

    final champion = kAICharacters.first;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ref.read(matchmakingServiceProvider).leaveQueue(user.uid);
                      context.pop();
                    },
                    icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Matchmaking',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48), // Balance for back button
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated spinner with rotating border
                    SizedBox(
                      width: 192,
                      height: 192,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _spinnerController,
                            builder: (_, child) => Transform.rotate(
                              angle: _spinnerController.value * 2 * 3.14159,
                              child: child,
                            ),
                            child: SizedBox(
                              width: 192,
                              height: 192,
                              child: CircularProgressIndicator(
                                value: 0.25,
                                strokeWidth: 4,
                                color: AppTheme.primary,
                                backgroundColor: AppTheme.primary.withOpacity(0.1),
                              ),
                            ),
                          ),
                          Container(
                            width: 128,
                            height: 128,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withOpacity(0.1),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                            ),
                            child: Icon(LucideIcons.search, size: 48, color: AppTheme.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _isMatched ? 'Match Found!' : 'Finding an opponent...',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (!_isMatched)
                      Text(
                        'Estimated wait: ${_waitTimer}s',
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                      ),
                    
                    const SizedBox(height: 48),

                    // Champion Card
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('YOUR CHAMPION', style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                Text('${champion.name} AI', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                                Text(champion.role, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                                  child: const Text('LVL 24', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 2),
                              image: DecorationImage(image: NetworkImage(champion.avatarUrl), fit: BoxFit.cover),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 16,
                        child: Text('VS', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900)),
                      ),
                    ),

                    // Opponent Card with pulsing dots
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[900]?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(LucideIcons.helpCircle, color: AppTheme.primary.withOpacity(0.3), size: 48),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'OPPONENT',
                                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _opponentName ?? 'Searching...',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                if (!_isMatched) ...[
                                  const SizedBox(height: 8),
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, _) {
                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(3, (i) {
                                          final delay = i * 0.2;
                                          final t = (_pulseController.value - delay).clamp(0.0, 1.0);
                                          return Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.symmetric(horizontal: 2),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppTheme.primary.withOpacity(0.3 + 0.7 * t),
                                            ),
                                          );
                                        }),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(matchmakingServiceProvider).leaveQueue(user.uid);
                    context.pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CANCEL MATCHMAKING', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
