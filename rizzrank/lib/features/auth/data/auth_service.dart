import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rizzrank/core/models/user_model.dart';
import 'package:rizzrank/core/services/database_service.dart';
import 'package:rizzrank/core/providers/firebase_providers.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    databaseService: ref.watch(databaseServiceProvider),
  );
});

class AuthService {
  final FirebaseAuth _firebaseAuth;
  final DatabaseService _databaseService;

  AuthService({
    required FirebaseAuth firebaseAuth,
    required DatabaseService databaseService,
  })  : _firebaseAuth = firebaseAuth,
        _databaseService = databaseService;

  Future<AppUser> signInAnonymously(String displayName) async {
    final userCredential = await _firebaseAuth.signInAnonymously();
    final uid = userCredential.user!.uid;
    
    final user = AppUser(
      uid: uid,
      displayName: displayName,
      eloRating: 1000,
      wins: 0,
      losses: 0,
      totalGames: 0,
      rizzTitle: 'Rookie',
    );
    
    await _databaseService.createUserProfile(user);
    await _databaseService.setupPresence(uid);
    return user;
  }

  Future<void> signOut() async {
    final uid = _firebaseAuth.currentUser?.uid;
    if (uid != null) {
      await _databaseService.goOffline(uid);
    }
    await _firebaseAuth.signOut();
  }
}
