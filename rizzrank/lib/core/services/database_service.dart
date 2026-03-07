import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/firestore_match_model.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';

/// Hybrid Firestore + RTDB service.
/// - Firestore: users (profiles), matches (history)
/// - RTDB: live_matches (high-speed vibe updates)
class DatabaseService {
  DatabaseService({
    FirebaseFirestore? firestore,
    FirebaseDatabase? database,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _database = database ?? FirebaseDatabase.instance;

  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;

  static const String _usersCollection = 'users';
  static const String _matchesCollection = 'matches';
  static const String _liveMatchesPath = 'live_matches';

  // ---------------------------------------------------------------------------
  // Firestore: Users (profiles)
  // ---------------------------------------------------------------------------

  /// Creates or overwrites a user profile in Firestore.
  Future<void> createUserProfile(AppUser user) async {
    await _firestore.collection(_usersCollection).doc(user.uid).set(
          user.toFirestore(),
          SetOptions(merge: true),
        );
  }

  /// Fetches a user profile from Firestore.
  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _firestore.collection(_usersCollection).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromFirestore(doc);
  }

  /// Streams a user profile from Firestore.
  Stream<AppUser?> watchUserProfile(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  // ---------------------------------------------------------------------------
  // RTDB: Live matches (vibe updates)
  // ---------------------------------------------------------------------------

  /// Updates vibe/rizz score for a player in a live match (RTDB).
  Future<void> updateMatchVibe({
    required String matchId,
    required String playerId,
    required int rizzScore,
    bool isWinner = false,
  }) async {
    final ref = _database.ref('$_liveMatchesPath/$matchId/players/$playerId');
    await ref.update({
      'rizz_score': rizzScore,
      'is_winner': isWinner,
    });
  }

  /// Updates multiple vibe fields for a player.
  Future<void> updateMatchVibeFields({
    required String matchId,
    required String playerId,
    Map<String, dynamic>? updates,
  }) async {
    if (updates == null || updates.isEmpty) return;
    final ref = _database.ref('$_liveMatchesPath/$matchId/players/$playerId');
    await ref.update(updates);
  }

  /// Streams a live match from RTDB for real-time vibe updates.
  Stream<GameMatch?> watchLiveMatch(String matchId) {
    return _database.ref('$_liveMatchesPath/$matchId').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) return null;
      return GameMatch.fromSnapshot(snapshot);
    });
  }

  /// Initializes a live match node in RTDB (called when match starts).
  Future<void> initLiveMatch({
    required String matchId,
    required List<String> playerIds,
    required Map<String, String> displayNamesByUid,
    String aiCharacterId = 'luna',
    String targetPhrase = '',
  }) async {
    final ref = _database.ref('$_liveMatchesPath/$matchId');
    final players = <String, dynamic>{};
    for (final uid in playerIds) {
      players[uid] = {
        'display_name': displayNamesByUid[uid] ?? '',
        'rizz_score': 0,
        'is_winner': false,
      };
    }
    await ref.set({
      'status': 'active',
      'ai_character_id': aiCharacterId,
      'player_ids': playerIds,
      'target_phrase': targetPhrase,
      'created_at': ServerValue.timestamp,
      'players': players,
    });
  }

  // ---------------------------------------------------------------------------
  // Firestore: Matches (history) - archive
  // ---------------------------------------------------------------------------

  /// Archives a completed match to Firestore and removes from RTDB live_matches.
  Future<void> archiveMatch({
    required String matchId,
    required List<String> playerIds,
    required String? winnerId,
    required String status,
    required String targetPhrase,
    String? aiCharacterId,
  }) async {
    final batch = _firestore.batch();
    final matchRef = _firestore.collection(_matchesCollection).doc(matchId);
    batch.set(matchRef, {
      'player_ids': playerIds,
      'winner_id': winnerId,
      'status': status,
      'target_phrase': targetPhrase,
      ...? (aiCharacterId != null ? {'ai_character_id': aiCharacterId} : null),
      'created_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Remove from RTDB live_matches (cleanup)
    await _database.ref('$_liveMatchesPath/$matchId').remove();
  }

  /// Fetches match history for a user from Firestore.
  Future<List<FirestoreMatch>> getMatchHistory(String uid, {int limit = 20}) async {
    final query = await _firestore
        .collection(_matchesCollection)
        .where('player_ids', arrayContains: uid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();

    return query.docs
        .map((d) => FirestoreMatch.fromFirestore(d))
        .toList();
  }

  /// Streams match history for a user.
  Stream<List<FirestoreMatch>> watchMatchHistory(String uid, {int limit = 20}) {
    return _firestore
        .collection(_matchesCollection)
        .where('player_ids', arrayContains: uid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                FirestoreMatch.fromFirestore(d))
            .toList());
  }
}
