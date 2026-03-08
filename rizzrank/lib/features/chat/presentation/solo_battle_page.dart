import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/data/ai_characters.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/heart_meter.dart';

class SoloBattlePage extends StatefulWidget {
  const SoloBattlePage({super.key, required this.characterId});

  final String characterId;

  @override
  State<SoloBattlePage> createState() => _SoloBattlePageState();
}

class _SoloBattlePageState extends State<SoloBattlePage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _random = Random();

  late final AICharacter _character;
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  int _affection = 45;
  int _msgCounter = 0;

  static const _aiResponses = [
    "Hmm, not bad. You've got a certain... energy about you. Keep going.",
    "Oh? That's actually more interesting than I expected. Tell me more.",
    "I've heard that line before, but something about the way you said it... intriguing.",
    "You're either very confident or very reckless. Either way, I'm paying attention.",
    "That was smooth. I'll give you credit for originality at least.",
    "Interesting perspective. Most people just agree with whatever I say.",
    "Okay, you have my attention now. Don't waste it.",
    "Not everyone can keep up with me. You're doing surprisingly well.",
    "I wasn't expecting that. You've got layers, don't you?",
    "Bold move. Let's see if you can back it up.",
  ];

  @override
  void initState() {
    super.initState();
    _character = getCharacterById(widget.characterId);
    _addAiMessage(
      "Honestly, the cinematography in that scene felt a bit derivative. "
      "Change my mind? Or are you just going to agree with the critics?",
    );
  }

  void _addAiMessage(String text) {
    _msgCounter++;
    _messages.add(ChatMessage(
      key: 'msg-$_msgCounter',
      role: 'ai',
      text: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isTyping) return;

    final rizzDelta = _random.nextInt(80) + 20;

    setState(() {
      _msgCounter++;
      _messages.add(ChatMessage(
        key: 'msg-$_msgCounter',
        role: 'user',
        text: text,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        rizzDelta: rizzDelta,
      ));
      _affection = (_affection + (_random.nextInt(8) + 2)).clamp(0, 100);
      _textController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(1200)));

    if (!mounted) return;

    final response = _aiResponses[_random.nextInt(_aiResponses.length)];
    setState(() {
      _addAiMessage(response);
      _isTyping = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.go('/dashboard'),
        ),
        title: const Text('RizzRank',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: InkWell(
              onTap: () => context.go('/results/victory/solo'),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.greenAccent.withOpacity(0.2),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('FINISH',
                        style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(LucideIcons.trophy,
                        color: Colors.greenAccent, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
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
                              width: 2),
                        ),
                        child: ClipOval(
                          child: Image.network(
                            _character.avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[800],
                              child: const Icon(LucideIcons.user,
                                  color: Colors.white54, size: 40),
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
                              color: AppTheme.backgroundDark, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_character.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${_character.role} \u2022 "${_character.description.split('.').first}"',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PersonalityTag(label: 'Cinephile', color: AppTheme.primary),
                    const SizedBox(width: 8),
                    _PersonalityTag(
                        label: 'Night Owl', color: Colors.pinkAccent),
                  ],
                ),
              ],
            ),
          ),

          // Heart Meter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: HeartMeter(score: _affection),
          ),

          // Chat Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _TypingIndicator(
                    avatarUrl: _character.avatarUrl,
                    name: _character.name,
                  );
                }
                return ChatBubble(
                  message: _messages[index],
                  aiAvatarUrl: _character.avatarUrl,
                  aiName: _character.name,
                );
              },
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark.withOpacity(0.95),
              border: Border(
                  top: BorderSide(color: AppTheme.primary.withOpacity(0.2))),
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
                          decoration: InputDecoration(
                            hintText: 'Type your smooth response...',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.3)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                  color: AppTheme.primary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                  color: AppTheme.primary.withOpacity(0.5),
                                  width: 2),
                            ),
                            contentPadding:
                                const EdgeInsets.fromLTRB(20, 14, 48, 14),
                          ),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                        Positioned(
                          right: 6,
                          child: GestureDetector(
                            onTap: _sendMessage,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.send,
                                  color: Colors.white, size: 18),
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
                          color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: const Icon(LucideIcons.wand2,
                        color: AppTheme.primary, size: 20),
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

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.avatarUrl, required this.name});

  final String avatarUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(avatarUrl),
          ),
          const SizedBox(width: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(3, (i) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.4, end: 1.0),
                    duration: Duration(milliseconds: 600 + i * 200),
                    curve: Curves.easeInOut,
                    builder: (_, value, child) => Opacity(
                      opacity: value,
                      child: child,
                    ),
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 6),
                Text(
                  '$name is typing...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
