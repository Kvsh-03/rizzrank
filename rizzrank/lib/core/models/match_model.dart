import 'package:firebase_database/firebase_database.dart';

/// RTDB live match model for real-time vibe updates.
/// Path: live_matches/{matchId}/
class GameMatch {
  final String matchId;
  final String status;
  final String aiCharacterId;
  final List<String> playerIds;
  final String? winnerId;
  final String targetPhrase;
  final Map<String, PlayerState> players;
  final int? createdAt;

  const GameMatch({
    required this.matchId,
    required this.status,
    this.aiCharacterId = 'luna',
    this.playerIds = const [],
    this.winnerId,
    this.targetPhrase = '',
    required this.players,
    this.createdAt,
  });

  factory GameMatch.fromSnapshot(DataSnapshot snapshot) {
    final matchId = snapshot.key ?? '';
    final value = snapshot.value;
    if (value == null || value is! Map) {
      throw ArgumentError('Invalid match snapshot: expected Map');
    }
    final map = Map<String, dynamic>.from(value);
    final playersMap = <String, PlayerState>{};
    final playersData = map['players'];
    if (playersData is Map) {
      for (final entry in playersData.entries) {
        final uid = entry.key.toString();
        final childSnapshot = snapshot.child('players/$uid');
        if (childSnapshot.exists) {
          playersMap[uid] = PlayerState.fromSnapshot(childSnapshot, uid);
        }
      }
    }
    final playerIdsRaw = map['player_ids'] ?? map['playerIds'];
    final playerIds = playerIdsRaw is List
        ? playerIdsRaw.map((e) => e.toString()).toList()
        : playersMap.keys.toList();
    return GameMatch(
      matchId: matchId,
      status: map['status'] as String? ?? 'waiting',
      aiCharacterId: map['ai_character_id'] as String? ?? 'luna',
      playerIds: playerIds,
      winnerId: map['winner_id'] as String? ?? map['winner_uid'] as String?,
      targetPhrase: map['target_phrase'] as String? ?? map['targetPhrase'] as String? ?? '',
      players: playersMap,
      createdAt: map['created_at'] != null
          ? _parseInt(map['created_at'], 0)
          : null,
    );
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  /// Returns the opponent's UID for the given player UID.
  String? getOpponentUid(String myUid) {
    final uids = playerIds.isNotEmpty ? playerIds : players.keys.toList();
    if (uids.length < 2) return null;
    return uids.firstWhere((u) => u != myUid, orElse: () => uids.first);
  }
}

/// Firebase-ready player state for RTDB path:
/// matches/{matchId}/players/{uid}/
class PlayerState {
  final String uid;
  final String displayName;
  final int rizzScore;
  final bool isWinner;

  const PlayerState({
    required this.uid,
    required this.displayName,
    this.rizzScore = 0,
    this.isWinner = false,
  });

  factory PlayerState.fromSnapshot(DataSnapshot snapshot, [String? uid]) {
    final uidValue = uid ?? snapshot.key ?? '';
    final value = snapshot.value;
    if (value == null || value is! Map) {
      return PlayerState(
        uid: uidValue,
        displayName: '',
        rizzScore: 0,
        isWinner: false,
      );
    }
    final map = Map<String, dynamic>.from(value);
    return PlayerState.fromMap(uidValue, map);
  }

  factory PlayerState.fromMap(String uid, Map<String, dynamic> map) {
    return PlayerState(
      uid: uid,
      displayName: map['display_name'] as String? ?? '',
      rizzScore: _parseInt(map['rizz_score'], 0),
      isWinner: map['is_winner'] == true,
    );
  }

  static int _parseInt(dynamic value, int fallback) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  Map<String, dynamic> toMap() {
    return {
      'display_name': displayName,
      'rizz_score': rizzScore,
      'is_winner': isWinner,
    };
  }
}
