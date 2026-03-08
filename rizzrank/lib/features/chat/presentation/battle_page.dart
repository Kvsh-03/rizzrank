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
    setState(() => _isForfeiting = true);
    try {
      await ref.read(matchmakingServiceProvider).forfeitMatch(widget.matchId);
      if (mounted) context.go('/results/defeat/${widget.matchId}');
    } catch (e) {
      if (mounted) {
        setState(() => _isForfeiting = false);
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
      final state = next.value;
      if (state != null && state.isCompleted && state.winnerUid != null) {
        final outcome = state.winnerUid == user.uid ? 'victory' : 'defeat';
        context.go('/results/$outcome/${widget.matchId}');
      }
    });

    // Navigate away if active_match_id changes (user cancelled, match invalidated)
    ref.listen(currentUserProvider, (prev, next) {
      final u = next.value;
      if (u != null && u.activeMatchId != widget.matchId) {
        if (u.activeMatchId == null || u.activeMatchId!.isEmpty) {
          if (mounted) context.go('/dashboard');
        } else {
          if (mounted) context.go('/chat/${u.activeMatchId}');
        }
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
            'avatar_url': 'https://via.placeholder.com/150',
          },
        );
        final aiCharRole = aiChar['role'] as String? ?? 'Mystery';
        final aiCharDescription =
            aiChar['description'] as String? ?? 'An enigma.';
        final aiCharAvatar =
            aiChar['avatar_url'] as String? ??
            aiChar['avatarUrl'] as String? ??
            'https://via.placeholder.com/150';
        final myVibe = liveMatch.vibeFor(user.uid);
        final opponentUid = liveMatch.getOpponentUid(user.uid);
        final opponentVibe = opponentUid != null
            ? liveMatch.vibeFor(opponentUid)
            : 0;
        final aiIsTyping = liveMatch.isTyping['ai_${user.uid}'] == true;

        final isKeyboardVisible =
            MediaQuery.of(context).viewInsets.bottom > 0 ||
            _focusNode.hasFocus;

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: AppTheme.backgroundDark,
          appBar: AppBar(
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppTheme.primary.withOpacity(0.1),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: const Icon(
                  LucideIcons.menu,
                  color: AppTheme.primary,
                  size: 20,
                ),
              ),
            ),
            title: const Text(
              'RizzRank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
              const SizedBox(width: 8),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              // Use compact header when keyboard visible, text field focused, or space is tight
              final useCompactHeader = isKeyboardVisible ||
                  constraints.maxHeight < 550;

              return Column(
                children: [
                  // Compact header when keyboard visible, full header otherwise
                  if (useCompactHeader)
                    _CompactChatHeader(
                      avatarUrl: aiCharAvatar,
                      name: aiCharName,
                      isForfeiting: _isForfeiting,
                      onForfeit: _forfeit,
                    )
                  else ...[
                // AI Profile Header
                Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primary.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.4),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.pinkAccent.withOpacity(0.2),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primary.withOpacity(0.5),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: Image.network(
                                aiCharAvatar,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    LucideIcons.user,
                                    color: Colors.white54,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.backgroundDark,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      aiCharName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$aiCharRole \u2022 "${aiCharDescription.split('.').first}"',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _PersonalityTag(
                          label: 'Cinephile',
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 8),
                        _PersonalityTag(
                          label: 'Night Owl',
                          color: Colors.pinkAccent,
                        ),
                      ],
                    ),
                  ],
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
                  ],

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
                            backgroundImage: NetworkImage(aiCharAvatar),
                            onBackgroundImageError: (_, __) {},
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
              );
            },
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Match Error: $e'))),
    );
  }
}

class _CompactChatHeader extends StatelessWidget {
  const _CompactChatHeader({
    required this.avatarUrl,
    required this.name,
    required this.isForfeiting,
    required this.onForfeit,
  });

  final String avatarUrl;
  final String name;
  final bool isForfeiting;
  final VoidCallback onForfeit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(
          bottom: BorderSide(color: AppTheme.primary.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[800],
            child: ClipOval(
              child: Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => const Icon(
                  LucideIcons.user,
                  color: Colors.white54,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: isForfeiting ? null : onForfeit,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        ],
      ),
    );
  }
}

class _PersonalityTag extends StatelessWidget {
  const _PersonalityTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
