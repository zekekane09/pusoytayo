import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/router/route_names.dart';
import 'package:pusoy_tayo/features/auth/presentation/auth_controller.dart';
import 'package:pusoy_tayo/features/auth/presentation/login_screen.dart';
import 'package:pusoy_tayo/features/game/presentation/game_screen.dart';
import 'package:pusoy_tayo/features/game/presentation/online_game_screen.dart';
import 'package:pusoy_tayo/features/home/presentation/home_screen.dart';
import 'package:pusoy_tayo/features/lobby/presentation/lobby_screen.dart';
import 'package:pusoy_tayo/features/profile/presentation/profile_screen.dart';
import 'package:pusoy_tayo/features/wallet/presentation/wallet_screen.dart';
import 'package:pusoy_tayo/core/widgets/shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Build the router ONCE. Recreating it on every auth change (via ref.watch)
  // rebuilds MaterialApp.router and causes a black flash on login/logout.
  // Instead we refresh redirects through a listenable and read auth lazily.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final isLoggedIn =
          ref.read(authControllerProvider).valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            name: RouteNames.home,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const HomeScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/lobby',
            name: RouteNames.lobby,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const LobbyScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/wallet',
            name: RouteNames.wallet,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const WalletScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
          GoRoute(
            path: '/profile',
            name: RouteNames.profile,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const ProfileScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/game/:roomCode',
        name: RouteNames.game,
        builder: (context, state) {
          final roomCode = state.pathParameters['roomCode']!;
          return GameScreen(roomCode: roomCode);
        },
      ),
      GoRoute(
        path: '/online/:roomCode',
        builder: (context, state) {
          final roomCode = state.pathParameters['roomCode']!;
          return OnlineGameScreen(roomCode: roomCode);
        },
      ),
    ],
  );
});
