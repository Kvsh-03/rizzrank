import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/chat_message.dart';
import '../models/firestore_match_model.dart';
import '../models/match_model.dart';
import '../models/user_model.dart';

/// Hybrid Firestore + RTDB service.
/// - Firestore: users (profiles), matches (history/archive)
/// - RTDB: active_states (high-speed vibe updates), presence
///
/// Match creation, archival, and ELO updates are server-only (Cloud Functions).
class DatabaseService {
  DatabaseService({FirebaseFirestore? firestore, FirebaseDatabase? database})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _database = database ?? FirebaseDatabase.instance;

  final FirebaseFirestore _firestore;
  final FirebaseDatabase _database;

  // ---------------------------------------------------------------------------
  // Firestore: Users (profiles)
  // ---------------------------------------------------------------------------

  /// Creates a user profile on first sign-in, or updates client-safe fields
  /// on subsequent sign-ins. Checks existence first so that re-login does not
  /// attempt to write server-managed fields (blocked by security rules).
  Future<void> createUserProfile(AppUser user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({
        'display_name': user.displayName,
        'rizz_title': user.rizzTitle,
        'last_played': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.set({
        'display_name': user.displayName,
        'rizz_title': user.rizzTitle,
        'elo_rating': user.eloRating,
        'total_games': 0,
        'wins': 0,
        'losses': 0,
        'last_played': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Updates only client-safe profile fields.
  Future<void> updateUserProfile(
    String uid, {
    String? displayName,
    String? rizzTitle,
    String? gender,
    String? preferredGender,
  }) async {
    final updates = <String, dynamic>{
      'last_played': FieldValue.serverTimestamp(),
    };
    if (displayName != null) updates['display_name'] = displayName;
    if (rizzTitle != null) updates['rizz_title'] = rizzTitle;
    if (gender != null) updates['gender'] = gender;
    if (preferredGender != null) updates['preferred_gender'] = preferredGender;
    await _firestore.collection('users').doc(uid).update(updates);
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromFirestore(doc);
  }

  Stream<AppUser?> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromFirestore(doc);
    });
  }

  /// Returns the active match ID for a user, or null if they have no active match.
  /// Used on app startup for reconnection.
  Future<String?> getActiveMatchId(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data()?['active_match_id'] as String?;
  }

  // ---------------------------------------------------------------------------
  // RTDB: Active match states (vibe updates, typing)
  // Path: active_states/{matchId}
  // ---------------------------------------------------------------------------

  /// Streams live match state from RTDB for real-time UI.
  Stream<ActiveMatchState?> watchLiveMatch(String matchId) {
    return _database.ref('active_states/$matchId').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists) return null;
      return ActiveMatchState.fromSnapshot(snapshot);
    });
  }

  /// Sets the typing indicator for a specific player.
  /// Writes true when typing, removes the key when stopped.
  Future<void> setTypingIndicator(
    String matchId,
    String uid,
    bool isTyping,
  ) async {
    final ref = _database.ref('active_states/$matchId/is_typing/$uid');
    if (isTyping) {
      await ref.set(true);
    } else {
      await ref.remove();
    }
  }

  // ---------------------------------------------------------------------------
  // RTDB: Presence
  // Path: presence/{uid}
  // ---------------------------------------------------------------------------

  /// Sets up presence tracking with onDisconnect handler.
  /// Call once after authentication.
  Future<void> setupPresence(String uid) async {
    final ref = _database.ref('presence/$uid');
    await ref.set({'is_online': true, 'last_seen': ServerValue.timestamp});
    await ref.onDisconnect().set({
      'is_online': false,
      'last_seen': ServerValue.timestamp,
    });
  }

  /// Manually sets presence to offline (e.g., on sign-out).
  Future<void> goOffline(String uid) async {
    await _database.ref('presence/$uid').set({
      'is_online': false,
      'last_seen': ServerValue.timestamp,
    });
  }

  /// Streams presence for a specific user.
  Stream<Map<String, dynamic>?> watchPresence(String uid) {
    return _database.ref('presence/$uid').onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final val = event.snapshot.value;
      if (val is Map) return Map<String, dynamic>.from(val);
      return null;
    });
  }

  // ---------------------------------------------------------------------------
  // RTDB: Live messages during active match
  // Path: matches/{matchId}/players/{uid}/messages
  // ---------------------------------------------------------------------------

  /// Sends a user message to RTDB (for active matches).
  Future<void> sendMessageToRTDB(
    String matchId,
    String uid,
    String content,
  ) async {
    final ref = _database.ref('matches/$matchId/players/$uid/messages');
    await ref.push().set({
      'role': 'user',
      'content': content,
      'sender_uid': uid,
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Streams messages from RTDB for an active match.
  Stream<List<ChatMessage>> watchMessagesFromRTDB(
    String matchId,
    String uid,
  ) {
    return _database
        .ref('matches/$matchId/players/$uid/messages')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return <ChatMessage>[];
      final val = event.snapshot.value;
      if (val is! Map) return <ChatMessage>[];
      final list = <ChatMessage>[];
      for (final entry in val.entries) {
        if (entry.value is Map) {
          list.add(ChatMessage.fromMap(
            entry.key,
            Map<String, dynamic>.from(entry.value as Map),
          ));
        }
      }
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return list;
    });
  }

  // ---------------------------------------------------------------------------
  // Firestore: Matches (history) -- read-only on client
  // ---------------------------------------------------------------------------

  Future<List<FirestoreMatch>> getMatchHistory(
    String uid, {
    int limit = 20,
  }) async {
    final query = await _firestore
        .collection('matches')
        .where('player_ids', arrayContains: uid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();

    return query.docs.map((d) => FirestoreMatch.fromFirestore(d)).toList();
  }

  Stream<List<FirestoreMatch>> watchMatchHistory(String uid, {int limit = 20}) {
    return _firestore
        .collection('matches')
        .where('player_ids', arrayContains: uid)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => FirestoreMatch.fromFirestore(d)).toList(),
        );
  }
}
