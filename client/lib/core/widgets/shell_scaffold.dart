import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/constants/socket_events.dart';
import 'package:pusoy_tayo/core/network/socket_client.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';

class ShellScaffold extends ConsumerStatefulWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  StreamSubscription? _inviteSub;
  bool _showingInvite = false;

  @override
  void initState() {
    super.initState();
    _listenForInvites();
  }

  /// Keep a live socket while the player is anywhere in the app (home, wallet,
  /// profile, lobby) so a friend's game invite reaches them even when they're
  /// not in a room. The in-game screen reuses the same shared socket.
  Future<void> _listenForInvites() async {
    final socket = ref.read(socketClientProvider);
    await socket.connect();
    _inviteSub = socket.on<dynamic>(SocketEvents.friendInvited).listen((d) {
      if (!mounted || _showingInvite) return;
      final m = d as Map;
      final code = m['roomCode']?.toString();
      final from = m['fromName']?.toString() ?? 'A friend';
      if (code == null || code.isEmpty) return;
      _showingInvite = true;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Game invite',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text('$from invited you to room $code. Join now?',
              style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/online/$code');
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ).whenComplete(() => _showingInvite = false);
    });
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    super.dispose();
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/lobby')) return 1;
    if (location.startsWith('/wallet')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _go(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/lobby');
      case 2:
        context.go('/wallet');
      case 3:
        context.go('/profile');
    }
  }

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.sports_esports_rounded, 'Play'),
    (Icons.account_balance_wallet_rounded, 'Wallet'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    // In landscape there's little vertical room, so move navigation to a side
    // rail and give the content the full height (better dashboard/menu UI).
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (landscape) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (i) => _go(context, i),
                labelType: NavigationRailLabelType.all,
                backgroundColor: AppColors.surface,
                selectedIconTheme:
                    const IconThemeData(color: AppColors.primary),
                selectedLabelTextStyle:
                    const TextStyle(color: AppColors.primary),
                unselectedIconTheme:
                    const IconThemeData(color: AppColors.textMuted),
                unselectedLabelTextStyle:
                    const TextStyle(color: AppColors.textMuted),
                destinations: [
                  for (final it in _items)
                    NavigationRailDestination(
                      icon: Icon(it.$1),
                      label: Text(it.$2),
                    ),
                ],
              ),
              const VerticalDivider(width: 0.5, color: AppColors.glassBorder),
              Expanded(child: widget.child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.glassBorder, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) => _go(context, i),
          items: [
            for (final it in _items)
              BottomNavigationBarItem(icon: Icon(it.$1), label: it.$2),
          ],
        ),
      ),
    );
  }
}
