import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_model.dart';
import '../models/chat_message.dart';
import '../models/firestore_match_model.dart';
import 'firebase_providers.dart';

final activeMatchIdProvider = StateProvider<String?>((ref) => null);

final liveMatchStreamProvider = StreamProvider.family<GameMatch?, String>((ref, matchId) {
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.watchLiveMatch(matchId);
});

final firestoreMatchStreamProvider = StreamProvider.family<FirestoreMatch?, String>((ref, matchId) {
  final firestore = ref.watch(firestoreProvider);
  return firestore.collection('matches').doc(matchId).snapshots().map((doc) {
    if (!doc.exists || doc.data() == null) return null;
    return FirestoreMatch.fromFirestore(doc);
  });
});

final messagesStreamProvider = StreamProvider.family<List<ChatMessage>, ({String matchId, String uid})>((ref, params) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('matches/${params.matchId}/chat')
      .where(Filter.or(
        Filter('sender_uid', isEqualTo: params.uid),
        Filter('target_uid', isEqualTo: params.uid),
      ))
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snap) {
        return snap.docs.map((doc) {
          final data = doc.data();
          return ChatMessage(
            key: doc.id,
            role: data['role'] as String? ?? 'user',
            text: data['text'] as String? ?? '',
            timestamp: data['timestamp'] != null 
                ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch 
                : DateTime.now().millisecondsSinceEpoch,
            rizzDelta: data['rizz_delta'] != null ? int.tryParse(data['rizz_delta'].toString()) : null,
          );
        }).toList();
      });
});
