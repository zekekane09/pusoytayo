import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/network/api_client.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/core/theme/glass_container.dart';
import 'package:pusoy_tayo/core/update/update_checker.dart';
import 'package:pusoy_tayo/features/auth/presentation/auth_controller.dart';
import 'package:pusoy_tayo/features/home/widgets/balance_card.dart';
import 'package:pusoy_tayo/features/home/widgets/game_mode_card.dart';
import 'package:pusoy_tayo/features/home/widgets/rank_badge.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Check for a newer Android build once per session (no-op on web).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.maybePrompt(context, ref.read(apiClientProvider));
    });

    final modeCards = [
      GameModeCard(
        title: 'Quick Match',
        subtitle: 'Find opponents',
        icon: Icons.flash_on_rounded,
        gradient: const [AppColors.primary, AppColors.primaryDark],
        onTap: () => context.go('/lobby'),
      ),
      GameModeCard(
        title: 'Create Room',
        subtitle: 'Play with friends',
        icon: Icons.add_circle_outline_rounded,
        gradient: const [AppColors.secondary, AppColors.secondaryDark],
        onTap: () => context.go('/lobby'),
      ),
      GameModeCard(
        title: 'Practice',
        subtitle: 'Free to play',
        icon: Icons.school_rounded,
        gradient: const [AppColors.info, Color(0xFF0091EA)],
        onTap: () => context.go('/lobby'),
      ),
      GameModeCard(
        title: 'Tournament',
        subtitle: 'Coming Soon',
        icon: Icons.emoji_events_rounded,
        gradient: const [AppColors.accent, Color(0xFFFF8F00)],
        onTap: () {},
        disabled: true,
      ),
    ];

    if (landscape) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0A3E), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _ProfileHeader(
                          displayName: user?.displayName ?? 'Player',
                          avatarUrl: user?.avatarUrl,
                        ),
                        const SizedBox(height: 10),
                        const RankBadge(),
                        const SizedBox(height: 10),
                        _QuickActions(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const BalanceCard(),
                        const SizedBox(height: 12),
                        const Text('PLAY NOW',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: 2)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: modeCards[0]),
                            const SizedBox(width: 8),
                            Expanded(child: modeCards[1]),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: modeCards[2]),
                            const SizedBox(width: 8),
                            Expanded(child: modeCards[3]),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A0A3E), AppColors.background],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: const Icon(Icons.style_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'PUSOY TAYO',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {},
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ProfileHeader(
                    displayName: user?.displayName ?? 'Player',
                    avatarUrl: user?.avatarUrl,
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
                  const SizedBox(height: 16),
                  const BalanceCard()
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideX(begin: 0.1),
                  const SizedBox(height: 16),
                  const RankBadge()
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms)
                      .slideX(begin: -0.1),
                  const SizedBox(height: 24),
                  const Text(
                    'PLAY NOW',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 2,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GameModeCard(
                          title: 'Quick Match',
                          subtitle: 'Find opponents',
                          icon: Icons.flash_on_rounded,
                          gradient: [AppColors.primary, AppColors.primaryDark],
                          onTap: () => context.go('/lobby'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GameModeCard(
                          title: 'Create Room',
                          subtitle: 'Play with friends',
                          icon: Icons.add_circle_outline_rounded,
                          gradient: [AppColors.secondary, AppColors.secondaryDark],
                          onTap: () => context.go('/lobby'),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GameModeCard(
                          title: 'Practice',
                          subtitle: 'Free to play',
                          icon: Icons.school_rounded,
                          gradient: [AppColors.info, const Color(0xFF0091EA)],
                          onTap: () => context.go('/lobby'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GameModeCard(
                          title: 'Tournament',
                          subtitle: 'Coming Soon',
                          icon: Icons.emoji_events_rounded,
                          gradient: [AppColors.accent, const Color(0xFFFF8F00)],
                          onTap: () {},
                          disabled: true,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(begin: 0.1),
                  const SizedBox(height: 24),
                  _QuickActions()
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 400.ms),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;

  const _ProfileHeader({required this.displayName, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bronze.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.military_tech_rounded, color: AppColors.bronze, size: 16),
                SizedBox(width: 4),
                Text(
                  'Bronze',
                  style: TextStyle(
                    color: AppColors.bronze,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ActionItem(
                  icon: Icons.leaderboard_rounded,
                  label: 'Rankings',
                  onTap: () => context.push('/rankings')),
              _ActionItem(
                  icon: Icons.people_rounded,
                  label: 'Friends',
                  onTap: () => context.push('/friends')),
              _ActionItem(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Wallet',
                  onTap: () => context.go('/wallet')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
