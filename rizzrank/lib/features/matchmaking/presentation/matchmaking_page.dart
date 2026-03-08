import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/data/ai_characters.dart';
import '../../../core/models/firestore_match_model.dart';
import '../../../core/providers/app_state_providers.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_theme.dart';

class MatchmakingPage extends ConsumerStatefulWidget {
  const MatchmakingPage({super.key});

  @override
  ConsumerState<MatchmakingPage> createState() => _MatchmakingPageState();
}

class _MatchmakingPageState extends ConsumerState<MatchmakingPage>
    with TickerProviderStateMixin {
  late AnimationController _spinnerController;
  late AnimationController _pulseController;
  int _waitTimer = 0;
  Timer? _countdownTimer;
  StreamSubscription<FirestoreMatch?>? _matchSub;
  bool _searching = true;
  String? _errorMessage;

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

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _searching) {
        setState(() => _waitTimer++);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _startMatchmaking());
  }

  Future<void> _startMatchmaking() async {
    final matchmakingService = ref.read(matchmakingServiceProvider);
    final authUser = ref.read(authStateProvider).value;
    if (authUser == null) {
      setState(() {
        _errorMessage = 'Not signed in';
        _searching = false;
      });
      return;
    }

    try {
      final match = await matchmakingService.findMatch();

      if (!mounted) return;

      if (match != null && match.matchId.isNotEmpty) {
        _navigateToMatch(match.matchId);
        return;
      }

      // Queued -- listen for pairing by another player
      _matchSub = matchmakingService
          .watchForMatch(authUser.uid)
          .listen((match) {
        if (match != null && match.matchId.isNotEmpty && match.status == 'active') {
          _navigateToMatch(match.matchId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Matchmaking failed: $e';
        _searching = false;
      });
    }
  }

  void _navigateToMatch(String matchId) {
    _matchSub?.cancel();
    if (mounted) {
      context.go('/chat/$matchId');
    }
  }

  Future<void> _cancelMatchmaking() async {
    _matchSub?.cancel();
    try {
      await ref.read(matchmakingServiceProvider).leaveQueue();
    } catch (_) {}
    if (mounted) context.go('/dashboard');
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    _matchSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedChallengerIdProvider);
    final champion = selectedId != null
        ? getCharacterById(selectedId)
        : kAICharacters.first;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _cancelMatchmaking,
                    icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Matchmaking',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_errorMessage != null) ...[
                      Icon(LucideIcons.alertCircle,
                          color: Colors.redAccent, size: 64),
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _searching = true;
                          });
                          _startMatchmaking();
                        },
                        child: const Text('Retry'),
                      ),
                    ] else ...[
                      // Animated spinner
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
                                  backgroundColor:
                                      AppTheme.primary.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.primary.withOpacity(0.1),
                                border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.3)),
                              ),
                              child: const Icon(LucideIcons.search,
                                  size: 48, color: AppTheme.primary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Finding an opponent...',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Searching for ${_waitTimer}s',
                        style: TextStyle(
                            color: AppTheme.primary.withOpacity(0.7),
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),

                      const SizedBox(height: 48),

                      // Champion Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('YOUR CHAMPION',
                                      style: TextStyle(
                                          color: AppTheme.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5)),
                                  Text('${champion.name} AI',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900)),
                                  Text(champion.role,
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 14)),
                                ],
                              ),
                            ),
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.4),
                                    width: 2),
                                image: DecorationImage(
                                    image: NetworkImage(champion.avatarUrl),
                                    fit: BoxFit.cover),
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
                          child: Text('VS',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ),

                      // Opponent Card with pulsing dots
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[900]?.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppTheme.primary.withOpacity(0.2)),
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
                              child: Icon(LucideIcons.helpCircle,
                                  color: AppTheme.primary.withOpacity(0.3),
                                  size: 48),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'OPPONENT',
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.3),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Searching...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, _) {
                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: List.generate(3, (i) {
                                          final delay = i * 0.2;
                                          final t =
                                              (_pulseController.value - delay)
                                                  .clamp(0.0, 1.0);
                                          return Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 2),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppTheme.primary
                                                  .withOpacity(0.3 + 0.7 * t),
                                            ),
                                          );
                                        }),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _cancelMatchmaking,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('CANCEL MATCHMAKING',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
