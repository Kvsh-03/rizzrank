import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';

/// Server-side matchmaking service.
///
/// Uses RTDB queue: joinQueue adds to queue, leaveQueue removes.
/// Matcher runs on queue write (Cloud Function). Client watches
/// matchmaking_matches/{uid} for matchId.
class MatchmakingService {
  MatchmakingService({
    FirebaseFunctions? functions,
    FirebaseDatabase? database,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _database = database ?? FirebaseDatabase.instance;

  final FirebaseFunctions _functions;
  final FirebaseDatabase _database;

  /// Joins the matchmaking queue. Rejects if user already has active_match_id.
  Future<void> joinQueue() async {
    final callable = _functions.httpsCallable('joinQueue');
    await callable.call<Map<String, dynamic>>();
  }

  /// Cancels matchmaking by calling the leaveQueue callable.
  Future<void> leaveQueue() async {
    final callable = _functions.httpsCallable('leaveQueue');
    await callable.call();
  }

  /// Forfeits the current match. Caller loses; opponent wins.
  Future<void> forfeitMatch(String matchId) async {
    final callable = _functions.httpsCallable('forfeitMatch');
    await callable.call<Map<String, dynamic>>({'matchId': matchId});
  }

  /// Listens for a match to be created for this user.
  /// When matcher pairs this user, matchmaking_matches/{uid} is set to { matchId }.
  Stream<String?> watchMatchResult(String uid) {
    return _database.ref('matchmaking_matches/$uid').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) return null;
      final val = snapshot.value;
      if (val is Map && val['matchId'] != null) {
        return val['matchId'] as String;
      }
      return null;
    });
  }
}
