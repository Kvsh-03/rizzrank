import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/firestore_match_model.dart';
import '../models/user_model.dart';

/// Matchmaking service using Firestore transactions to prevent double-matching.
/// Collection: matchmaking (queue)
/// ELO range: +/- 100
class MatchmakingService {
  MatchmakingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _matchmakingCollection = 'matchmaking';
  static const String _matchesCollection = 'matches';
  static const int _eloRange = 100;

  /// Finds a match. Uses a Firestore transaction to prevent double-matching.
  /// - If a compatible user (within +/- 100 ELO) exists: pair, delete both from queue, create match.
  /// - If none: add self to queue and return null.
  /// Returns [FirestoreMatch] if matched, null if queued.
  Future<FirestoreMatch?> findMatch(AppUser user) async {
    return _firestore.runTransaction<FirestoreMatch?>((transaction) async {
      final myElo = user.eloRating;
      final minElo = myElo - _eloRange;
      final maxElo = myElo + _eloRange;

      // Query queue by timestamp (FIFO), filter ELO range in memory to avoid compound index
      final snapshot = await _firestore
          .collection(_matchmakingCollection)
          .orderBy('timestamp', descending: false)
          .limit(50)
          .get();

      // Find first user in ELO range that is not self
      DocumentSnapshot<Map<String, dynamic>>? opponentDoc;
      for (final doc in snapshot.docs) {
        if (doc.id == user.uid) continue;
        final data = doc.data();
        final opponentElo = (data['elo_rating'] as num?)?.toInt() ?? 1000;
        if (opponentElo >= minElo && opponentElo <= maxElo) {
          opponentDoc = doc as DocumentSnapshot<Map<String, dynamic>>;
          break;
        }
      }

      if (opponentDoc == null || !opponentDoc.exists) {
        // No compatible opponent: add self to queue
        final queueRef = _firestore.collection(_matchmakingCollection).doc(user.uid);
        transaction.set(queueRef, {
          'display_name': user.displayName,
          'elo_rating': user.eloRating,
          'rizz_title': user.rizzTitle,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return null;
      }

      final opponentUid = opponentDoc.id;
      final opponentData = opponentDoc.data();
      if (opponentData == null) return null;

      // Create match document
      final matchRef = _firestore.collection(_matchesCollection).doc();
      final matchId = matchRef.id;
      final playerIds = [user.uid, opponentUid];

      transaction.set(matchRef, {
        'player_ids': playerIds,
        'winner_id': null,
        'status': 'active',
        'target_phrase': '',
        'ai_character_id': 'luna',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Remove both from queue
      transaction.delete(_firestore.collection(_matchmakingCollection).doc(user.uid));
      transaction.delete(_firestore.collection(_matchmakingCollection).doc(opponentUid));

      return FirestoreMatch(
        matchId: matchId,
        playerIds: playerIds,
        winnerId: null,
        status: 'active',
        targetPhrase: '',
        aiCharacterId: 'luna',
        createdAt: DateTime.now(),
      );
    });
  }

  /// Removes the current user from the matchmaking queue (cancel).
  Future<void> leaveQueue(String uid) async {
    await _firestore.collection(_matchmakingCollection).doc(uid).delete();
  }

  /// Checks if user is currently in the queue.
  Future<bool> isInQueue(String uid) async {
    final doc = await _firestore.collection(_matchmakingCollection).doc(uid).get();
    return doc.exists;
  }

  /// Listens for a match to be created for this user (e.g. when opponent joins).
  /// Polls matches collection for documents where player_ids contains uid.
  Stream<FirestoreMatch?> watchForMatch(String uid) {
    return _firestore
        .collection(_matchesCollection)
        .where('player_ids', arrayContains: uid)
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return FirestoreMatch.fromFirestore(
        doc as DocumentSnapshot<Map<String, dynamic>>,
      );
    });
  }
}
