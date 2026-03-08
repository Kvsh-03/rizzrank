import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_model.dart';
import '../models/chat_message.dart';
import '../models/firestore_match_model.dart';
import 'firebase_providers.dart';

/// Currently active match ID (set during matchmaking flow).
final activeMatchIdProvider = StateProvider<String?>((ref) => null);

/// Streams RTDB active_states/{matchId} for live vibe/typing updates.
final liveMatchStreamProvider =
    StreamProvider.family<ActiveMatchState?, String>((ref, matchId) {
      final dbService = ref.watch(databaseServiceProvider);
      return dbService.watchLiveMatch(matchId);
    });

/// Streams the Firestore match document (for status/winner detection).
final firestoreMatchStreamProvider =
    StreamProvider.family<FirestoreMatch?, String>((ref, matchId) {
      final firestore = ref.watch(firestoreProvider);
      return firestore.collection('matches').doc(matchId).snapshots().map((
        doc,
      ) {
        if (!doc.exists || doc.data() == null) return null;
        return FirestoreMatch.fromFirestore(doc);
      });
    });

/// Streams chat messages from the player's private shard in a match.
final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, ({String matchId, String uid})>((
      ref,
      params,
    ) {
      final firestore = ref.watch(firestoreProvider);
      return firestore
          .collection(
            'matches/${params.matchId}/players/${params.uid}/messages',
          )
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snap) {
            return snap.docs.map((doc) {
              return ChatMessage.fromFirestore(doc);
            }).toList();
          });
    });

/// Streams presence data for a specific user.
final presenceProvider = StreamProvider.family<Map<String, dynamic>?, String>((
  ref,
  uid,
) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchPresence(uid);
});
