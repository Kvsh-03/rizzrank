import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../services/matchmaking_service.dart';
import '../models/user_model.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
final firebaseDatabaseProvider = Provider<FirebaseDatabase>(
  (ref) => FirebaseDatabase.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instance,
);

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(
    firestore: ref.watch(firestoreProvider),
    database: ref.watch(firebaseDatabaseProvider),
  );
});

final matchmakingServiceProvider = Provider<MatchmakingService>((ref) {
  return MatchmakingService(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(firebaseFunctionsProvider),
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
