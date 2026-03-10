import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

// import '../../../core/data/ai_characters.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/match_providers.dart';
import '../../../core/theme/app_theme.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/heart_meter.dart';
import 'widgets/opponent_ghost.dart';

bool _isPlaceholderAvatar(String url) =>
    url.isEmpty || url.contains('placeholder');

class BattlePage extends ConsumerStatefulWidget {
  const BattlePage({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends ConsumerState<BattlePage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  Timer? _typingDebounce;
  bool _isForfeiting = false;
  bool _hasForfeited = false;

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _onTextChanged(String text) {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final dbService = ref.read(databaseServiceProvider);
    _typingDebounce?.cancel();

    if (text.isNotEmpty) {
      dbService.setTypingIndicator(widget.matchId, user.uid, true);
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        dbService.setTypingIndicator(widget.matchId, user.uid, false);
      });
    } else {
      dbService.setTypingIndicator(widget.matchId, user.uid, false);
    }
  }

  Future<void> _sendMessage(String uid) async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // Clear immediately so the user can keep typing
    _textController.clear();

    // Clear typing indicator
    ref
        .read(databaseServiceProvider)
        .setTypingIndicator(widget.matchId, uid, false);
    _typingDebounce?.cancel();

    try {
      await ref.read(databaseServiceProvider).sendMessageToRTDB(
        widget.matchId,
        uid,
        text,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _forfeit() async {
    if (_isForfeiting) return;
    setState(() {
      _isForfeiting = true;
      _hasForfeited = true;
    });
    try {
      await ref.read(matchmakingServiceProvider).forfeitMatch(widget.matchId);
      if (mounted) context.go('/results/defeat/${widget.matchId}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isForfeiting = false;
          _hasForfeited = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forfeit failed: $e')),
        );
      }
    }
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _typingDebounce?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final liveMatchAsync = ref.watch(liveMatchStreamProvider(widget.matchId));
    final messagesAsync = ref.watch(
      messagesStreamProvider((matchId: widget.matchId, uid: user.uid)),
    );

    // Navigate to results when match completes
    ref.listen(liveMatchStreamProvider(widget.matchId), (prev, next) {
      if (_hasForfeited) return;
      final state = next.value;
      if (state != null && state.isCompleted) {
        if (state.winnerUid != null) {
          final outcome = state.winnerUid == user.uid ? 'victory' : 'defeat';
          context.go('/results/$outcome/${widget.matchId}');
        } else {
          context.go('/results/defeat/${widget.matchId}');
        }
      }
    });

    // Navigate away if active_match_id changes (user cancelled, match invalidated)
    // Skip when we just forfeited - we navigate to results ourselves
    // When active_match_id becomes null, the match ended (forfeit/win/draw) - do NOT
    // navigate to dashboard; let liveMatchStreamProvider navigate to results/victory.
    ref.listen(currentUserProvider, (prev, next) {
      if (_hasForfeited) return;
      final u = next.value;
      if (u != null && u.activeMatchId != widget.matchId) {
        if (u.activeMatchId == null || u.activeMatchId!.isEmpty) {
          return; // Match ended - liveMatchStreamProvider will navigate to results
        }
        if (mounted) context.go('/chat/${u.activeMatchId}');
      }
    });

    return liveMatchAsync.when(
      data: (liveMatch) {
        if (liveMatch == null) {
          return const Scaffold(body: Center(child: Text('Match not found')));
        }

        final aiCharName = liveMatch.aiCharacterName ??
            (ref.watch(aiModelsProvider).valueOrNull ?? [])
                .cast<Map<String, dynamic>>()
                .firstWhere(
                  (m) => m['id'] == liveMatch.aiCharacterId,
                  orElse: () => {'name': 'Unknown AI'},
                )['name'] as String? ??
            'Unknown AI';
        final aiModels = ref.watch(aiModelsProvider).valueOrNull ?? [];
        final aiChar = aiModels.cast<Map<String, dynamic>>().firstWhere(
          (m) => m['id'] == liveMatch.aiCharacterId,
          orElse: () => {
            'role': 'Mystery',
            'description': 'An enigma.',
            'avatar_url': '',
          },
        );
        final aiCharAvatar =
            aiChar['avatar_url'] as String? ??
            aiChar['avatarUrl'] as String? ??
            '';
        final myVibe = liveMatch.vibeFor(user.uid);
        final opponentUid = liveMatch.getOpponentUid(user.uid);
        final opponentVibe = opponentUid != null
            ? liveMatch.vibeFor(opponentUid)
            : 0;
        final aiIsTyping = liveMatch.isTyping['ai_${user.uid}'] == true;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: AppTheme.backgroundDark,
          body: Stack(
            children: [
              Column(
                children: [
                  // Model header at top (level with SafeArea)
                  SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundDark,
                        border: Border(
                          bottom: BorderSide(
                            color: AppTheme.primary.withOpacity(0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _isPlaceholderAvatar(aiCharAvatar)
                                      ? Container(
                                          color: Colors.grey[800],
                                          child: const Icon(
                                            LucideIcons.user,
                                            color: Colors.white54,
                                            size: 24,
                                          ),
                                        )
                                      : Image.network(
                                          aiCharAvatar,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: Colors.grey[800],
                                            child: const Icon(
                                              LucideIcons.user,
                                              color: Colors.white54,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.backgroundDark,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              aiCharName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Heart Meter & Opponent Ghost
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    children: [
                      HeartMeter(score: myVibe),
                      const SizedBox(height: 12),
                      if (opponentUid != null)
                        OpponentGhost(opponentScore: opponentVibe),
                    ],
                  ),
                ),

                  // Chat Messages
                  Expanded(
                    child: messagesAsync.when(
                  data: (messages) {
                    final reversedMessages = messages.reversed.toList();

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: reversedMessages.length,
                      itemBuilder: (context, index) {
                        return ChatBubble(
                          message: reversedMessages[index],
                          aiAvatarUrl: aiCharAvatar,
                          aiName: aiCharName,
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),

                  // AI Typing indicator
                  if (aiIsTyping)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                          child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.grey[800],
                            child: _isPlaceholderAvatar(aiCharAvatar)
                                ? const Icon(
                                    LucideIcons.user,
                                    color: Colors.white54,
                                    size: 20,
                                  )
                                : ClipOval(
                                    child: Image.network(
                                      aiCharAvatar,
                                      fit: BoxFit.cover,
                                      width: 28,
                                      height: 28,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(
                                        LucideIcons.user,
                                        color: Colors.white54,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.pinkAccent,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$aiCharName is typing...',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Input Bar
                  Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark.withOpacity(0.95),
                  border: Border(
                    top: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            TextField(
                              controller: _textController,
                              focusNode: _focusNode,
                              onTap: () => _scrollToBottom(),
                              onChanged: _onTextChanged,
                              decoration: InputDecoration(
                                hintText: 'Type your smooth response...',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                filled: true,
                                fillColor:
                                    Colors.grey[850]?.withOpacity(0.5) ??
                                    Colors.white.withOpacity(0.08),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: AppTheme.primary.withOpacity(0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide(
                                    color: AppTheme.primary.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.fromLTRB(
                                  20,
                                  14,
                                  48,
                                  14,
                                ),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              onSubmitted: (_) => _sendMessage(user.uid),
                            ),
                            Positioned(
                              right: 6,
                              child: GestureDetector(
                                onTap: () => _sendMessage(user.uid),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.send,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withOpacity(0.1),
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.wand2,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                  ),
                ],
              ),
              // FORFEIT button overlay at top right
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: InkWell(
                  onTap: _isForfeiting ? null : _forfeit,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.redAccent.withOpacity(0.2),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.4),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'FORFEIT',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          LucideIcons.trophy,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Match Error: $e'))),
    );
  }
}

