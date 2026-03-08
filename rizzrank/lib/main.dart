import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Disable RTDB persistence on native platforms to avoid LevelDB crashes on restart
  if (!kIsWeb) {
    FirebaseDatabase.instance.setPersistenceEnabled(false);
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
    // Cloud Functions emulator URL is used by CloudFunctionsHttpService when USE_EMULATORS=true
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
