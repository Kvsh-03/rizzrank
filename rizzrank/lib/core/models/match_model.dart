import 'package:firebase_database/firebase_database.dart';

/// RTDB live match model for real-time vibe/typing updates.
/// Path: active_states/{matchId}
///
/// Flat schema:
///   status, player_ids, ai_character_id, target_phrase,
///   p1_vibe, p2_vibe, is_typing, winner_uid, expires_at, created_at
class ActiveMatchState {
  final String matchId;
  final String status;
  final List<String> playerIds;
  final String aiCharacterId;
  final String targetPhrase;
  final int p1Vibe;
  final int p2Vibe;
  final String? isTyping;
  final String? winnerUid;
  final int? expiresAt;
  final int? createdAt;

  const ActiveMatchState({
    required this.matchId,
    this.status = 'active',
    this.playerIds = const [],
    this.aiCharacterId = 'luna',
    this.targetPhrase = '',
    this.p1Vibe = 0,
    this.p2Vibe = 0,
    this.isTyping,
    this.winnerUid,
    this.expiresAt,
    this.createdAt,
  });

  factory ActiveMatchState.fromSnapshot(DataSnapshot snapshot) {
    final matchId = snapshot.key ?? '';
    final value = snapshot.value;
    if (value == null || value is! Map) {
      throw ArgumentError('Invalid active_states snapshot: expected Map');
    }
    final map = Map<String, dynamic>.from(value);
    return ActiveMatchState.fromMap(matchId, map);
  }

  factory ActiveMatchState.fromMap(String matchId, Map<String, dynamic> map) {
    final playerIdsRaw = map['player_ids'] ?? map['playerIds'];
    final playerIds = playerIdsRaw is List
        ? playerIdsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return ActiveMatchState(
      matchId: matchId,
      status: map['status'] as String? ?? 'active',
      playerIds: playerIds,
      aiCharacterId:
          map['ai_character_id'] as String? ?? map['aiCharacterId'] as String? ?? 'luna',
      targetPhrase:
          map['target_phrase'] as String? ?? map['targetPhrase'] as String? ?? '',
      p1Vibe: _parseInt(map['p1_vibe'], 0),
      p2Vibe: _parseInt(map['p2_vibe'], 0),
      isTyping: map['is_typing'] as String?,
      winnerUid: map['winner_uid'] as String?,
      expiresAt: map['expires_at'] != null ? _parseInt(map['expires_at'], 0) : null,
      createdAt: map['created_at'] != null ? _parseInt(map['created_at'], 0) : null,
    );
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// Returns the player index (0 or 1) for the given UID, or -1 if not found.
  int playerIndex(String uid) => playerIds.indexOf(uid);

  /// Returns the vibe score for the given player UID.
  int vibeFor(String uid) {
    final idx = playerIndex(uid);
    if (idx == 0) return p1Vibe;
    if (idx == 1) return p2Vibe;
    return 0;
  }

  /// Returns the opponent's UID for the given player UID.
  String? getOpponentUid(String myUid) {
    if (playerIds.length < 2) return null;
    return playerIds.firstWhere((u) => u != myUid, orElse: () => playerIds.first);
  }

  bool get isCompleted => status == 'completed' || status == 'timed_out';

  /// Remaining seconds until match expires, or null if no expiry set.
  int? get remainingSeconds {
    if (expiresAt == null) return null;
    final remaining = expiresAt! - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }
}
