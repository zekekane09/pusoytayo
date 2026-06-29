import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';

class ShellScaffold extends StatelessWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

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
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: child,
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
