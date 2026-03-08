import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/firebase_providers.dart';
import 'widgets/app_shell.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/matchmaking/presentation/matchmaking_page.dart';
import '../features/chat/presentation/battle_page.dart';
import '../features/chat/presentation/solo_battle_page.dart';
import '../features/results/presentation/results_page.dart';
import '../features/leaderboard/presentation/leaderboard_page.dart';
import '../features/challengers/presentation/challengers_page.dart';
import '../features/history/presentation/history_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/preferences/presentation/preferences_page.dart';

/// Bridges Firebase Auth stream into a [ChangeNotifier] so GoRouter can use
/// [refreshListenable] without rebuilding the entire router on every auth event.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(FirebaseAuth auth) {
    _sub = auth.authStateChanges().listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifierProvider = Provider<_AuthNotifier>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final notifier = _AuthNotifier(auth);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(_authNotifierProvider);
  final auth = ref.watch(firebaseAuthProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuth = auth.currentUser != null;
      final isGoingToLogin =
          state.matchedLocation == '/login' || state.matchedLocation == '/';

      if (!isAuth && !isGoingToLogin) {
        return '/login';
      }

      if (isAuth && isGoingToLogin) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/matchmaking',
        builder: (context, state) => const MatchmakingPage(),
      ),
      GoRoute(
        path: '/chat/solo/:characterId',
        builder: (context, state) =>
            SoloBattlePage(characterId: state.pathParameters['characterId']!),
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (context, state) =>
            BattlePage(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/results/:outcome/:matchId',
        builder: (context, state) {
          final outcome = state.pathParameters['outcome']!;
          final matchId = state.pathParameters['matchId']!;
          return ResultsPage(matchId: matchId, outcome: outcome);
        },
      ),
      GoRoute(
        path: '/preferences',
        builder: (context, state) => const PreferencesPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/leaderboard',
                builder: (context, state) => const LeaderboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/challengers',
                builder: (context, state) => const ChallengersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
