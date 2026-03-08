import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore match document for matches collection (history/archive).
/// Path: matches/{matchId}
///
/// All writes to this collection are server-only (Admin SDK).
/// Clients have read access if they are in player_ids.
class FirestoreMatch {
  final String matchId;
  final List<String> playerIds;
  final String? winnerId;
  final String status;
  final String targetPhrase;
  final String? aiCharacterId;
  final List<String> aiTraits;
  final Map<String, int> eloChange;
  final Map<String, int> playerEloBefore;
  final bool isGameOver;
  final DateTime? expiresAt;
  final int? duration;
  final DateTime? createdAt;

  const FirestoreMatch({
    required this.matchId,
    required this.playerIds,
    this.winnerId,
    this.status = 'active',
    this.targetPhrase = '',
    this.aiCharacterId,
    this.aiTraits = const [],
    this.eloChange = const {},
    this.playerEloBefore = const {},
    this.isGameOver = false,
    this.expiresAt,
    this.duration,
    this.createdAt,
  });

  factory FirestoreMatch.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final matchId = doc.id;
    if (data == null) {
      return FirestoreMatch(matchId: matchId, playerIds: []);
    }
    return FirestoreMatch.fromMap(matchId, data);
  }

  factory FirestoreMatch.fromMap(String matchId, Map<String, dynamic> map) {
    final playerIdsRaw = map['player_ids'] ?? map['playerIds'];
    final playerIds = playerIdsRaw is List
        ? playerIdsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final aiTraitsRaw = map['ai_traits'] ?? map['aiTraits'];
    final aiTraits = aiTraitsRaw is List
        ? aiTraitsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final eloChangeRaw = map['elo_change'] ?? map['eloChange'];
    final eloChange = <String, int>{};
    if (eloChangeRaw is Map) {
      for (final entry in eloChangeRaw.entries) {
        eloChange[entry.key.toString()] =
            (entry.value is num) ? (entry.value as num).toInt() : 0;
      }
    }

    final playerEloBeforeRaw = map['player_elo_before'] ?? map['playerEloBefore'];
    final playerEloBefore = <String, int>{};
    if (playerEloBeforeRaw is Map) {
      for (final entry in playerEloBeforeRaw.entries) {
        playerEloBefore[entry.key.toString()] =
            (entry.value is num) ? (entry.value as num).toInt() : 0;
      }
    }

    final createdAt = map['created_at'];
    final expiresAtRaw = map['expires_at'] ?? map['expiresAt'];

    return FirestoreMatch(
      matchId: matchId,
      playerIds: playerIds,
      winnerId: map['winner_id'] as String? ?? map['winnerId'] as String?,
      status: map['status'] as String? ?? 'active',
      targetPhrase: map['target_phrase'] as String? ??
          map['targetPhrase'] as String? ??
          '',
      aiCharacterId:
          map['ai_character_id'] as String? ?? map['aiCharacterId'] as String?,
      aiTraits: aiTraits,
      eloChange: eloChange,
      playerEloBefore: playerEloBefore,
      isGameOver: map['is_game_over'] as bool? ?? map['isGameOver'] as bool? ?? false,
      expiresAt: expiresAtRaw is Timestamp
          ? expiresAtRaw.toDate()
          : expiresAtRaw != null
              ? DateTime.tryParse(expiresAtRaw.toString())
              : null,
      duration: map['duration'] != null
          ? (map['duration'] is num ? (map['duration'] as num).toInt() : null)
          : null,
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : createdAt != null
              ? DateTime.tryParse(createdAt.toString())
              : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'player_ids': playerIds,
      'winner_id': winnerId,
      'status': status,
      'target_phrase': targetPhrase,
      'is_game_over': isGameOver,
      if (aiCharacterId != null) 'ai_character_id': aiCharacterId,
      if (aiTraits.isNotEmpty) 'ai_traits': aiTraits,
      if (eloChange.isNotEmpty) 'elo_change': eloChange,
      if (playerEloBefore.isNotEmpty) 'player_elo_before': playerEloBefore,
      if (expiresAt != null) 'expires_at': Timestamp.fromDate(expiresAt!),
      if (duration != null) 'duration': duration,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
    };
  }

  FirestoreMatch copyWith({
    String? matchId,
    List<String>? playerIds,
    String? winnerId,
    String? status,
    String? targetPhrase,
    String? aiCharacterId,
    List<String>? aiTraits,
    Map<String, int>? eloChange,
    Map<String, int>? playerEloBefore,
    bool? isGameOver,
    DateTime? expiresAt,
    int? duration,
    DateTime? createdAt,
  }) {
    return FirestoreMatch(
      matchId: matchId ?? this.matchId,
      playerIds: playerIds ?? this.playerIds,
      winnerId: winnerId ?? this.winnerId,
      status: status ?? this.status,
      targetPhrase: targetPhrase ?? this.targetPhrase,
      aiCharacterId: aiCharacterId ?? this.aiCharacterId,
      aiTraits: aiTraits ?? this.aiTraits,
      eloChange: eloChange ?? this.eloChange,
      playerEloBefore: playerEloBefore ?? this.playerEloBefore,
      isGameOver: isGameOver ?? this.isGameOver,
      expiresAt: expiresAt ?? this.expiresAt,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
