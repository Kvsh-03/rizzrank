import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) => FirebaseDatabase.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService(
    firestore: ref.watch(firestoreProvider),
    database: ref.watch(firebaseDatabaseProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final authUser = ref.watch(authStateProvider).value;
  if (authUser == null) return const Stream.empty();
  return ref.watch(databaseServiceProvider).watchUserProfile(authUser.uid);
});
