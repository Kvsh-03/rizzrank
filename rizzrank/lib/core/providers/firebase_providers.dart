import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cloud_functions_http_service.dart';
import '../services/database_service.dart';
import '../services/matchmaking_service.dart';
import '../models/user_model.dart';
import '../models/firestore_match_model.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});
final firebaseDatabaseProvider = Provider<FirebaseDatabase>(
  (ref) => FirebaseDatabase.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
final cloudFunctionsHttpServiceProvider = Provider<CloudFunctionsHttpService>(
  (ref) => CloudFunctionsHttpService(ref.watch(firebaseAuthProvider)),
);

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(
    firestore: ref.watch(firestoreProvider),
    database: ref.watch(firebaseDatabaseProvider),
  );
});

final matchmakingServiceProvider = Provider<MatchmakingService>((ref) {
  return MatchmakingService(
    functions: ref.watch(cloudFunctionsHttpServiceProvider),
    database: ref.watch(firebaseDatabaseProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  return authAsync.when(
    data: (authUser) {
      if (authUser == null) return Stream.value(null);
      return ref.watch(databaseServiceProvider).watchUserProfile(authUser.uid);
    },
    loading: () => const Stream.empty(), // keeps AsyncLoading
    error: (e, st) => Stream.error(e, st),
  );
});

final aiModelsProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) {
    return ref.watch(firestoreProvider).collection('ai_models').snapshots().map(
      (snap) {
        return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      },
    );
  },
);

/// Traits from Firestore traits/{category} (e.g. traits/genders with { values: [...] }).
/// Used for gender/preference dropdowns in settings.
final traitsProvider = StreamProvider.autoDispose<Map<String, List<String>>>((ref) {
  return ref.watch(firestoreProvider).collection('traits').snapshots().map((snap) {
    final map = <String, List<String>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final values = data['values'];
      if (values is List) {
        map[doc.id] = values.map((e) => e.toString()).toList();
      }
    }
    return map;
  });
});
/// Checks if the current user has an active match to reconnect to.
final activeMatchCheckProvider = FutureProvider<String?>((ref) async {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return null;
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getActiveMatchId(authUser.uid);
});

/// Top players for leaderboard, ordered by ELO descending.
final leaderboardProvider = StreamProvider.autoDispose<List<AppUser>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .orderBy('elo_rating', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => AppUser.fromFirestore(doc))
          .toList());
});

final matchHistoryProvider = StreamProvider.autoDispose<List<FirestoreMatch>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  return ref.watch(databaseServiceProvider).watchMatchHistory(user.uid);
});
