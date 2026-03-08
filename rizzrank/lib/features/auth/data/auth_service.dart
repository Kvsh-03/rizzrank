import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
    debugPrint('[AuthService] signInAnonymously starting for "$displayName"');
    final userCredential = await _firebaseAuth.signInAnonymously();
    final uid = userCredential.user!.uid;
    debugPrint('[AuthService] Firebase Auth succeeded, uid=$uid');

    final user = AppUser(
      uid: uid,
      displayName: displayName,
      eloRating: 1000,
      wins: 0,
      losses: 0,
      totalGames: 0,
      rizzTitle: 'Rookie',
    );

    debugPrint('[AuthService] Creating user profile in Firestore...');
    await _databaseService.createUserProfile(user);
    debugPrint('[AuthService] Profile created. Setting up presence...');
    await _databaseService.setupPresence(uid);
    debugPrint('[AuthService] Sign-in complete.');
    return user;
  }

  /// Sign in with Google. Creates or updates user profile; sets up presence.
  /// On web (Chrome): uses Firebase signInWithPopup for reliable auth.
  /// On iOS/Android: uses google_sign_in + signInWithCredential.
  Future<AppUser> signInWithGoogle() async {
    debugPrint('[AuthService] signInWithGoogle starting (kIsWeb=$kIsWeb)');
    final UserCredential userCredential;
    if (kIsWeb) {
      // Web: use Firebase popup — works reliably in Chrome (no google_sign_in web issues)
      final provider = GoogleAuthProvider();
      provider.setCustomParameters({'prompt': 'select_account'});
      userCredential = await _firebaseAuth.signInWithPopup(provider);
    } else {
      // Mobile: use google_sign_in then Firebase credential
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'google-sign-in-cancelled',
          message: 'Google sign-in was cancelled',
        );
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      userCredential = await _firebaseAuth.signInWithCredential(credential);
    }

    final fbUser = userCredential.user!;
    final uid = fbUser.uid;
    final displayName = fbUser.displayName?.trim().isNotEmpty == true
        ? fbUser.displayName!
        : (fbUser.email ?? 'Player');
    debugPrint('[AuthService] Firebase Auth succeeded, uid=$uid');

    final user = AppUser(
      uid: uid,
      displayName: displayName,
      eloRating: 1000,
      wins: 0,
      losses: 0,
      totalGames: 0,
      rizzTitle: 'Rookie',
    );

    debugPrint('[AuthService] Creating/updating user profile in Firestore...');
    await _databaseService.createUserProfile(user);
    debugPrint('[AuthService] Setting up presence...');
    await _databaseService.setupPresence(uid);
    debugPrint('[AuthService] Google sign-in complete.');
    return user;
  }

  Future<void> signOut() async {
    final uid = _firebaseAuth.currentUser?.uid;
    debugPrint('[AuthService] signOut for uid=$uid');
    if (uid != null) {
      await _databaseService.goOffline(uid);
    }
    if (!kIsWeb) await GoogleSignIn().signOut();
    await _firebaseAuth.signOut();
    debugPrint('[AuthService] Signed out.');
  }
}
