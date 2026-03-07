import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore match document for matches collection (history).
/// Path: matches/{matchId}
class FirestoreMatch {
  final String matchId;
  final List<String> playerIds;
  final String? winnerId;
  final String status;
  final String targetPhrase;
  final String? aiCharacterId;
  final DateTime? createdAt;

  const FirestoreMatch({
    required this.matchId,
    required this.playerIds,
    this.winnerId,
    this.status = 'active',
    this.targetPhrase = '',
    this.aiCharacterId,
    this.createdAt,
  });

  factory FirestoreMatch.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
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
    final createdAt = map['created_at'];
    return FirestoreMatch(
      matchId: matchId,
      playerIds: playerIds,
      winnerId: map['winner_id'] as String? ?? map['winnerId'] as String?,
      status: map['status'] as String? ?? 'active',
      targetPhrase: map['target_phrase'] as String? ?? map['targetPhrase'] as String? ?? '',
      aiCharacterId: map['ai_character_id'] as String? ?? map['aiCharacterId'] as String?,
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
      if (aiCharacterId != null) 'ai_character_id': aiCharacterId,
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
    DateTime? createdAt,
  }) {
    return FirestoreMatch(
      matchId: matchId ?? this.matchId,
      playerIds: playerIds ?? this.playerIds,
      winnerId: winnerId ?? this.winnerId,
      status: status ?? this.status,
      targetPhrase: targetPhrase ?? this.targetPhrase,
      aiCharacterId: aiCharacterId ?? this.aiCharacterId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
