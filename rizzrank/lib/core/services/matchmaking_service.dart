import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/firestore_match_model.dart';

/// Server-side matchmaking service.
///
/// All queue operations run on Cloud Functions (Admin SDK) to prevent
/// double-matching and ensure clients cannot forge match documents.
class MatchmakingService {
  MatchmakingService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  /// Calls the server-side findMatch callable.
  /// Returns a [FirestoreMatch] if immediately matched, or null if queued.
  /// If [lat] and [lng] are provided, the server will prefer nearby opponents.
  Future<FirestoreMatch?> findMatch({double? lat, double? lng}) async {
    final callable = _functions.httpsCallable('findMatch');
    final requestData = <String, dynamic>{};
    if (lat != null && lng != null) {
      requestData['lat'] = lat;
      requestData['lng'] = lng;
    }
    final result = await callable.call<Map<String, dynamic>>(requestData);

    final data = result.data;
    if (data['matched'] == true && data['matchId'] != null) {
      final matchId = data['matchId'] as String;
      // Fetch the full match doc created by the server
      final doc = await _firestore.collection('matches').doc(matchId).get();
      if (doc.exists && doc.data() != null) {
        return FirestoreMatch.fromFirestore(doc);
      }
      // Fallback: return a minimal match with just the ID
      return FirestoreMatch(matchId: matchId, playerIds: [], status: 'active');
    }
    return null;
  }

  /// Cancels matchmaking by calling the leaveQueue callable.
  Future<void> leaveQueue() async {
    final callable = _functions.httpsCallable('leaveQueue');
    await callable.call();
  }

  /// Listens for a match to be created for this user (when opponent pairs with them).
  /// Used when findMatch returns null (queued) to detect pairing by another player's call.
  Stream<FirestoreMatch?> watchForMatch(String uid) {
    return _firestore
        .collection('matches')
        .where('player_ids', arrayContains: uid)
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return FirestoreMatch.fromFirestore(snap.docs.first);
        });
  }
}
