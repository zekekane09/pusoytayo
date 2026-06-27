import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/router/route_names.dart';
import 'package:pusoy_tayo/features/auth/presentation/auth_controller.dart';
import 'package:pusoy_tayo/features/auth/presentation/login_screen.dart';
import 'package:pusoy_tayo/features/game/presentation/game_screen.dart';
import 'package:pusoy_tayo/features/home/presentation/home_screen.dart';
import 'package:pusoy_tayo/features/lobby/presentation/lobby_screen.dart';
import 'package:pusoy_tayo/features/profile/presentation/profile_screen.dart';
import 'package:pusoy_tayo/features/wallet/presentation/wallet_screen.dart';
import 'package:pusoy_tayo/core/widgets/shell_scaffold.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
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
    ],
  );
});
