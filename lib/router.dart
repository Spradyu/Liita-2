import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liita/core/providers/providers.dart';
import 'package:liita/features/splash/splash_screen.dart';
import 'package:liita/features/onboarding/onboarding_screen.dart';
import 'package:liita/features/home/home_shell.dart';
import 'package:liita/features/radar/radar_screen.dart';
import 'package:liita/features/matches/matches_screen.dart';
import 'package:liita/features/games/games_screen.dart';
import 'package:liita/features/games/tictactoe_screen.dart';
import 'package:liita/features/games/trivia_screen.dart';
import 'package:liita/features/games/connect_four_screen.dart';
import 'package:liita/features/lounge/lounge_screen.dart';
import 'package:liita/features/profile/profile_screen.dart';
import 'package:liita/features/chat/chat_screen.dart';
import 'package:liita/features/showcase/showcase_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isOnboarded = ref.watch(onboardingCompleteProvider);
  final profile = ref.watch(localProfileProvider);

  // Null-profile guard: if no profile exists, always go to onboarding
  // regardless of the onboarding flag value.
  final bool shouldOnboard = !isOnboarded || profile == null;

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/splash';
      if (isSplash) return null; // Let splash screen handle its own navigation

      final onboarding = state.matchedLocation == '/onboarding';
      if (shouldOnboard && !onboarding) return '/onboarding';
      if (!shouldOnboard && onboarding) return '/radar';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/radar',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RadarScreen(),
            ),
          ),
          GoRoute(
            path: '/matches',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MatchesScreen(),
            ),
          ),
          GoRoute(
            path: '/games',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: GamesScreen(),
            ),
          ),
          GoRoute(
            path: '/lounge',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LoungeScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/chat/:matchId',
        builder: (context, state) {
          final matchId = state.pathParameters['matchId']!;
          final peerName = state.uri.queryParameters['name'] ?? 'Chat';
          return ChatScreen(matchId: matchId, peerName: peerName);
        },
      ),
      // Game boards are FULL-SCREEN (outside the shell / no bottom nav) so the
      // only way out is the in-game Quit (X) or the back gesture — both of
      // which fire _quitGame and tell the opponent the game ended. Inside the
      // shell, a nav-tab tap would silently leave the board without notifying
      // the peer, so the opponent only saw the disconnect on the ~30s mesh
      // presence timeout, not when the player actually left the screen.
      GoRoute(
        path: '/games/tictactoe',
        builder: (context, state) => const TicTacToeScreen(),
      ),
      GoRoute(
        path: '/games/trivia',
        builder: (context, state) => const TriviaScreen(),
      ),
      GoRoute(
        path: '/games/connectfour',
        builder: (context, state) => const ConnectFourScreen(),
      ),
      // TEMP DEBUG: standalone neumorphic UI showcase (reached from Profile).
      GoRoute(
        path: '/showcase',
        builder: (context, state) => const ShowcaseScreen(),
      ),
    ],
  );
});
