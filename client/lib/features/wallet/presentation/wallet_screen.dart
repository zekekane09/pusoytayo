import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pusoy_tayo/core/theme/app_colors.dart';
import 'package:pusoy_tayo/core/theme/glass_container.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A2818), AppColors.background],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              title: Text(
                'WALLET',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _WalletBalanceCard()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GradientButton(
                          label: 'Deposit',
                          icon: Icons.add_circle_outline,
                          colors: [AppColors.success, const Color(0xFF00C853)],
                          onPressed: () => _showDepositSheet(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GradientButton(
                          label: 'Withdraw',
                          icon: Icons.arrow_circle_up_outlined,
                          colors: [AppColors.warning, const Color(0xFFFF8F00)],
                          onPressed: () => _showWithdrawSheet(context),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: 24),
                  const Text(
                    'TRANSACTION HISTORY',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 12),
                  ..._buildMockTransactions(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMockTransactions(BuildContext context) {
    final transactions = [
      _TransactionItem(
        type: 'bonus',
        description: 'Welcome Bonus',
        amount: 1000,
        currency: 'coins',
        isCredit: true,
        date: 'Today',
      ),
    ];

    return transactions
        .asMap()
        .entries
        .map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: e.value,
            ).animate().fadeIn(delay: (400 + e.key * 80).ms, duration: 400.ms))
        .toList();
  }

  void _showDepositSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _DepositSheet(),
    );
  }

  void _showWithdrawSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _WithdrawSheet(),
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      gradient: LinearGradient(
        colors: [
          AppColors.secondary.withValues(alpha: 0.2),
          AppColors.primary.withValues(alpha: 0.1),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '₱0.00',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniBalance(
                  label: 'Coins',
                  value: '1,000',
                  icon: Icons.monetization_on_rounded,
                  color: AppColors.coinColor,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.glassBorder),
              Expanded(
                child: _MiniBalance(
                  label: 'Cash',
                  value: '₱0.00',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.cashColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBalance extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniBalance({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final String type;
  final String description;
  final int amount;
  final String currency;
  final bool isCredit;
  final String date;

  const _TransactionItem({
    required this.type,
    required this.description,
    required this.amount,
    required this.currency,
    required this.isCredit,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.success : AppColors.error)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: isCredit ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${currency == 'cash' ? '₱' : ''}$amount',
            style: TextStyle(
              color: isCredit ? AppColors.success : AppColors.error,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DepositSheet extends StatelessWidget {
  const _DepositSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Deposit via GCash',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Amount (PHP)',
              prefixText: '₱ ',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'GCash Reference Number',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Submit Deposit Request',
              colors: [AppColors.success, const Color(0xFF00C853)],
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Admin will verify your payment within 24 hours',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawSheet extends StatelessWidget {
  const _WithdrawSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Withdraw to GCash',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: 'GCash Number',
              prefixText: '+63 ',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Amount (PHP)',
              prefixText: '₱ ',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: 'Submit Withdrawal Request',
              colors: [AppColors.warning, const Color(0xFFFF8F00)],
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Withdrawals are processed within 24-48 hours',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
