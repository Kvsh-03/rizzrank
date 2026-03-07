import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/firebase_providers.dart';
import 'widgets/app_shell.dart';
import '../features/auth/presentation/landing_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/matchmaking/presentation/matchmaking_page.dart';
import '../features/chat/presentation/battle_page.dart';
import '../features/results/presentation/results_page.dart';
import '../features/leaderboard/presentation/leaderboard_page.dart';
import '../features/history/presentation/history_page.dart';
import '../features/profile/presentation/profile_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      // If authState is loading, don't redirect yet
      if (authState.isLoading) return null;

      final isAuth = authState.value != null;
      final isGoingToLogin = state.matchedLocation == '/login' || state.matchedLocation == '/';

      if (!isAuth && !isGoingToLogin) {
        return '/';
      }
      
      if (isAuth && isGoingToLogin) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/matchmaking',
        builder: (context, state) => const MatchmakingPage(),
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (context, state) => BattlePage(matchId: state.pathParameters['matchId']!),
      ),
      GoRoute(
        path: '/results/:outcome/:matchId',
        builder: (context, state) {
          final outcome = state.pathParameters['outcome']!;
          final matchId = state.pathParameters['matchId']!;
          return ResultsPage(matchId: matchId, outcome: outcome);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/leaderboard', builder: (context, state) => const LeaderboardPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/history', builder: (context, state) => const HistoryPage())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (context, state) => const ProfilePage())]),
        ],
      ),
    ],
  );
});
