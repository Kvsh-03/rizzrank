import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rizzrank/core/models/user_model.dart';
import 'package:rizzrank/core/services/database_service.dart';
import 'package:rizzrank/core/providers/firebase_providers.dart';
import 'package:rizzrank/firebase_options.dart';

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

  Future<AppUser> signInWithGoogle() async {
    if (kIsWeb) {
      return _signInWithGoogleWeb();
    }
    return _signInWithGoogleNative();
  }

  /// Web (including Chrome on Windows): use Firebase signInWithPopup.
  /// The google_sign_in package has issues on web; popup is more reliable.
  Future<AppUser> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider();
    provider.setCustomParameters({'prompt': 'select_account'});
    final userCredential = await _firebaseAuth.signInWithPopup(provider);

    final fbUser = userCredential.user!;
    final uid = fbUser.uid;
    final displayName = fbUser.displayName?.trim().isNotEmpty == true
        ? fbUser.displayName!
        : (fbUser.email ?? 'Player').split('@').first;

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

  /// Native (macOS, iOS, Android): use google_sign_in.
  /// Note: Windows desktop is not supported by google_sign_in; use web (Chrome) instead.
  Future<AppUser> _signInWithGoogleNative() async {
    final opts = DefaultFirebaseOptions.currentPlatform;
    final clientId = opts.iosClientId;
    final googleSignIn = GoogleSignIn(clientId: clientId);
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google Sign-In was cancelled by the user.');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final uid = userCredential.user!.uid;
    final displayName =
        googleUser.displayName ?? googleUser.email.split('@').first;

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
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await _firebaseAuth.signOut();
  }
}
