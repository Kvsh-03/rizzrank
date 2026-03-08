import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'debug_log_io.dart' if (dart.library.html) 'debug_log_stub.dart' as debug_log;
import 'firebase_options.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  // #region agent log
  debug_log.debugLog('main.dart:17', 'main() entry, before ensureInitialized',
      {'step': 'entry'}, 'H1');
  // #endregion
  WidgetsFlutterBinding.ensureInitialized();
  // #region agent log
  debug_log.debugLog('main.dart:21', 'before Firebase.initializeApp',
      {'step': 'pre_init'}, 'H1');
  // #endregion
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // #region agent log
  debug_log.debugLog('main.dart:25', 'after Firebase.initializeApp',
      {'step': 'post_init'}, 'H1');
  // #endregion

  // Disable RTDB persistence on native platforms (iOS, macOS) to avoid LevelDB
  // lock/corruption crashes on app restart. Must be called before any DB refs.
  // Web uses IndexedDB and doesn't need this.
  if (!kIsWeb) {
    // #region agent log
    debug_log.debugLog('main.dart:34', 'before setPersistenceEnabled',
        {'step': 'pre_rtdb'}, 'H2');
    // #endregion
    FirebaseDatabase.instance.setPersistenceEnabled(false);
    // #region agent log
    debug_log.debugLog('main.dart:38', 'after setPersistenceEnabled',
        {'step': 'post_rtdb'}, 'H2');
    // #endregion
  }

  // Use emulators when running in debug mode with USE_EMULATORS=true
  // Run: flutter run --dart-define=USE_EMULATORS=true
  const useEmulators = bool.fromEnvironment(
    'USE_EMULATORS',
    defaultValue: false,
  );
  if (kDebugMode && useEmulators) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8081);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    FirebaseDatabase.instance.useDatabaseEmulator('localhost', 9001);
    FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  } else {
    // Disable LevelDB persistence on all platforms to avoid stale lock files
    // that cause "invalid reuse after initialization failure" on iOS restart.
    // App requires wifi so offline cache is not needed.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );

    // If a cached auth token exists from a previous emulator or expired
    // session, validate it. If invalid, sign out for a fresh login.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        await currentUser.getIdToken(true);
      } catch (_) {
        await FirebaseAuth.instance.signOut();
      }
    }
  }

  // #region agent log
  debug_log.debugLog('main.dart:68', 'before runApp', {'step': 'pre_runApp'}, 'H1');
  // #endregion
  runApp(const ProviderScope(child: RizzRankApp()));
}

class RizzRankApp extends ConsumerWidget {
  const RizzRankApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'RizzRank',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
