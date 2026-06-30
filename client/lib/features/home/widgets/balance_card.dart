import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/core/theme/glass_container.dart';
import 'package:pusoy_tayo/features/wallet/data/wallet_provider.dart';

class BalanceCard extends ConsumerStatefulWidget {
  const BalanceCard({super.key});

  @override
  ConsumerState<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<BalanceCard> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Keep the balance fresh so admin top-ups show up without reopening.
    _poll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) ref.invalidate(walletProvider);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final coins = wallet.valueOrNull?.formattedCoins ?? '—';
    final cash = wallet.valueOrNull?.formattedCash ?? '₱0.00';
    return GlassContainer(
      gradient: LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.15),
          AppColors.secondary.withValues(alpha: 0.1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BalanceItem(
                  label: 'Coins',
                  amount: coins,
                  icon: Icons.monetization_on_rounded,
                  color: AppColors.coinColor,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: AppColors.glassBorder,
              ),
              Expanded(
                child: _BalanceItem(
                  label: 'Cash',
                  amount: cash,
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.cashColor,
                ),
              ),
              IconButton(
                tooltip: 'Refresh balance',
                icon: wallet.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.coinColor),
                      )
                    : const Icon(Icons.refresh_rounded,
                        color: AppColors.coinColor, size: 20),
                onPressed: () => ref.invalidate(walletProvider),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/wallet'),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Deposit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cashColor,
                    side: BorderSide(color: AppColors.cashColor.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/wallet'),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  label: const Text('Withdraw'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  const _BalanceItem({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
